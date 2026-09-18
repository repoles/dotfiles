"""Selector contracts, with tmux/fzf replaced at the process boundary."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / 'tmux/.config/tmux/scripts'
SEPARATOR = '\x1f'


def row(*fields):
    return SEPARATOR.join(map(str, fields))


class TmuxSelectorsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='tmux-selectors-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name)
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        SELECTOR_CLIENT='/dev/ttys-review', SELECTOR_SESSION='$1',
                        SELECTOR_WINDOW='@11', SELECTOR_LAST_SESSION='previous',
                        XDG_CACHE_HOME=str(self.path), FIXTURES=str(self.path))
        self.env.pop('FZF_DEFAULT_OPTS', None)
        self.env.pop('FZF_DEFAULT_OPTS_FILE', None)
        self.executable('tmux', '''#!/usr/bin/env python3
import json, os, pathlib, sys
path = pathlib.Path(os.environ['FIXTURES'])
with (path / 'commands').open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1].startswith('list-'):
    sys.stdout.write((path / 'rows').read_text())
    sys.exit(int(os.environ.get('QUERY_STATUS', '0')))
''')
        self.executable('fzf', '''#!/usr/bin/env python3
import json, os, pathlib, sys
path = pathlib.Path(os.environ['FIXTURES'])
rows = sys.stdin.read().splitlines()
(path / 'menu').write_text(json.dumps({'rows': rows, 'options': sys.argv[1:]}))
status = int(os.environ.get('FZF_STATUS', '0'))
if status:
    sys.exit(status)
if not os.environ.get('EMPTY_SELECTION'):
    print(rows[int(os.environ.get('SELECT_ROW', '0'))])
''')
        self.executable('date', '#!/bin/sh\nprintf "200000\\n"\n')

    def executable(self, name, contents):
        path = self.path / name
        path.write_text(contents)
        path.chmod(0o755)

    def run_selector(self, name, rows, **env):
        (self.path / 'rows').write_text('\n'.join(rows) + '\n')
        (self.path / 'commands').write_text('')
        return subprocess.run(['/bin/bash', str(SCRIPTS / (name + '.sh'))],
                              env=dict(self.env, **env), capture_output=True,
                              text=True)

    def menu(self):
        return json.loads((self.path / 'menu').read_text())

    def commands(self):
        return [json.loads(line) for line in
                (self.path / 'commands').read_text().splitlines()]

    def test_session_order_labels_current_and_previous(self):
        # tmux removes the active-window marker before returning these rows.
        # Keep a nonempty alerts field to verify that it stays out of the label.
        result = self.run_selector('select-session', [
            row(199880, '$2', 'previous', 1, '1:fish', '', 0, '', 'default'),
            row(200000, '$1', 'work]local', 3, '2:codex', '1!', 1, '✳ Raw title', 'fg=green'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.menu()['rows'], [
            '$1\t[work]local] 2:codex (3 windows, current session) "\x1b[32mRaw title\x1b[39m"',
            '$2\t[previous] 1:fish (1 window, accessed 2m ago)',
        ])
        self.assertIn('start:pos(1)', self.menu()['options'])
        self.assertIn('S:pos(2)+accept', self.menu()['options'])
        self.assertIn('--ansi', self.menu()['options'])
        self.assertEqual(self.commands()[-1],
                         ['switch-client', '-c', '/dev/ttys-review', '-t', '$1'])

    def test_window_uses_session_and_stable_id_not_displayed_index(self):
        result = self.run_selector('select-window', [
            row('@42', 'work]local', '2:fish-', 0, 1, 199999, '', 'default'),
            row('@11', 'work]local', '3:codex*', 1, 0, 199940, '✳ Title', 'fg=red'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands()[0][1:3], ['-t', '$1'])
        self.assertEqual(self.commands()[-1],
                         ['switch-client', '-c', '/dev/ttys-review', '-t', '$1:@42'])
        self.assertEqual(self.menu()['rows'][0],
                         '$1:@42\t[work]local] 2:fish- (active 1s ago)')
        self.assertEqual(self.menu()['rows'][1],
                         '$1:@11\t[work]local] 3:codex* (active 1m ago) "\x1b[31mTitle\x1b[39m"')
        self.assertIn('start:pos(2)', self.menu()['options'])
        self.assertIn('W:pos(1)+accept', self.menu()['options'])
        self.assertIn('--ansi', self.menu()['options'])

    def test_agent_stamps_override_activity_and_invalid_stamp_falls_back(self):
        stamps = self.path / 'tmux-agent-activity'
        stamps.mkdir()
        (stamps / '%1').write_text('0199990\n')
        (stamps / '%2').write_text('invalid\n')
        result = self.run_selector('select-agent-window', [
            row(100, '%1', '$1', '@11', 'work', '1:claude*', 'claude', '2_1_217', '✳ Raw title', 'fg=yellow'),
            row(199000, '%2', '$2', '@22', 'other', '2:codex-', 'codex', 'codex', '', 'default'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.menu()['rows'], [
            '$1:@11\t[work] 1:claude* (active 10s ago) "\x1b[33mRaw title\x1b[39m"',
            '$2:@22\t[other] 2:codex- (active 16m ago)',
        ])
        self.assertIn('start:pos(1)', self.menu()['options'])
        self.assertIn('--ansi', self.menu()['options'])

    def test_agent_titles_use_hook_status_colors_only(self):
        result = self.run_selector('select-agent-window', [
            row(200000, '%1', '$1', '@11', 'work', '1:claude', 'claude', 'claude', 'Green', 'fg=green'),
            row(199999, '%2', '$1', '@12', 'work', '2:codex', 'codex', 'codex', 'Yellow', 'fg=yellow'),
            row(199998, '%3', '$1', '@13', 'work', '3:claude', 'claude', 'claude', 'Red', 'fg=red'),
            row(199997, '%4', '$1', '@14', 'work', '4:codex', 'codex', 'codex', 'Idle', 'default'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.menu()['rows'], [
            '$1:@11\t[work] 1:claude (active 0s ago) "\x1b[32mGreen\x1b[39m"',
            '$1:@12\t[work] 2:codex (active 1s ago) "\x1b[33mYellow\x1b[39m"',
            '$1:@13\t[work] 3:claude (active 2s ago) "\x1b[31mRed\x1b[39m"',
            '$1:@14\t[work] 4:codex (active 3s ago) "Idle"',
        ])
        self.assertIn('--ansi', self.menu()['options'])

    def test_agent_detection_uses_names_and_commands_not_titles(self):
        result = self.run_selector('select-agent-window', [
            row(199999, '%1', '$1', '@11', 'work', '1:editor*', 'editor', 'fish', '🚀 Release notes', 'default'),
            row(199998, '%2', '$2', '@22', 'other', '2:custom', 'custom', 'codex-aarch64-apple-darwin', 'Title', 'default'),
            row(199997, '%3', '$3', '@33', 'third', '1:custom', 'custom', 'claude', '', 'default'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.menu()['rows']), 2)
        self.assertEqual(self.commands()[-1][-1], '$2:@22')
        self.assertNotIn('start:pos(1)', self.menu()['options'])

    def test_future_activity_clamps_to_zero(self):
        result = self.run_selector('select-window', [
            row('@11', 'work', '1:fish*', 1, 0, 200001, 'Title', 'default'),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn('(active 0s ago)', self.menu()['rows'][0])

    def test_duration_boundaries(self):
        result = subprocess.run([
            '/bin/bash', '-c',
            'source "$1/selector-common.sh"; '
            'for seconds in -1 0 59 60 3599 3600 86399 86400; do '
            'humanize_duration "$seconds"; printf "\\n"; done',
            'duration-test', str(SCRIPTS),
        ], env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(),
                         ['0s', '0s', '59s', '1m', '59m', '1h', '23h', '1d'])

    def test_no_agents_does_not_open_fzf_or_switch(self):
        result = self.run_selector('select-agent-window', [
            row(200000, '%1', '$1', '@11', 'work', '1:fish*', 'fish', 'fish', ''),
        ])
        self.assertEqual(result.returncode, 1)
        self.assertIn('No claude or codex', result.stderr)
        self.assertFalse((self.path / 'menu').exists())
        self.assertEqual(len(self.commands()), 1)

    def test_cancel_empty_selection_and_fzf_error_never_switch(self):
        for env, expected in [({'FZF_STATUS': '130'}, 0),
                              ({'EMPTY_SELECTION': '1'}, 0),
                              ({'FZF_STATUS': '2'}, 2)]:
            with self.subTest(env=env):
                result = self.run_selector('select-window', [
                    row('@11', 'work', '1:fish*', 1, 0, 200000, '', 'default'),
                ], **env)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(len(self.commands()), 1)

    def test_failed_query_with_partial_output_never_opens_fzf(self):
        for name in ['select-session', 'select-window', 'select-agent-window']:
            with self.subTest(name=name):
                result = self.run_selector(name, ['partial output'], QUERY_STATUS='1')
                self.assertEqual(result.returncode, 1)
                self.assertFalse((self.path / 'menu').exists())
                self.assertEqual(len(self.commands()), 1)


if __name__ == '__main__':
    unittest.main()
