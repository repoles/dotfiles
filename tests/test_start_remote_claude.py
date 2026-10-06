"""Contracts for the command that opens a remote-controlled Claude window in a tmux session."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'tmux/.config/tmux/scripts'
REMOTE_SCRIPT = SCRIPTS / 'start-remote-claude.sh'


class StartRemoteClaudeTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='start-remote-claude-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.log = self.path / 'log'
        # Point tmux at a server of its own, should the fake ever be bypassed.
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        LOG=str(self.log), TMUX_TMPDIR=str(self.path))
        self.env.pop('TMUX', None)
        # Without SERVER_PATH, no tmux server is running.
        self.executable('tmux', '''#!/bin/sh
if [ "$1" = show-environment ]; then
    [ -n "$SERVER_PATH" ] || exit 1
    printf 'PATH=%s\\n' "$SERVER_PATH"
    exit
fi
printf 'tmux %s\\n' "$*" >> "$LOG"
[ "$1" = new-window ] && printf '%s\\n' "$PATH" > "$LOG.path"
[ "$1" = has-session ] && exit "${HAS_SESSION:-0}"
exit "${TMUX_STATUS:-0}"
''')
        self.executable('zoxide', '#!/bin/sh\nprintf "zoxide %s\\n" "$*" >> "$LOG"\n'
                                  '[ -n "$ZOXIDE_DIR" ] || exit 1\n'
                                  'printf "%s\\n" "$ZOXIDE_DIR"\n')

    def executable(self, name, contents):
        path = self.path / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_remote(self, *args, script=REMOTE_SCRIPT, **env):
        return subprocess.run(['/bin/sh', str(script), *args],
                              env=dict(self.env, **env), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def window_path(self):
        return Path(f'{self.log}.path').read_text().rstrip('\n')

    def new_window(self, session, scripts=SCRIPTS):
        return (f"tmux new-window -d -P -F #{{session_name}}:#{{window_index}} -t ={session}: "
                f"-c #{{session_path}} -n claude {scripts}/start-agent.sh claude "
                '--permission-mode auto --remote-control')

    def test_opens_the_window_in_an_existing_session(self):
        result = self.run_remote('api')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['tmux has-session -t =api', self.new_window('api')])

    def test_creates_a_missing_session_in_its_zoxide_directory(self):
        result = self.run_remote('api', HAS_SESSION='1', ZOXIDE_DIR='/Users/me/Code/api')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['tmux has-session -t =api', 'zoxide query -- api',
                                        'tmux new-session -d -s api -c /Users/me/Code/api',
                                        self.new_window('api')])

    def test_gives_the_window_the_tmux_server_path(self):
        server_path = f'{self.path}:/usr/bin:/bin'

        result = self.run_remote('api', SERVER_PATH=server_path)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.window_path(), server_path)

    def test_without_a_server_adds_the_agent_directories_to_the_path(self):
        result = self.run_remote('api', HAS_SESSION='1', ZOXIDE_DIR='/Users/me/Code/api',
                                 HOME='/Users/me')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.window_path(),
                         self.env['PATH'] + ':/Users/me/.local/bin:/opt/homebrew/bin')

    def test_fails_when_zoxide_knows_no_directory(self):
        result = self.run_remote('api', HAS_SESSION='1')

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), ['tmux has-session -t =api', 'zoxide query -- api'])

    def test_fails_when_the_window_cannot_be_opened(self):
        result = self.run_remote('api', TMUX_STATUS='1')

        self.assertEqual(result.returncode, 1)

    def test_finds_start_agent_through_a_link(self):
        link = self.path / 'start-remote-claude'
        link.symlink_to(REMOTE_SCRIPT)

        result = self.run_remote('api', script=link)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], self.new_window('api', SCRIPTS.resolve()))

    def test_requires_exactly_one_session(self):
        for args in [[], [''], ['api', 'web']]:
            with self.subTest(args=args):
                result = self.run_remote(*args)

                self.assertEqual(result.returncode, 64)
                self.assertIn('Usage:', result.stderr)
                self.assertEqual(self.calls(), [])


if __name__ == '__main__':
    unittest.main()
