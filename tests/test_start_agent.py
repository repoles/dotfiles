"""Contracts for the command that runs an agent as a tmux pane."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
START_SCRIPT = ROOT / 'tmux/.config/tmux/scripts/start-agent.sh'
TMUX_CONF = ROOT / 'tmux/.config/tmux/tmux.conf'


class StartAgentTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='start-agent-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.log = self.path / 'log'
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        TMUX_PANE='%1', LOG=str(self.log), WAIT_BEFORE_CLOSE_SECONDS='0')
        self.executable('tmux', '#!/bin/sh\nprintf "tmux %s\\n" "$*" >> "$LOG"\n'
                                'exit "${TMUX_STATUS:-0}"\n')
        for agent in ['claude', 'codex']:
            self.executable(agent, f'#!/bin/sh\nprintf "{agent} %s\\n" "$*" >> "$LOG"\n'
                                   'exit "${AGENT_STATUS:-0}"\n')

    def executable(self, name, contents):
        path = self.path / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_start(self, *args, **env):
        return subprocess.run(['/bin/sh', str(START_SCRIPT), *args],
                              env=dict(self.env, **env), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_sets_up_the_window_and_runs_the_agent(self):
        window = 'tmux set -w -t %1 monitor-silence 300 ; set -w -t %1 @full_title 1'
        for args, agent in [(['claude'], 'claude '),
                            (['claude', '--resume', 'abc'], 'claude --resume abc'),
                            (['codex'], 'codex --no-daemon'),
                            (['codex', 'resume', 'abc'], 'codex --no-daemon resume abc')]:
            with self.subTest(args=args):
                self.log.unlink(missing_ok=True)
                result = self.run_start(*args)

                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls(), [window, agent])

    def test_exits_with_the_agent_status(self):
        result = self.run_start('claude', AGENT_STATUS='3')

        self.assertEqual(result.returncode, 3)

    def test_runs_the_agent_even_if_the_window_cannot_be_set_up(self):
        result = self.run_start('codex', TMUX_STATUS='1')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], 'codex --no-daemon')

    def test_outside_tmux_only_runs_the_agent(self):
        result = self.run_start('claude', TMUX_PANE='')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), ['claude '])

    def test_rejects_an_unknown_agent(self):
        for args in [[], ['vim']]:
            with self.subTest(args=args):
                result = self.run_start(*args)

                self.assertEqual(result.returncode, 64)
                self.assertIn('Usage:', result.stderr)
                self.assertEqual(self.calls(), [])

    def test_f1_and_f2_open_their_agent_through_the_script(self):
        bindings = {line.split()[1]: line for line in TMUX_CONF.read_text().splitlines()
                    if line.startswith('bind-key F')}

        for key, agent in [('F1', 'claude'), ('F2', 'codex')]:
            with self.subTest(key=key):
                self.assertIn(f'-n {agent} ', bindings[key])
                self.assertIn(f'/tmux/scripts/start-agent.sh" {agent}\'', bindings[key])
                self.assertNotIn('setw', bindings[key])


if __name__ == '__main__':
    unittest.main()
