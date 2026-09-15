"""Exercise the actual bindings and fzf in an isolated tmux server."""

import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


class TmuxSelectorBindingsTest(unittest.TestCase):
    def test_popups_preserve_context_with_two_clients(self):
        tmux = shutil.which('tmux')
        if not tmux or not shutil.which('fzf'):
            self.skipTest('tmux and fzf are required')
        with tempfile.TemporaryDirectory(prefix='selector-bindings-') as directory:
            path = Path(directory)
            socket = str(path / 'socket')
            (path / 'config').mkdir()
            (path / 'config/tmux').symlink_to(ROOT / 'tmux/.config/tmux')
            (path / 'config/fzf').mkdir()
            defaults = (ROOT / 'fzf/.config/fzf/config').read_text()
            defaults_file = path / 'config/fzf/config'
            defaults_file.write_text(defaults + "\n--header='Shared fzf defaults'\n")
            env = dict(os.environ, TERM='xterm-256color',
                       XDG_CONFIG_HOME=str(path / 'config'),
                       XDG_CACHE_HOME=str(path / 'cache'))
            for key in ['TMUX', 'TMUX_PANE', 'FZF_DEFAULT_OPTS', 'FZF_DEFAULT_OPTS_FILE']:
                env.pop(key, None)
            # Simulate the variable exported by Fish when it starts the server.
            env['FZF_DEFAULT_OPTS_FILE'] = str(defaults_file)

            def command(*args):
                result = subprocess.run([tmux, '-S', socket, *args], env=env,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                return result.stdout.strip()

            def wait_for(predicate, description):
                deadline = time.monotonic() + 5
                while not predicate():
                    self.assertLess(time.monotonic(), deadline, description)
                    time.sleep(.03)

            clients = []

            def attach():
                master, slave = pty.openpty()
                tty = os.ttyname(slave)
                fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 130, 0, 0))
                process = subprocess.Popen([tmux, '-S', socket, 'attach', '-t', 'dotfiles'],
                                           env=env, stdin=slave, stdout=slave, stderr=slave)
                os.close(slave)
                output = bytearray()
                done = threading.Event()

                def drain():
                    while not done.is_set():
                        if select.select([master], [], [], .05)[0]:
                            try:
                                data = os.read(master, 65536)
                                if not data:
                                    break
                                output.extend(data)
                            except OSError:
                                break

                reader = threading.Thread(target=drain, daemon=True)
                reader.start()
                client = (master, process, done, reader, output, tty)
                clients.append(client)
                wait_for(lambda: tty in command('list-clients', '-F', '#{client_name}'),
                         'client never attached')
                return client

            def state(client):
                lines = command('list-clients', '-F',
                                '#{client_name}\t#{session_name}\t#{window_id}').splitlines()
                return next(line.split('\t')[1:] for line in lines
                            if line.startswith(client[5] + '\t'))

            def terminal_text(client, offset):
                return re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '',
                              client[4][offset:].decode('utf-8', 'replace'))

            def popup(client, key, expected):
                offset = len(client[4])
                os.write(client[0], b'\x02' + key.encode())
                try:
                    wait_for(lambda: expected in terminal_text(client, offset),
                             f'{key} popup did not render {expected!r}')
                except AssertionError:
                    self.fail(f'{key} terminal output: {terminal_text(client, offset)[-2000:]!r}')
                # Let fzf finish terminal initialization before sending keys.
                time.sleep(.1)

            def search_and_accept(client, query):
                os.write(client[0], query.encode())
                # fzf filters asynchronously; Enter must follow the new result.
                time.sleep(.3)
                os.write(client[0], b'\r')

            (path / 'initial.conf').write_text('set -g default-shell /bin/sh\n')
            command('-f', str(path / 'initial.conf'), 'new-session', '-d',
                    '-s', 'dotfiles', '-n', 'fish', '/bin/sleep 120')
            try:
                agent = command('new-window', '-d', '-P', '-F', '#{window_id}',
                                '-t', 'dotfiles', '-n', 'codex', '/bin/sleep 120')
                command('select-pane', '-t', agent, '-T', '✳ Revise scripts Fish')
                other = command('new-session', '-d', '-P', '-F', '#{window_id}',
                                '-s', 'work]local', '-n', 'fish', '/bin/sleep 120')
                bindings = '\n'.join(line for line in
                                     (ROOT / 'tmux/.config/tmux/tmux.conf').read_text().splitlines()
                                     if line.startswith(('bind-key S ', 'bind-key W ', 'bind-key A ')))
                (path / 'bindings.conf').write_text(bindings + '\n')
                command('source-file', str(path / 'bindings.conf'))
                self.assertEqual(command('show-environment', '-g', 'FZF_DEFAULT_OPTS_FILE'),
                                 f'FZF_DEFAULT_OPTS_FILE={defaults_file}')
                first, second = attach(), attach()

                popup(first, 'W', 'Shared fzf defaults')
                search_and_accept(first, 'codex')
                wait_for(lambda: state(first)[1] == agent, 'W did not select the agent window')

                # A fresh fzf invocation rereads the file without reloading tmux.
                defaults_file.write_text(defaults + "\n--header='Updated fzf defaults'\n")
                popup(first, 'S', 'Updated fzf defaults')
                search_and_accept(first, 'work')
                wait_for(lambda: state(first)[0] == 'work]local', 'S did not switch sessions')
                self.assertEqual(state(second)[0], 'dotfiles')

                popup(first, 'A', '✳ Revise scripts Fish')
                os.write(first[0], b'\r')
                wait_for(lambda: state(first) == ['dotfiles', agent], 'A selected the wrong target')

                popup(first, 'S', 'current session')
                os.write(first[0], b'S')
                wait_for(lambda: state(first)[0] == 'work]local', 'S shortcut lost the last session')

                popup(first, 'W', '(active')
                # Use tmux's unambiguous application-Escape sequence; the PTY
                # does not answer the capability queries used to time bare Esc.
                os.write(first[0], b'\x1bO[')
                time.sleep(.6)
                # Opening another selector verifies that Escape closed the popup.
                popup(first, 'S', 'current session')
                self.assertEqual(state(first), ['work]local', other])
                os.write(first[0], b'\x1b')
            finally:
                for master, process, done, reader, output, tty in clients:
                    process.terminate()
                    process.wait(timeout=5)
                    done.set()
                    reader.join(timeout=1)
                    os.close(master)
                command('kill-server')


if __name__ == '__main__':
    unittest.main()
