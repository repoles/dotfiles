"""Contracts for the activity stamps written by agent tmux hooks."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = (Path(__file__).resolve().parents[1] /
          'tmux/.config/tmux/scripts/agent-tmux-status.sh')


class AgentTmuxStatusTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='agent-tmux-status-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        TMUX_PANE='%1', XDG_CACHE_HOME=str(self.path),
                        SERVER_INSTANCE='1000-42', NOW='200000')
        self.executable('tmux', '''#!/bin/sh
case "$1" in
    display-message)
        printf '%s\n' "$SERVER_INSTANCE"
        exit "${DISPLAY_STATUS:-0}"
        ;;
    set) exit 0 ;;
esac
exit 1
''')
        self.executable('date', '#!/bin/sh\nprintf "%s\\n" "$NOW"\n')

    def executable(self, name, contents):
        path = self.path / name
        path.write_text(contents)
        path.chmod(0o755)

    def stamps(self, instance=None):
        return (self.path / 'tmux-agent-activity' /
                (instance or self.env['SERVER_INSTANCE']))

    def run_hook(self, event, **env):
        return subprocess.run(['/bin/sh', str(SCRIPT), event],
                              env=dict(self.env, **env), capture_output=True,
                              text=True)

    def test_stamp_is_namespaced_by_server_lifetime(self):
        result = self.run_hook('busy')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.stamps() / '%1').read_text(), '200000\n')
        self.assertFalse((self.path / 'tmux-agent-activity/%1').exists())

    def test_idle_never_sweeps_panes_from_its_current_instance(self):
        self.stamps().mkdir(parents=True)
        (self.stamps() / '%old').write_text('100\n')

        result = self.run_hook('idle')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.stamps() / '%1').read_text(), '200000\n')
        self.assertEqual((self.stamps() / '%old').read_text(), '100\n')

    def test_idle_removes_only_namespaces_whose_server_pid_is_dead(self):
        live = self.stamps(f'900-{os.getpid()}')
        live.mkdir(parents=True)
        (live / '%foreign').write_text('100\n')
        dead = self.stamps('800-999999999')
        dead.mkdir(parents=True)
        (dead / '%orphan').write_text('100\n')
        invalid = self.stamps('not-an-instance')
        invalid.mkdir(parents=True)
        (invalid / '%unknown').write_text('100\n')

        result = self.run_hook('idle')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((live / '%foreign').read_text(), '100\n')
        self.assertFalse(dead.exists())
        self.assertEqual((invalid / '%unknown').read_text(), '100\n')

    def test_invalid_server_instance_does_not_write_a_stamp(self):
        result = self.run_hook('busy', SERVER_INSTANCE='invalid')

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse((self.path / 'tmux-agent-activity').exists())


if __name__ == '__main__':
    unittest.main()
