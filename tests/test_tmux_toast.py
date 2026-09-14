"""Tests for tmux-toast.sh. Run with python3 -m unittest discover -s tests."""

import contextlib
import concurrent.futures
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

    # Rows a message has to take to be denied room over a toast resting on
    # the floor of this 40 row window: that toast starts on row 37, and a
    # margin row, two borders and the margin over the new toast stand between
    # them, so 32 rows still fit.
    crowding_out = ['line %d' % row for row in range(33)]

    def top(self, pane):
        return self.command('display-message', '-p', '-t', pane,
                            '#{pane_top}').stdout.strip()

    def toast_panes(self):
        # Every window on the server, not just the ambient one: a toast goes
        # to the window the user is on, which may be in another session.
        return [pane.split()[0] for pane
                in self.command('list-panes', '-a', '-F',
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
    def attached_client(self, session='toast-test'):
        """Attach a client on a pty, so tmux has somewhere to report to."""
        master, slave = pty.openpty()
        # The window follows the newest client, so keep the client at the size
        # the other tests expect, plus the row the status line takes.
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 41, 100, 0, 0))
        client = subprocess.Popen([self.tmux, '-S', self.socket, 'attach',
                                   '-t', session],
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
        asked = [] if width is None else ['-w', str(width)]
        subprocess.run(['sh', str(self.script), *asked, '-d', '30',
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
                          [' abcdefgh', ' ijklmnop', ' qrst'])

    def test_embedded_newlines(self):
        self.assert_toast(34, ['first\nsecond', 'third'],
                          [' first', ' second', ' third'])

    def test_exact_width_has_no_extra_row(self):
        self.assert_toast(10, ['12345678'], [' 12345678'])

    def test_short_lines_are_unchanged(self):
        self.assert_toast(34, ['hello', 'world'], [' hello', ' world'])

    def test_blank_lines_and_trailing_newline(self):
        # A padded blank line is a lone space, which capture-pane trims.
        self.assert_toast(34, ['first\n\nsecond\n'], [' first', '', ' second', ''])

    def test_unicode_uses_display_columns(self):
        self.assert_toast(10, ['ação漢字xy'], [' ação漢字', ' xy'])

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
        self.assert_toast(94, ['x' * 94], [' ' + 'x' * 92, ' xx'])
        panes = self.command('list-panes', '-F',
                             '#{@toast} #{pane_left} #{pane_width} #{window_width}').stdout
        # Two columns of margin on each side of the two border columns, so the
        # widest toast stands as far off the left edge as off the right.
        self.assertIn('1 3 94 100', panes.splitlines())

    def test_maximum_height_preserves_borders_and_margin(self):
        lines = ['row %d' % row for row in range(40)]
        self.assert_toast(34, lines, [' ' + line for line in lines[:35]] + [' …'])
        panes = self.command('list-panes', '-F',
                             '#{@toast} #{pane_top} #{pane_height} #{window_height}').stdout
        # A row of margin over the top border and under the bottom one, so the
        # tallest toast stands as far off the top edge as off the bottom.
        self.assertIn('1 2 36 40', panes.splitlines())

    def test_excessive_width_preserves_existing_toast(self):
        self.assert_toast(34, ['existing toast'], [' existing toast'])
        before = self.command('list-panes', '-F', '#{pane_id}').stdout
        for width in ['95', '101', '18446744073709551616']:
            with self.subTest(width=width):
                result = subprocess.run(
                    ['sh', str(self.script), '-w', width, 'replacement'],
                    env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('use at most 94 columns', result.stderr)
                self.assertEqual(self.command('list-panes', '-F',
                                              '#{pane_id}').stdout, before)

    def test_width_limit_tracks_window_size(self):
        try:
            self.command('resize-window', '-x', '14', '-y', '40')
            self.assert_toast(8, ['123456789'], [' 123456', ' 789'])
            self.command('resize-window', '-x', '13', '-y', '40')
            before = self.command('list-panes', '-F', '#{pane_id}').stdout
            result = subprocess.run(['sh', str(self.script), '-w', '8', 'replacement'],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('window is too narrow', result.stderr)
            self.assertEqual(self.command('list-panes', '-F', '#{pane_id}').stdout, before)
        finally:
            self.command('resize-window', '-x', '100', '-y', '40')

    def geometry(self):
        """Every toast up, as its left column and its width."""
        return self.command('list-panes', '-F',
                            '#{@toast} #{pane_left} #{pane_width}'
                            ).stdout.splitlines()

    # The left column is asserted along with the width so that each of these
    # also stands for the right edge the box was laid out from: in this 100
    # column window the two come to 97 whatever the text turns out to measure.
    def test_automatic_width_fits_the_text(self):
        self.assert_toast(None, ['x' * 30], [' ' + 'x' * 30])
        self.assertIn('1 65 32', self.geometry())

    def test_automatic_width_uses_display_columns(self):
        # Twelve characters standing in twenty four columns. Measured as bytes
        # they would read as thirty six and the box would come out at its cap.
        self.assert_toast(None, ['漢字' * 6], [' ' + '漢字' * 6])
        self.assertIn('1 71 26', self.geometry())

    def test_automatic_width_measures_the_text_and_not_a_format(self):
        # The measurement puts the text in a tmux option, so a message of this
        # shape is the one that would come back expanded: 24 columns as it
        # stands, and 12 - short enough to be held up by the floor - if tmux
        # were to read it.
        self.assert_toast(None, ['#{window_width} abcdefgh'],
                          [' #{window_width} abcdefgh'])
        self.assertIn('1 71 26', self.geometry())

    def test_automatic_width_holds_a_floor(self):
        self.assert_toast(None, ['hi'], [' hi'])
        self.assertIn('1 77 20', self.geometry())

    def test_automatic_width_stops_at_the_default(self):
        self.assert_toast(None, ['x' * 50], [' ' + 'x' * 40, ' ' + 'x' * 10])
        self.assertIn('1 55 42', self.geometry())

    def test_automatic_width_fits_a_narrow_window(self):
        # The floor gives way to the window: 20 columns do not fit here, and a
        # toast at the widest the window allows is worth more than none.
        try:
            self.command('resize-window', '-x', '14', '-y', '40')
            self.assert_toast(None, ['123456789'], [' 123456', ' 789'])
            self.assertIn('1 3 8', self.geometry())
        finally:
            self.command('resize-window', '-x', '100', '-y', '40')

    def test_measuring_the_text_leaves_no_option_behind(self):
        self.assert_toast(None, ['hello'], [' hello'])
        self.assertNotIn('toast-measure', self.command('show-options', '-w').stdout)

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

    def test_displacing_a_toast_reports_nothing_to_the_client(self):
        with self.attached_client() as tty:
            subprocess.run(['sh', str(self.script), '-d', '1', 'first'],
                           env=self.env, capture_output=True, check=True)
            # Leaves the stack no room, so the first toast is dropped and its
            # timer is left with no pane to kill.
            subprocess.run(['sh', str(self.script), '-d', '30',
                            *self.crowding_out],
                           env=self.env, capture_output=True, check=True)
            time.sleep(2)
            panes = self.command('list-panes', '-F', '#{@toast}').stdout
            # Asserted on how tmux reports rather than on any wording: a failed
            # command shows its output and status in view mode, and an error
            # from -C is shown to the client instead.
            modes = self.command('list-panes', '-a', '-F', '#{pane_mode}').stdout
            messages = [line for line in self.command('show-messages').stdout.splitlines()
                        if '%s message:' % tty in line]
        self.assertIn('1', panes.split(), 'the new toast should still be up')
        self.assertEqual(modes.split(), [], 'the timer left a pane in a mode')
        self.assertEqual(messages, [], 'tmux reported the timer to the client')

    def test_a_dropped_toast_that_disappears_before_cleanup_is_not_missed(self):
        self.assert_toast(34, ['old'], [' old'])
        old, = self.toast_panes()
        with tempfile.TemporaryDirectory(prefix='tmux-toast-expiry-') as directory:
            wrapper = Path(directory) / 'tmux'
            # Reproduce expiry after the dropped pane was recorded but before
            # the final cleanup, without depending on timer timing.
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
            result = subprocess.run(['sh', str(self.script), '-d', '30',
                                     *self.crowding_out],
                                    env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        new, = self.toast_panes()
        self.assertNotEqual(new, old)
        self.assertEqual(self.command('capture-pane', '-p', '-t', new).stdout,
                         '\n'.join(' ' + line for line in self.crowding_out) + '\n')

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
            # Tall enough that the stack has to be dropped, so the sweep runs
            # at all: a toast that finds room above the last one kills nothing.
            subprocess.run(['sh', str(self.script), '-d', '30',
                            *self.crowding_out],
                           env=self.env, capture_output=True, check=True)
            panes = self.command('list-panes', '-F', '#{pane_id}').stdout.split()
            self.assertIn(worked_in, panes, 'swept a pane being worked in')
            self.assertIn(floating, panes, "swept someone else's floating pane")
            self.assertNotIn(toast, panes, 'left the dropped toast up')
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

    def test_a_toast_that_cannot_be_raised_spares_the_one_up(self):
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

    def test_a_second_toast_stacks_above_the_first(self):
        self.assert_toast(34, ['first'], [' first'])
        first, = self.toast_panes()
        subprocess.run(['sh', str(self.script), '-d', '30', 'second\nline'],
                       env=self.env, capture_output=True, check=True)
        second, = [pane for pane in self.toast_panes() if pane != first]
        # Of the 40 rows, the first toast holds 36 to 38 and leaves 39 as the
        # margin under it. The second takes 31 to 34, so row 35 is left
        # between them: two cards rather than one rule of doubled borders.
        self.assertEqual(self.top(first), '37')
        self.assertEqual(self.top(second), '32')
        self.assertEqual(self.command('capture-pane', '-p', '-t', first).stdout,
                         ' first\n', 'the first toast lost its text')

    def test_concurrent_toasts_have_separate_positions(self):
        with tempfile.TemporaryDirectory(prefix='tmux-toast-concurrent-') as directory:
            wrapper = Path(directory) / 'tmux'
            # Widen the interval between reading the stack and creating a pane.
            # Without serialization, all four callers choose the same position.
            wrapper.write_text(
                '#!/bin/sh\n'
                'if [ "$1" = new-pane ]; then sleep .2; fi\n'
                'exec %s "$@"\n' % shlex.quote(self.tmux))
            wrapper.chmod(0o755)
            env = dict(self.env, PATH=directory + os.pathsep + self.env['PATH'])
            start = threading.Barrier(4)

            def raise_toast(number):
                start.wait(timeout=5)
                return subprocess.run(
                    ['sh', str(self.script), '-d', '30', str(number)],
                    env=env, capture_output=True, text=True, timeout=5)

            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                results = list(pool.map(raise_toast, range(4)))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        panes = self.toast_panes()
        self.assertEqual(len(panes), 4)
        self.assertEqual(sorted(int(self.top(pane)) for pane in panes),
                         [25, 29, 33, 37])

    def test_a_failed_toast_does_not_block_the_next_one(self):
        for failing in ('new-pane', 'run-shell'):
            with self.subTest(failing=failing):
                with self.tmux_failing_on(failing) as env:
                    result = subprocess.run(
                        ['sh', str(self.script), '-d', '30', 'failed'],
                        env=env, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 1)
                result = subprocess.run(
                    ['sh', str(self.script), '-d', '30', 'next'],
                    env=self.env, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_switching_windows_does_not_redirect_a_toast(self):
        original = self.command('display-message', '-p', '#{window_id}').stdout.strip()
        other, = [window for window in self.command(
            'list-windows', '-F', '#{window_id}').stdout.split() if window != original]
        try:
            with tempfile.TemporaryDirectory(prefix='tmux-toast-window-') as directory:
                wrapper = Path(directory) / 'tmux'
                wrapper.write_text(
                    '#!/bin/sh\n'
                    'if [ "$1" = list-panes ]; then\n'
                    '  %s "$@" || exit 1\n'
                    '  %s select-window -t %s\n'
                    '  exit\n'
                    'fi\n'
                    'exec %s "$@"\n' % (shlex.quote(self.tmux),
                                           shlex.quote(self.tmux),
                                           shlex.quote(other), shlex.quote(self.tmux)))
                wrapper.chmod(0o755)
                env = dict(self.env, PATH=directory + os.pathsep + self.env['PATH'])
                result = subprocess.run(
                    ['sh', str(self.script), '-d', '30', 'hello'],
                    env=env, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
            locations = self.command('list-panes', '-a', '-F',
                                     '#{window_id} #{pane_floating_flag}').stdout.splitlines()
            self.assertEqual([line for line in locations if line.endswith(' 1')],
                             [original + ' 1'])
        finally:
            self.command('select-window', '-t', original)
            # Also remove a misplaced toast if the assertion caught a regression.
            for pane in self.command('list-panes', '-a', '-F',
                                     '#{pane_id} #{pane_floating_flag}').stdout.splitlines():
                if pane.endswith(' 1'):
                    self.command('kill-pane', '-t', pane.split()[0])

    def test_the_stack_fills_up_to_the_top_margin(self):
        self.assert_toast(34, ['first'], [' first'])
        first, = self.toast_panes()
        subprocess.run(['sh', str(self.script), '-d', '30',
                        *self.crowding_out[:-1]],
                       env=self.env, capture_output=True, check=True)
        panes = self.toast_panes()
        self.assertEqual(len(panes), 2, 'a toast that fits dropped the stack')
        second, = [pane for pane in panes if pane != first]
        # One row short of crowding the first toast out: the text runs from
        # row 2 to row 33, which leaves row 1 for the top border and row 0 as
        # the margin over it.
        self.assertEqual(self.top(second), '2')

    def test_a_toast_the_stack_cannot_hold_starts_again_from_the_bottom(self):
        self.assert_toast(34, ['first'], [' first'])
        first, = self.toast_panes()
        subprocess.run(['sh', str(self.script), '-d', '30', *self.crowding_out],
                       env=self.env, capture_output=True, check=True)
        panes = self.toast_panes()
        self.assertEqual(panes, [pane for pane in panes if pane != first],
                         'kept a toast the new one had no room above')
        self.assertEqual(len(panes), 1)
        # Back on the floor, at the size it would have had on an empty window:
        # a message cut down to the room left over is the worse of the two.
        self.assertEqual(self.top(panes[0]), '5')
        self.assertEqual(self.command('capture-pane', '-p', '-t', panes[0]).stdout,
                         '\n'.join(' ' + line for line in self.crowding_out) + '\n')

    # A toast is only read where the user is looking, and -o is the caller
    # saying which window it is about so it can be held back when that window
    # is the one on screen. Both answers come from the attached clients, which
    # is what carries across sessions: a session switched away from keeps a
    # current window, so #{window_active} still reads 1 for a window nobody is
    # watching and #{session_attached} reads 0 for one the user left a moment
    # ago on a client that is still very much there.

    @contextlib.contextmanager
    def other_session(self):
        """A second session, so a toast can be asked for from outside."""
        self.command('new-session', '-d', '-s', 'toast-elsewhere',
                     '-x', '100', '-y', '40', 'sleep', '120')
        try:
            yield self.command('list-panes', '-t', 'toast-elsewhere', '-F',
                               '#{window_id}').stdout.split()[0]
        finally:
            self.command('kill-session', '-t', 'toast-elsewhere', check=False)

    def watched_window(self):
        return self.command('list-clients', '-F', '#{window_id}').stdout.split()[0]

    def windows(self):
        return self.command('list-windows', '-F', '#{window_id}').stdout.split()

    def raise_toast(self, *arguments):
        # Run from inside a pane of the ambient session, the way both callers
        # do: with TMUX_PANE set, an ambient target resolves to that session's
        # current window rather than to the window a client is on, so the two
        # only agree while the user has stayed put.
        pane = self.command('display-message', '-p', '-t', 'toast-test',
                            '#{pane_id}').stdout.strip()
        return subprocess.run(['sh', str(self.script), '-d', '30', *arguments],
                              env=dict(self.env, TMUX_PANE=pane),
                              capture_output=True, text=True, timeout=10)

    def assert_landed_on(self, window):
        pane, = self.toast_panes()
        self.assertEqual(self.command('display-message', '-p', '-t', pane,
                                      '#{window_id}').stdout.strip(), window)

    def test_a_toast_about_the_window_on_screen_is_held_back(self):
        with self.attached_client():
            watched = self.watched_window()
            result = self.raise_toast('-o', watched, 'hello')
            self.assertEqual(result.returncode, 3, result.stderr)
            self.assertEqual(self.toast_panes(), [])

    def test_a_toast_about_another_window_lands_where_the_user_is(self):
        with self.attached_client():
            watched = self.watched_window()
            other, = [window for window in self.windows() if window != watched]
            result = self.raise_toast('-o', other, 'hello')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_landed_on(watched)

    def test_a_toast_from_a_session_the_user_left_still_lands(self):
        # The window it is about is the current one of its own session and
        # that session has no client, which is every sign of being watched
        # that a single session can give while the user is in another one.
        with self.other_session() as elsewhere:
            with self.attached_client(session='toast-elsewhere'):
                watched = self.watched_window()
                self.assertEqual(watched, elsewhere)
                # Named against the session and not the ambient window, which
                # tmux resolves through the attached client and so answers
                # with the window the user moved to.
                origin, = [window.split()[1] for window in self.command(
                    'list-windows', '-t', 'toast-test', '-F',
                    '#{window_active} #{window_id}').stdout.splitlines()
                    if window.startswith('1 ')]
                result = self.raise_toast('-o', origin, 'hello')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assert_landed_on(elsewhere)

    def test_a_toast_follows_the_user_into_another_session(self):
        # Asked for from one session with the only client in another: the
        # ambient window would put the toast where nobody would ever read it.
        with self.other_session() as elsewhere:
            with self.attached_client(session='toast-elsewhere'):
                self.assertEqual(self.raise_toast('hello').returncode, 0)
                self.assert_landed_on(elsewhere)

    def test_a_toast_is_held_back_when_no_one_is_attached(self):
        # Without -o the toast still goes up, which is what the rest of the
        # suite runs on; asking for one only while the user is elsewhere is
        # asking for a user, and a pane raised for nobody is gone by the time
        # anyone attaches.
        self.assertEqual(self.command('list-clients', '-F', 'x').stdout, '')
        origin = self.command('display-message', '-p', '#{window_id}').stdout.strip()
        result = self.raise_toast('-o', origin, 'hello')
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(self.toast_panes(), [])

    def test_a_toast_is_held_back_for_a_window_a_second_client_is_on(self):
        # One terminal is on the window it is about, so the user has already
        # been told by the thing itself; the newest client being elsewhere
        # does not make that screen any less visible.
        with self.other_session() as elsewhere:
            with self.attached_client():
                watched = self.watched_window()
                with self.attached_client(session='toast-elsewhere'):
                    result = self.raise_toast('-o', watched, 'hello')
                    self.assertEqual(result.returncode, 3, result.stderr)
                    self.assertEqual(self.toast_panes(), [])
                    # The newest client is where an unheld one would land.
                    self.assertEqual(self.raise_toast('-o', elsewhere,
                                                      'hello').returncode, 3)

    def test_a_toast_lands_on_the_client_last_used(self):
        with self.other_session() as elsewhere:
            with self.attached_client():
                time.sleep(1.1)  # client_activity counts whole seconds
                with self.attached_client(session='toast-elsewhere'):
                    self.assertEqual(self.raise_toast('hello').returncode, 0)
                    self.assert_landed_on(elsewhere)

    def test_control_characters_cannot_drive_the_pane(self):
        # Interpreted instead of dropped, the carriage return would overwrite
        # the padding, the escape would colour the pane, and both would spend
        # columns that fold counted: the text would read ' cdef' in red.
        self.assert_toast(14, ['ab\rcd\x1b[31mef\x07'], [' abcd[31mef'])


if __name__ == '__main__':
    unittest.main()
