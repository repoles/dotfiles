"""Tests for tmux-toast.sh. Run with python3 -m unittest discover -s tests."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest


class TmuxToastTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmux = shutil.which('tmux')
        if not cls.tmux:
            raise unittest.SkipTest('tmux 3.7+ is required')
        cls.directory = tempfile.TemporaryDirectory(prefix='tmux-toast-test-')
        cls.addClassCleanup(cls.directory.cleanup)
        cls.socket = str(Path(cls.directory.name) / 'socket')
        cls.env = dict(os.environ)
        cls.env.pop('TMUX', None)
        cls.env.pop('TMUX_PANE', None)
        cls.command('-f', '/dev/null', 'new-session', '-d', '-s', 'toast-test',
                    '-x', '100', '-y', '40', 'sleep', '120')
        cls.addClassCleanup(cls.command, 'kill-server')
        cls.env['TMUX'] = cls.command(
            'display-message', '-p', '#{socket_path},#{pid},#{session_id}'
        ).stdout.strip()
        cls.script = (Path(__file__).resolve().parents[1]
                      / 'tmux/.config/tmux/scripts/tmux-toast.sh')

    @classmethod
    def command(cls, *args):
        return subprocess.run([cls.tmux, '-S', cls.socket, *args], env=cls.env,
                              text=True, capture_output=True, check=True)

    def tearDown(self):
        for pane in self.command('list-panes', '-F',
                                 '#{pane_id} #{@toast}').stdout.splitlines():
            if pane.endswith(' 1'):
                self.command('kill-pane', '-t', pane.split()[0])

    def assert_toast(self, width, lines, expected):
        subprocess.run(['sh', str(self.script), '-w', str(width), '-d', '30',
                        *lines], env=self.env, capture_output=True,
                       text=True, check=True)
        panes = self.command('list-panes', '-F',
                             '#{pane_id} #{@toast} #{pane_height} #{pane_active}'
                             ).stdout.splitlines()
        toast = [p.split() for p in panes if len(p.split()) == 4]
        self.assertEqual(len(toast), 1)
        pane, marker, height, active = toast[0]
        self.assertEqual(marker, '1')
        self.assertEqual(height, str(len(expected)))
        # Pane output is asynchronous; wait for the expected content to arrive.
        deadline = time.monotonic() + 3
        while True:
            actual = self.command('capture-pane', '-p', '-t', pane).stdout
            if actual == '\n'.join(expected) + '\n' or time.monotonic() >= deadline:
                break
            time.sleep(.02)
        self.assertEqual(actual, '\n'.join(expected) + '\n')
        self.assertEqual(active, '0')

    def test_long_line_keeps_beginning_and_end(self):
        self.assert_toast(10, ['abcdefghijklmnopqrst'],
                          [' abcdefghi', ' jklmnopqr', ' st'])

    def test_embedded_newlines(self):
        self.assert_toast(34, ['first\nsecond', 'third'],
                          [' first', ' second', ' third'])

    def test_exact_width_has_no_extra_row(self):
        self.assert_toast(10, ['123456789'], [' 123456789'])

    def test_short_lines_are_unchanged(self):
        self.assert_toast(34, ['hello', 'world'], [' hello', ' world'])

    def test_blank_lines_and_trailing_newline(self):
        # A padded blank line is a lone space, which capture-pane trims.
        self.assert_toast(34, ['first\n\nsecond\n'], [' first', '', ' second', ''])

    def test_unicode_uses_display_columns(self):
        self.assert_toast(10, ['ação漢字xy'], [' ação漢字x', ' y'])

    def test_tabs_are_expanded_before_wrapping(self):
        # Tab stops are relative to the text, not to the padded line. The
        # expanded run of spaces is both the fold point and trailing
        # whitespace capture-pane trims, so the split into two lines is what
        # shows the tab was expanded: unexpanded, 'a\tbcd' would fit on one.
        self.assert_toast(10, ['a\tbcd'], [' a', ' bcd'])

    def test_invalid_duration_preserves_existing_toast(self):
        self.assert_toast(34, ['existing toast'], [' existing toast'])
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        for duration in ['', 'invalid', '-1', '.', '1.2.3', 'nan', 'inf', '1s', '1\n2']:
            with self.subTest(duration=duration):
                result = subprocess.run(
                    ['sh', str(self.script), '-d', duration, 'replacement'],
                    env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('invalid duration', result.stderr)
                self.assertEqual(self.command('list-panes', '-F',
                                              '#{pane_id}').stdout, before)

    def test_maximum_width_preserves_borders_and_margin(self):
        self.assert_toast(96, ['x' * 96], [' ' + 'x' * 95, ' x'])
        panes = self.command('list-panes', '-F',
                             '#{@toast} #{pane_left} #{pane_width} #{window_width}').stdout
        self.assertIn('1 1 96 100', panes.splitlines())

    def test_excessive_width_preserves_existing_toast(self):
        self.assert_toast(34, ['existing toast'], [' existing toast'])
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        for width in ['97', '101', '18446744073709551616']:
            with self.subTest(width=width):
                result = subprocess.run(
                    ['sh', str(self.script), '-w', width, 'replacement'],
                    env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('use at most 96 columns', result.stderr)
                self.assertEqual(self.command('list-panes', '-F',
                                              '#{pane_id}').stdout, before)

    def test_width_limit_tracks_window_size(self):
        try:
            self.command('resize-window', '-x', '12', '-y', '40')
            self.assert_toast(8, ['123456789'], [' 1234567', ' 89'])
            self.command('resize-window', '-x', '11', '-y', '40')
            before = self.command('list-panes', '-F', '#{pane_id}').stdout
            result = subprocess.run(['sh', str(self.script), '-w', '8', 'replacement'],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('window is too narrow', result.stderr)
            self.assertEqual(self.command('list-panes', '-F', '#{pane_id}').stdout, before)
        finally:
            self.command('resize-window', '-x', '100', '-y', '40')

    def test_valid_durations_expire(self):
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        for duration in ['0', '.1', '0.1', '1.']:
            with self.subTest(duration=duration):
                subprocess.run(['sh', str(self.script), '-d', duration, 'hello'],
                               env=self.env, capture_output=True, text=True, check=True)
                deadline = time.monotonic() + 3
                while True:
                    panes = self.command('list-panes', '-F', '#{pane_id}').stdout
                    if panes == before or time.monotonic() >= deadline:
                        break
                    time.sleep(.02)
                self.assertEqual(panes, before)

    def test_scheduling_failure_removes_created_pane(self):
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        with tempfile.TemporaryDirectory(prefix='tmux-toast-failure-') as directory:
            wrapper = Path(directory) / 'tmux'
            wrapper.write_text(
                '#!/bin/sh\n'
                'if [ "$1" = run-shell ]; then\n'
                '  echo "simulated scheduling failure" >&2\n'
                '  exit 1\n'
                'fi\n'
                f'exec {shlex.quote(self.tmux)} "$@"\n')
            wrapper.chmod(0o755)
            env = dict(self.env, PATH=directory + os.pathsep + self.env['PATH'])
            result = subprocess.run(['sh', str(self.script), '-d', '1', 'hello'],
                                    env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('simulated scheduling failure', result.stderr)
        self.assertEqual(self.command('list-panes', '-F', '#{pane_id}').stdout, before)


if __name__ == '__main__':
    unittest.main()
