"""Contracts for the record of agent sessions that started in tmux and have not ended."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SESSION_SCRIPT = ROOT / 'tmux/.config/tmux/scripts/agent-tmux-session.sh'
SESSION_ID = '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b'
AGENT_LSTART = 'Fri Oct  2 01:39:11 2026    '


class AgentTmuxSessionTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='agent-tmux-session-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.sessions = self.path / 'tmux-agent-sessions'
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        TMUX_PANE='%1', XDG_STATE_HOME=str(self.path),
                        PANE='work\x1f2\x1fapi: tests\x1f1\x1f✳ Fix\tthe build',
                        NOW='1791030600', AGENT_STARTED_AT='1791000000')
        # The script runs as a child of this test, so its ancestry starts here: a hook
        # shell, then the agent, then tmux.
        self.processes = {os.getpid(): (700, '/bin/zsh', ''),
                          700: (600, '/Users/me/.local/bin/claude', AGENT_LSTART),
                          600: (1, 'tmux', '')}
        self.executable('ps', '''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
pid = args[args.index('-p') + 1]
process = json.loads(os.environ['PROCESSES']).get(pid)
if process is None:
    sys.exit(1)
ppid, comm, lstart = process
print(lstart if 'lstart=' in args else '%5d %s' % (ppid, comm))
''')
        self.executable('tmux', '''#!/bin/sh
printf '%s\n' "$*" >> "$XDG_STATE_HOME/tmux-commands"
[ "$1" = display-message ] || exit 1
printf '%s\n' "$PANE"
exit "${DISPLAY_STATUS:-0}"
''')
        self.executable('date', '''#!/bin/sh
# Only the agent's normalized lstart converts to its start time.
if [ "$1" = -j ]; then
    [ "$4" = 'Fri Oct 2 01:39:11 2026' ] || exit 1
    printf '%s\n' "$AGENT_STARTED_AT"
    exit
fi
printf '%s\n' "$NOW"
''')

    def executable(self, name, contents):
        path = self.path / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_session(self, *args, payload=None, **env):
        if payload is None:
            payload = {'session_id': SESSION_ID, 'cwd': '/Users/me/Code/api',
                       'hook_event_name': 'UserPromptSubmit'}
        processes = json.dumps({str(pid): process
                                for pid, process in self.processes.items()})
        return subprocess.run(['/bin/sh', str(SESSION_SCRIPT), *args],
                              input=json.dumps(payload),
                              env=dict(self.env, PROCESSES=processes, **env),
                              capture_output=True, text=True)

    def record(self, session_id=SESSION_ID):
        return json.loads((self.sessions / f'{session_id}.json').read_text())

    def test_start_records_the_session_and_its_tmux_pane(self):
        result = self.run_session('claude', 'start')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(self.record(), {
            'tool': 'claude',
            'session_id': SESSION_ID,
            'cwd': '/Users/me/Code/api',
            'tmux_session': 'work',
            'window_index': 2,
            'window_name': 'api: tests',
            'pane_index': 1,
            'pane_title': '✳ Fix\tthe build',
            'started_at': 1791030600,
            'last_prompt_at': 1791030600,
            'agent_pid': 700,
            'agent_started_at': 1791000000,
        })
        self.assertEqual([p.name for p in self.sessions.iterdir()],
                         [f'{SESSION_ID}.json'])

    def test_an_agent_missing_from_the_ancestry_is_recorded_as_unknown(self):
        result = self.run_session('codex', 'start')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.record()['agent_pid'], self.record()['agent_started_at']),
                         (None, None))

    def test_an_agent_without_a_readable_start_time_is_recorded_as_unknown(self):
        self.processes[700] = (600, 'claude', 'not a date')

        result = self.run_session('claude', 'start')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.record()['agent_pid'], self.record()['agent_started_at']),
                         (None, None))

    def test_stop_refreshes_the_agent_process(self):
        self.run_session('claude', 'start')
        self.processes = {os.getpid(): (800, '/bin/sh', ''),
                          800: (1, 'claude', 'Fri Oct  2 01:39:11 2026')}

        result = self.run_session('claude', 'stop')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.record()['agent_pid'], 800)

    def test_later_prompts_refresh_the_record_but_keep_the_start_time(self):
        self.run_session('codex', 'start')

        result = self.run_session('codex', 'start', NOW='1791036000',
                                  PANE='work\x1f5\x1fmoved\x1f0\x1f')

        self.assertEqual(result.returncode, 0, result.stderr)
        record = self.record()
        self.assertEqual(record['started_at'], 1791030600)
        self.assertEqual(record['last_prompt_at'], 1791036000)
        self.assertEqual((record['window_index'], record['window_name'],
                          record['pane_index'], record['pane_title']),
                         (5, 'moved', 0, ''))

    def test_unreadable_start_time_is_replaced(self):
        self.sessions.mkdir()
        (self.sessions / f'{SESSION_ID}.json').write_text(
            '{"started_at": "2026-10-02T09:00:00-0300"}')

        result = self.run_session('claude', 'start')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.record()['started_at'], 1791030600)

    def test_stop_refreshes_the_pane_but_keeps_both_times(self):
        self.run_session('claude', 'start')

        result = self.run_session('claude', 'stop', NOW='1791036000',
                                  PANE='work\x1f2\x1fapi: tests\x1f1\x1f✳ Agent sessions')

        self.assertEqual(result.returncode, 0, result.stderr)
        record = self.record()
        self.assertEqual(record['pane_title'], '✳ Agent sessions')
        self.assertEqual((record['started_at'], record['last_prompt_at']),
                         (1791030600, 1791030600))

    def test_stop_without_a_record_writes_nothing(self):
        result = self.run_session('codex', 'stop')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.sessions.exists())
        self.assertFalse((self.path / 'tmux-commands').exists())

    def test_end_removes_only_its_own_record(self):
        self.run_session('claude', 'start')
        other = 'other-session'
        self.run_session('codex', 'start', payload={'session_id': other, 'cwd': '/tmp'})

        result = self.run_session('claude', 'end')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.sessions / f'{SESSION_ID}.json').exists())
        self.assertEqual(self.record(other)['tool'], 'codex')

    def test_end_without_a_record_succeeds(self):
        result = self.run_session('claude', 'end')

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_outside_tmux_nothing_is_recorded_or_refreshed(self):
        self.run_session('claude', 'start')
        before = (self.sessions / f'{SESSION_ID}.json').read_text()

        for action in ['start', 'stop']:
            with self.subTest(action=action):
                result = self.run_session('claude', action, TMUX_PANE='', NOW='1791036000',
                                          payload={'session_id': 'other', 'cwd': '/'})
                self.assertEqual(result.returncode, 0, result.stderr)
                result = self.run_session('claude', action, TMUX_PANE='', NOW='1791036000')
                self.assertEqual(result.returncode, 0, result.stderr)

                self.assertFalse((self.sessions / 'other.json').exists())
                self.assertEqual((self.sessions / f'{SESSION_ID}.json').read_text(), before)

    def test_a_session_resumed_outside_tmux_still_ends_its_record(self):
        self.run_session('claude', 'start')

        result = self.run_session('claude', 'end', TMUX_PANE='')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.sessions / f'{SESSION_ID}.json').exists())

    def test_session_id_cannot_escape_the_directory(self):
        for session_id in ['', '../escape', 'a/b', '.hidden']:
            with self.subTest(session_id=session_id):
                result = self.run_session('claude', 'start',
                                          payload={'session_id': session_id, 'cwd': '/'})

                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(self.sessions.exists())
                self.assertFalse((self.path / 'escape.json').exists())

    def test_failed_tmux_query_leaves_no_record(self):
        result = self.run_session('claude', 'start', DISPLAY_STATUS='1')

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse(self.sessions.exists())

    def test_agent_configs_record_from_the_first_prompt_until_the_end(self):
        script = '/tmux/scripts/agent-tmux-session.sh'
        for tool, relative_path in [('codex', 'codex/.codex/hooks.json'),
                                    ('claude', 'claude/.claude/settings.json')]:
            with self.subTest(config=relative_path):
                hooks = json.loads((ROOT / relative_path).read_text())['hooks']
                self.assertNotIn(script, json.dumps(hooks['SessionStart']))
                for event, action in [('UserPromptSubmit', 'start'), ('Stop', 'stop'),
                                      ('SessionEnd', 'end')]:
                    groups = [group for group in hooks[event]
                              if any(hook['command'].endswith(f'{script} {tool} {action}')
                                     for hook in group['hooks'])]
                    self.assertEqual(len(groups), 1, event)
                    self.assertNotIn('matcher', groups[0])


if __name__ == '__main__':
    unittest.main()
