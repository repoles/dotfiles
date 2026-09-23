"""Contracts for the agent tmux hook, activity cache, and window status."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'tmux/.config/tmux/scripts'
HOOK_SCRIPT = SCRIPTS / 'agent-tmux-hook.sh'
ACTIVITY_SCRIPT = SCRIPTS / 'agent-tmux-activity.sh'
STATUS_SCRIPT = SCRIPTS / 'agent-tmux-status.sh'


class AgentTmuxScriptsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='agent-tmux-scripts-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.command_log = self.path / 'tmux-commands'
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        TMUX_PANE='%1', XDG_CACHE_HOME=str(self.path),
                        SERVER_INSTANCE='1000-42', NOW='200000',
                        COMMAND_LOG=str(self.command_log))
        self.executable('tmux', '''#!/bin/sh
printf '%s\n' "$*" >> "$COMMAND_LOG"
case "$1" in
    display-message)
        printf '%s\n' "$SERVER_INSTANCE"
        exit "${DISPLAY_STATUS:-0}"
        ;;
    set) exit "${SET_STATUS:-0}" ;;
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

    def run_script(self, script, event, **env):
        return subprocess.run(['/bin/sh', str(script), event],
                              env=dict(self.env, **env), capture_output=True,
                              text=True)

    def run_activity(self, event, **env):
        return self.run_script(ACTIVITY_SCRIPT, event, **env)

    def commands(self):
        if not self.command_log.exists():
            return []
        return self.command_log.read_text().splitlines()

    def test_stamp_is_namespaced_by_server_lifetime(self):
        result = self.run_activity('busy')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.stamps() / '%1').read_text(), '200000\n')
        self.assertFalse((self.path / 'tmux-agent-activity/%1').exists())

    def test_idle_never_sweeps_panes_from_its_current_instance(self):
        self.stamps().mkdir(parents=True)
        (self.stamps() / '%old').write_text('100\n')

        result = self.run_activity('idle')

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

        result = self.run_activity('idle')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((live / '%foreign').read_text(), '100\n')
        self.assertFalse(dead.exists())
        self.assertEqual((invalid / '%unknown').read_text(), '100\n')

    def test_invalid_server_instance_does_not_write_a_stamp(self):
        result = self.run_activity('busy', SERVER_INSTANCE='invalid')

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse((self.path / 'tmux-agent-activity').exists())

    def test_status_script_maps_events_to_window_styles(self):
        expected_commands = {
            'busy': 'set -w -t %1 window-status-style fg=green',
            'waiting': 'set -w -t %1 window-status-style fg=yellow',
            'error': 'set -w -t %1 window-status-style fg=red',
            'idle': 'set -uw -t %1 window-status-style',
        }

        for event, expected in expected_commands.items():
            with self.subTest(event=event):
                self.command_log.unlink(missing_ok=True)
                result = self.run_script(STATUS_SCRIPT, event)

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.commands(), [expected])
                self.assertFalse((self.path / 'tmux-agent-activity').exists())

    def test_hook_updates_status_when_activity_cache_fails(self):
        result = self.run_script(HOOK_SCRIPT, 'busy', SERVER_INSTANCE='invalid')

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.commands(), [
            'display-message -p -t %1 #{start_time}-#{pid}',
            'set -w -t %1 window-status-style fg=green',
        ])
        self.assertFalse((self.path / 'tmux-agent-activity').exists())

    def test_hook_records_activity_when_status_update_fails(self):
        result = self.run_script(HOOK_SCRIPT, 'busy', SET_STATUS='1')

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.stamps() / '%1').read_text(), '200000\n')
        self.assertEqual(self.commands(), [
            'display-message -p -t %1 #{start_time}-#{pid}',
            'set -w -t %1 window-status-style fg=green',
        ])

    def test_agent_configs_use_the_shared_hook_entrypoint(self):
        for relative_path in ['codex/.codex/hooks.json',
                              'claude/.claude/settings.json']:
            with self.subTest(config=relative_path):
                contents = (ROOT / relative_path).read_text()
                self.assertIn('/agent-tmux-hook.sh ', contents)
                self.assertNotIn('/agent-tmux-status.sh ', contents)


if __name__ == '__main__':
    unittest.main()
