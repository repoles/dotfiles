"""Tests for tmux-toast.sh. Run with python3 -m unittest discover -s tests."""

import contextlib
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import struct
import subprocess
import tempfile
import termios
import threading
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
        # A second window keeps the session alive even if a bug sweeps every
        # pane of the first, so such a failure reads as one assertion rather
        # than as a dead server taking the rest of the suite with it.
        cls.command('new-window', '-d', 'sleep', '120')
        cls.env['TMUX'] = cls.command(
            'display-message', '-p', '#{socket_path},#{pid},#{session_id}'
        ).stdout.strip()
        cls.script = (Path(__file__).resolve().parents[1]
                      / 'tmux/.config/tmux/scripts/tmux-toast.sh')

    @classmethod
    def command(cls, *args, check=True):
        return subprocess.run([cls.tmux, '-S', cls.socket, *args], env=cls.env,
                              text=True, capture_output=True, check=check)

    def tearDown(self):
        # Matched on the floating flag as well: a test that leaves @toast set
        # outside a pane would otherwise sweep the session's own pane away.
        for pane in self.toast_panes():
            self.command('kill-pane', '-t', pane)
        # A pane tmux dropped into view mode would outlive a failing test.
        for pane in self.command('list-panes', '-a', '-F',
                                 '#{pane_id} #{pane_mode}').stdout.split():
            if pane.startswith('%'):
                current = pane
            else:
                self.command('send-keys', '-t', current, '-X', 'cancel')

    def toast_panes(self):
        return [pane.split()[0] for pane
                in self.command('list-panes', '-F',
                                '#{pane_id} #{@toast}#{pane_floating_flag}'
                                ).stdout.splitlines() if pane.endswith(' 11')]

    @contextlib.contextmanager
    def tmux_failing_on(self, subcommand):
        """Yield an environment whose tmux fails that one subcommand."""
        with tempfile.TemporaryDirectory(prefix='tmux-toast-failure-') as directory:
            wrapper = Path(directory) / 'tmux'
            wrapper.write_text(
                '#!/bin/sh\n'
                'if [ "$1" = %s ]; then\n'
                '  echo "simulated %s failure" >&2\n'
                '  exit 1\n'
                'fi\n'
                'exec %s "$@"\n' % (subcommand, subcommand, shlex.quote(self.tmux)))
            wrapper.chmod(0o755)
            yield dict(self.env, PATH=directory + os.pathsep + self.env['PATH'])

    @contextlib.contextmanager
    def attached_client(self):
        """Attach a client on a pty, so tmux has somewhere to report to."""
        master, slave = pty.openpty()
        # The window follows the newest client, so keep the client at the size
        # the other tests expect, plus the row the status line takes.
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 41, 100, 0, 0))
        client = subprocess.Popen([self.tmux, '-S', self.socket, 'attach',
                                   '-t', 'toast-test'],
                                  stdin=slave, stdout=slave, stderr=slave,
                                  env=self.env)
        os.close(slave)
        done = threading.Event()

        def drain():
            """Keep reading, or the pty fills up and the client blocks."""
            while not done.is_set():
                if select.select([master], [], [], .05)[0]:
                    try:
                        if not os.read(master, 65536):
                            break
                    except OSError:
                        break

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()
        try:
            deadline = time.monotonic() + 5
            while not self.command('list-clients', '-F',
                                   '#{client_tty}').stdout.strip():
                self.assertLess(time.monotonic(), deadline, 'client never attached')
                time.sleep(.02)
            yield self.command('list-clients', '-F', '#{client_tty}').stdout.strip()
        finally:
            done.set()
            reader.join(1)
            client.terminate()
            client.wait(5)
            os.close(master)

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

    def test_replacing_a_toast_reports_nothing_to_the_client(self):
        with self.attached_client() as tty:
            subprocess.run(['sh', str(self.script), '-d', '1', 'first'],
                           env=self.env, capture_output=True, check=True)
            # Replaces the first toast, leaving its timer with no pane to kill.
            subprocess.run(['sh', str(self.script), '-d', '30', 'second'],
                           env=self.env, capture_output=True, check=True)
            time.sleep(2)
            panes = self.command('list-panes', '-F', '#{@toast}').stdout
            # Asserted on how tmux reports rather than on any wording: a failed
            # command shows its output and status in view mode, and an error
            # from -C is shown to the client instead.
            modes = self.command('list-panes', '-a', '-F', '#{pane_mode}').stdout
            messages = [line for line in self.command('show-messages').stdout.splitlines()
                        if '%s message:' % tty in line]
        self.assertIn('1', panes.split(), 'the replacement toast should still be up')
        self.assertEqual(modes.split(), [], 'the timer left a pane in a mode')
        self.assertEqual(messages, [], 'tmux reported the timer to the client')

    def test_replacement_succeeds_when_old_toast_disappears_before_cleanup(self):
        self.assert_toast(34, ['old'], [' old'])
        old, = self.toast_panes()
        with tempfile.TemporaryDirectory(prefix='tmux-toast-expiry-') as directory:
            wrapper = Path(directory) / 'tmux'
            # Reproduce expiry after the old pane was recorded but before the
            # final cleanup, without depending on timer timing.
            wrapper.write_text(
                '#!/bin/sh\n'
                'if [ "$1" = run-shell ]; then\n'
                f'  {shlex.quote(self.tmux)} kill-pane -t {shlex.quote(old)} || exit 1\n'
                'fi\n'
                f'exec {shlex.quote(self.tmux)} "$@"\n')
            wrapper.chmod(0o755)
            env = dict(self.env, PATH=directory + os.pathsep + self.env['PATH'])
            # The script resolves the tmux that it books the removal with from
            # this PATH, so the replacement is scheduled to be killed by a
            # wrapper that is gone by the time the timer fires: it never expires
            # on its own here, and tearDown is what takes it away.
            result = subprocess.run(['sh', str(self.script), '-d', '30', 'new'],
                                    env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        replacement, = self.toast_panes()
        self.assertNotEqual(replacement, old)
        self.assertEqual(self.command('capture-pane', '-p', '-t', replacement).stdout,
                         ' new\n')

    def test_marker_outside_the_pane_spares_the_other_panes(self):
        subprocess.run(['sh', str(self.script), '-d', '30', 'first'],
                       env=self.env, capture_output=True, check=True)
        toast, = self.toast_panes()
        # A user option answers for every pane once it is set anywhere above it.
        self.command('set', '-g', '@toast', '1')
        worked_in = self.command('split-window', '-d', '-P', '-F', '#{pane_id}',
                                 'sleep', '120').stdout.strip()
        floating = self.command('new-pane', '-d', '-P', '-F', '#{pane_id}',
                                '-x', '10', '-y', '2', '-X', '1', '-Y', '1',
                                'sleep', '120').stdout.strip()
        try:
            subprocess.run(['sh', str(self.script), '-d', '30', 'second'],
                           env=self.env, capture_output=True, check=True)
            panes = self.command('list-panes', '-F', '#{pane_id}').stdout.split()
            self.assertIn(worked_in, panes, 'swept a pane being worked in')
            self.assertIn(floating, panes, "swept someone else's floating pane")
            self.assertNotIn(toast, panes, 'left the replaced toast up')
        finally:
            # Tolerant: a regression here is a pane that has already been
            # swept, and the failure above is the one worth reading.
            self.command('set', '-gu', '@toast')
            for pane in (worked_in, floating):
                self.command('kill-pane', '-t', pane, check=False)

    def test_toast_holds_no_process_and_leaves_no_file(self):
        probe = subprocess.run(['mktemp', '-t', 'toast'], text=True,
                               capture_output=True, check=True).stdout.strip()
        temporary = Path(probe).parent
        os.unlink(probe)
        before = set(temporary.glob('toast.*'))
        self.assert_toast(34, ['hello'], [' hello'])
        pane, = self.toast_panes()
        self.assertEqual(self.command('display-message', '-p', '-t', pane,
                                      '#{pane_pid}').stdout.strip(), '0')
        self.assertEqual(set(temporary.glob('toast.*')), before)

    def test_scheduling_failure_removes_created_pane(self):
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        with self.tmux_failing_on('run-shell') as env:
            result = subprocess.run(['sh', str(self.script), '-d', '1', 'hello'],
                                    env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('simulated run-shell failure', result.stderr)
        self.assertEqual(self.command('list-panes', '-F', '#{pane_id}').stdout, before)

    def test_a_toast_that_cannot_be_replaced_is_left_alone(self):
        self.assert_toast(34, ['existing toast'], [' existing toast'])
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        for failing in ('new-pane', 'run-shell'):
            with self.subTest(failing=failing), self.tmux_failing_on(failing) as env:
                result = subprocess.run(['sh', str(self.script), '-d', '30',
                                         'replacement'], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.command('list-panes', '-F',
                                              '#{pane_id}').stdout, before)
        toast = self.toast_panes()
        self.assertEqual(len(toast), 1, 'the toast should have been left alone')
        self.assertEqual(self.command('capture-pane', '-p', '-t', toast[0]).stdout,
                         ' existing toast\n')

    def test_control_characters_cannot_drive_the_pane(self):
        # Interpreted instead of dropped, the carriage return would overwrite
        # the padding, the escape would colour the pane, and both would spend
        # columns that fold counted: the text would read ' cdef' in red.
        self.assert_toast(14, ['ab\rcd\x1b[31mef\x07'], [' abcd[31mef'])


if __name__ == '__main__':
    unittest.main()
