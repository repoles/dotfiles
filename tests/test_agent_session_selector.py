"""Contracts for the selector that resumes agent sessions that never concluded."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
SELECTOR = ROOT / 'tmux/.config/tmux/scripts/select-agent-session.sh'
NOW = 1791030600


class SelectorTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='agent-session-selector-')
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name).resolve()
        self.sessions = self.path / 'state/tmux-agent-sessions'
        self.sessions.mkdir(parents=True)
        self.bin = self.path / 'bin'
        self.bin.mkdir()
        self.repo = self.path / 'repo'
        (self.repo / 'sub').mkdir(parents=True)
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        (self.path / 'other').mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        XDG_STATE_HOME=str(self.path / 'state'), HOME=str(self.path),
                        SELECTOR_CLIENT='/dev/ttys-review', SELECTOR_SESSION='$1',
                        SELECTOR_PATH=str(self.repo / 'sub'))
        for key in ['TMUX', 'TMUX_PANE', 'FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE']:
            self.env.pop(key, None)

    def executable(self, name, contents):
        path = self.bin / name
        path.write_text(contents)
        path.chmod(0o755)

    def record(self, session_id, cwd, last, **fields):
        record = {'tool': 'claude', 'session_id': session_id, 'cwd': str(cwd),
                  'tmux_session': 'work', 'window_index': 2, 'window_name': 'claude',
                  'pane_index': 0, 'pane_title': f'✳ Title {session_id}',
                  'started_at': last - 3600, 'last_prompt_at': last,
                  'agent_pid': None, 'agent_started_at': None}
        record.update(fields)
        (self.sessions / f'{session_id}.json').write_text(json.dumps(record))

    def run_selector(self, *args, **env):
        return subprocess.run(['/bin/bash', str(SELECTOR), *args],
                              env=dict(self.env, **env), capture_output=True, text=True)


class AgentSessionListTest(SelectorTestCase):
    def setUp(self):
        super().setUp()
        # Process 700 is a live agent started at 1791000000; every other PID is gone.
        self.executable('ps', '''#!/bin/sh
[ "$4" = 700 ] || exit 1
printf 'Fri Oct  2 01:39:11 2026    \\n'
''')
        self.executable('date', f'''#!/bin/sh
if [ "$1" = -j ]; then
    [ "$4" = 'Fri Oct 2 01:39:11 2026' ] || exit 1
    echo 1791000000
    exit
fi
echo {NOW}
''')
        self.executable('tmux', '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TMUX_LOG"\n')
        self.env['TMUX_LOG'] = str(self.path / 'tmux.log')

    def entries(self, scope):
        result = self.run_selector('--list', scope)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.splitlines()

    def tmux_calls(self):
        log = self.path / 'tmux.log'
        return log.read_text().splitlines() if log.exists() else []

    def test_lists_the_project_by_last_prompt_without_running_sessions(self):
        self.record('old', self.repo, NOW - 7200, pane_title='⠧ Old one')
        self.record('new', self.repo / 'sub', NOW - 60, tool='codex', window_name='codex',
                    window_index=3)
        self.record('running', self.repo, NOW - 30,
                    agent_pid=700, agent_started_at=1791000000)
        self.record('reused', self.repo, NOW - 30,
                    agent_pid=700, agent_started_at=1790000000)
        self.record('away', self.path / 'other', NOW - 10)
        self.record('sibling', str(self.repo) + '-fork', NOW - 10)

        self.assertEqual(self.entries('here'), [
            'reused\t[work] 2:claude (last prompt 30s ago) "Title reused"',
            'new\t[work] 3:codex (last prompt 1m ago) "Title new"',
            'old\t[work] 2:claude (last prompt 2h ago) "Old one"',
        ])
        self.assertEqual([entry.split('\t')[0] for entry in self.entries('all')],
                         ['away', 'sibling', 'reused', 'new', 'old'])

    def test_titles_drop_a_bare_session_id_and_control_characters(self):
        self.record('bare', self.repo, NOW - 10, pane_title='⠏ bare')
        self.record('tabs', self.repo, NOW - 20, pane_title='Fix\tthe\x1b[31m build')
        self.record('plain', self.repo, NOW - 30, pane_title='')

        self.assertEqual(self.entries('here'), [
            'bare\t[work] 2:claude (last prompt 10s ago)',
            'tabs\t[work] 2:claude (last prompt 20s ago) "Fix the [31m build"',
            'plain\t[work] 2:claude (last prompt 30s ago)',
        ])

    def test_unreadable_records_are_skipped(self):
        self.record('good', self.repo, NOW - 10)
        (self.sessions / 'broken.json').write_text('{')
        (self.sessions / 'bad name.json').write_text('{}')

        self.assertEqual([entry.split('\t')[0] for entry in self.entries('all')], ['good'])

    def test_outside_a_repository_the_project_is_the_directory(self):
        self.record('inside', self.path / 'other', NOW - 10)
        self.record('repo', self.repo, NOW - 20)

        result = self.run_selector('--list', 'here', SELECTOR_PATH=str(self.path / 'other'))

        self.assertEqual([line.split('\t')[0] for line in result.stdout.splitlines()],
                         ['inside'])

    def test_preview_describes_the_session(self):
        self.record('one', self.path / 'other', NOW - 60, tmux_session='work',
                    window_index=4, pane_index=1)

        result = self.run_selector('--preview', 'one')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'claude one', '~/other', '[work] 4:claude.1',
            'started 1h ago, last prompt 1m ago',
        ])

    def test_delete_forgets_only_valid_ids(self):
        self.record('one', self.repo, NOW)
        self.record('two', self.repo, NOW)
        (self.path / 'state/escape.json').write_text('{}')

        result = self.run_selector('--delete', 'one', '../escape', '')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted(p.name for p in self.sessions.iterdir()), ['two.json'])
        self.assertTrue((self.path / 'state/escape.json').exists())

    def test_resume_skips_running_sessions_and_missing_directories(self):
        self.record('running', self.repo, NOW, agent_pid=700, agent_started_at=1791000000)
        self.record('gone', self.path / 'missing', NOW)

        result = self.run_selector('--resume', 'running', 'gone')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.tmux_calls()), 1)
        self.assertIn('running is already running', self.tmux_calls()[0])
        self.assertIn('no longer exists', self.tmux_calls()[0])


class AgentSessionChooserTest(SelectorTestCase):
    def setUp(self):
        super().setUp()
        self.executable('fzf', '''#!/usr/bin/env python3
import json, os, sys
rows = sys.stdin.read().splitlines()
with open(os.environ['MENU'], 'w') as menu:
    json.dump({'rows': rows, 'options': sys.argv[1:]}, menu)
status = int(os.environ.get('FZF_STATUS', '0'))
if status:
    sys.exit(status)
''')
        self.executable('tmux', '#!/bin/sh\nprintf "%s\\n" "$*" >> "$TMUX_LOG"\n')
        self.env.update(MENU=str(self.path / 'menu'), TMUX_LOG=str(self.path / 'tmux.log'))

    def menu(self):
        return json.loads((self.path / 'menu').read_text())

    def option(self, name):
        options = self.menu()['options']
        return options[options.index(name) + 1]

    def binding(self, key):
        options = self.menu()['options']
        return next(options[i + 1][len(key) + 1:] for i, option in enumerate(options)
                    if option == '--bind' and options[i + 1].startswith(key + ':'))

    def test_opens_on_the_project_with_multi_select_and_actions(self):
        now = int(time.time())
        self.record('here', self.repo, now)
        self.record('away', self.path / 'other', now)

        result = self.run_selector()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row.split('\t')[0] for row in self.menu()['rows']], ['here'])
        self.assertEqual(self.option('--prompt'), 'repo> ')
        self.assertIn('--multi', self.menu()['options'])
        self.assertEqual(self.option('--with-shell'), 'bash -c')

    def test_scope_actions_switch_between_the_project_and_all(self):
        self.record('here', self.repo, int(time.time()))
        self.run_selector()
        toggle = self.binding('ctrl-a').removeprefix('transform:')
        forget = self.binding('ctrl-x')

        for prompt, scope, other in [('repo> ', 'here', 'all projects> '),
                                     ('all projects> ', 'all', 'repo> ')]:
            with self.subTest(prompt=prompt):
                action = subprocess.run(['bash', '-c', toggle], capture_output=True,
                                        text=True, env=dict(self.env, FZF_PROMPT=prompt))
                self.assertRegex(action.stdout.strip(),
                                 rf'^change-prompt\({other}\)\+reload\(.* --list '
                                 rf'{"all" if scope == "here" else "here"}\)$')

                reload = forget.split('+transform:', 1)[1]
                action = subprocess.run(['bash', '-c', reload], capture_output=True,
                                        text=True, env=dict(self.env, FZF_PROMPT=prompt))
                self.assertRegex(action.stdout.strip(), rf'^reload\(.* --list {scope}\)$')
        self.assertRegex(forget, r'^execute-silent\(.* --delete \{\+1\}\)\+transform:')

    def test_opens_on_all_projects_when_this_one_has_none(self):
        self.record('away', self.path / 'other', int(time.time()))

        result = self.run_selector()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.option('--prompt'), 'all projects> ')
        self.assertEqual([row.split('\t')[0] for row in self.menu()['rows']], ['away'])

    def test_without_sessions_says_so_and_opens_nothing(self):
        result = self.run_selector()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.path / 'menu').exists())
        self.assertEqual((self.path / 'tmux.log').read_text(),
                         'display-message -c /dev/ttys-review No unfinished agent sessions.\n')

    def test_closing_the_popup_resumes_nothing(self):
        self.record('here', self.repo, int(time.time()))

        for status, expected in [(130, 0), (2, 2)]:
            with self.subTest(status=status):
                result = self.run_selector(FZF_STATUS=str(status))

                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertFalse((self.path / 'tmux.log').exists())

    def test_u_opens_the_selector_from_the_pane_directory(self):
        lines = (ROOT / 'tmux/.config/tmux/tmux.conf').read_text().splitlines()
        binding = next(line for line in lines if line.startswith('bind-key U '))

        self.assertIn('-e SELECTOR_PATH=#{q:pane_current_path}', binding)
        self.assertIn('/tmux/scripts/select-agent-session.sh"', binding)
        # tpm runs last and would rebind U to its plugin update unless told otherwise.
        self.assertIn("set -g @tpm-update 'M-U'", lines)


@unittest.skipUnless(shutil.which('tmux'), 'tmux is required')
class AgentSessionResumeTest(SelectorTestCase):
    """Resume into a real, isolated tmux server; only the agents are fake."""

    def setUp(self):
        super().setUp()
        # tmux runs pane commands through $SHELL. Some shells (fish) keep running as the
        # parent of `sh`, which makes the idle pane look busy, so pin a shell that execs it.
        self.env['SHELL'] = '/bin/sh'
        self.socket = f'resume-{uuid.uuid4().hex[:8]}'
        real = shutil.which('tmux')
        self.executable('tmux', f'#!/bin/sh\nexec {real} -L {self.socket} "$@"\n')
        for agent in ['claude', 'codex']:
            self.executable(agent, '#!/bin/sh\necho "fake $(basename "$0") $*"\n'
                                   'exec sleep 300\n')
        self.addCleanup(lambda: subprocess.run([str(self.bin / 'tmux'), 'kill-server'],
                                               env=self.env, capture_output=True))
        self.tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'work', '-n', 'shell', '-x',
                  '120', '-y', '30', 'sh')
        self.tmux('new-window', '-t', 'work:', '-n', 'claude', 'sh')
        self.tmux('new-window', '-t', 'work:', '-n', 'codex', 'sleep 300')
        self.env['SELECTOR_SESSION'] = self.tmux('display-message', '-p', '-t', 'work',
                                                 '#{session_id}')

    def tmux(self, *args):
        return subprocess.run([str(self.bin / 'tmux'), *args], env=self.env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def windows(self):
        return self.tmux('list-windows', '-a', '-F',
                         '#{session_name}:#{window_index}:#{window_name}:#{monitor-silence}'
                         ).splitlines()

    def agent_output(self, target):
        for _ in range(50):
            output = [line for line in self.tmux('capture-pane', '-p', '-t', target)
                      .splitlines() if line.startswith('fake ')]
            if output:
                return output
            time.sleep(0.1)
        return []

    def test_resumes_in_place_at_the_original_index_or_in_a_new_session(self):
        self.record('idle', self.repo, NOW, window_index=1, window_name='claude')
        self.record('busy', self.repo, NOW, tool='codex', window_index=2,
                    window_name='codex')
        self.record('gone', self.repo, NOW, tmux_session='closed', window_index=4)

        result = self.run_selector('--resume', 'gone', 'busy', 'idle')

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.agent_output('work:1'), ['fake claude --resume idle'])
        self.assertEqual(self.agent_output('work:2'), ['fake codex --no-daemon resume busy'])
        self.assertEqual(self.agent_output('closed:0'), ['fake claude --resume gone'])
        # Sessions list by name; the agents have set up their windows by now.
        self.assertEqual(self.windows(), [
            'closed:0:claude:300',
            'work:0:shell:0', 'work:1:claude:300', 'work:2:codex:300', 'work:3:codex:0',
        ])

        listed = self.run_selector('--list', 'all')
        self.assertEqual(listed.stdout, '')

    def test_a_pane_in_a_renamed_window_is_not_reused(self):
        self.record('moved', self.repo, NOW, window_index=1, window_name='other')

        result = self.run_selector('--resume', 'moved')

        self.assertEqual(result.returncode, 0, result.stderr)
        # A new window takes the original index; the window there now moves after it.
        self.assertEqual(self.agent_output('work:1'), ['fake claude --resume moved'])
        self.assertEqual(self.windows(), [
            'work:0:shell:0', 'work:1:claude:300', 'work:2:claude:0', 'work:3:codex:0',
        ])


if __name__ == '__main__':
    unittest.main()
