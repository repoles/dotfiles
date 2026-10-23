"""Exercise rexls with isolated Rex metadata and terminal timestamps."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''
import json
import os
from pathlib import Path
import sys

config = json.loads(Path(os.environ['REXLS_FIXTURE']).read_text())
command = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ['REXLS_CALLS']).open('a') as calls:
    calls.write(json.dumps([command, *args]) + '\n')

def reply(key, value):
    if key in config.get('failures', {}):
        print('mock failure: ' + key, file=sys.stderr)
        sys.exit(config['failures'][key])
    print(config.get('raw', {}).get(key, json.dumps(value)))

if command == 'rex':
    if args[0] == 'whoami':
        reply('whoami', config['whoami'])
    elif args[:2] == ['session', 'ls']:
        reply('sessions', {'sessions': config['sessions']})
    elif args[:2] == ['window', 'ls']:
        session = args[args.index('-s') + 1]
        reply('windows:' + session, config['windows'].get(session))
    elif args[:2] == ['block', 'call']:
        block = args[args.index('-b') + 1]
        method = args[-1]
        reply(method + ':' + block, config['blocks'][block].get(method))
    else:
        sys.exit('unexpected Rex command: ' + repr(args))
elif command == 'ps':
    print(config['ps'])
elif command == 'stat':
    value = config['mtimes'].get(args[-1])
    if value is None:
        sys.exit(1)
    print(value)
elif command == 'date':
    print(config['now'])
'''


class RexlsTest(unittest.TestCase):
    def setUp(self):
        self.fish = shutil.which('fish')
        if not self.fish or not shutil.which('jq'):
            self.skipTest('fish and jq are required')
        directory = tempfile.TemporaryDirectory(prefix='rexls-')
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        mock_bin = self.directory / 'bin'
        mock_bin.mkdir()
        mock = mock_bin / 'rex'
        mock.write_text('#!' + sys.executable + '\n' + MOCK)
        mock.chmod(0o755)
        for command in ['ps', 'stat', 'date']:
            (mock_bin / command).symlink_to(mock)
        self.fixture = self.directory / 'fixture.json'
        self.calls = self.directory / 'calls.jsonl'
        self.env = dict(os.environ, PATH=str(mock_bin) + os.pathsep + os.environ['PATH'], TZ='UTC',
                        REXLS_FIXTURE=str(self.fixture), REXLS_CALLS=str(self.calls))
        blocks = [dict(block_id=f'block:{i:06}', label=f'block {i}', host_id='local')
                  for i in [1, 2]]
        self.config = {
            'whoami': dict(host_id='local', window_id='window:000001', block_id='block:000001'),
            'sessions': [dict(session_id='session:000001', label='demo')],
            'windows': {'session:000001': {
                'active_window_id': 'window:000001',
                'windows': [dict(window_id='window:000001', label='Terminal',
                                 focused_block_id='block:000001', layers=[dict(blocks=blocks)])],
            }},
            'blocks': {f'block:{i:06}': {
                'title': dict(title=f'title {i}'),
                'process': dict(foreground=dict(pid=100 + i, argv0='-fish')),
                'program_status': dict(records=[]),
            } for i in [1, 2]},
            'ps': '  101   ttys001\n  102   ttys002',
            'mtimes': {'/dev/ttys001': 1699999940, '/dev/ttys002': 1699996400},
            'now': 1700000000,
        }

    def run_rexls(self, *args):
        self.fixture.write_text(json.dumps(self.config))
        return subprocess.run([
            self.fish, '--no-config', '-c', 'source $argv[1]; or exit $status; rexls $argv[2..-1]',
            str(ROOT / 'fish/.config/fish/functions/rexls.fish'), *args,
        ], env=self.env, text=True, capture_output=True, timeout=15)

    def json_rows(self, *args):
        result = self.run_rexls('--json', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return json.loads(result.stdout)

    def test_json_preserves_fields_and_current_markers(self):
        first, second = self.json_rows()
        self.assertIsNone(first['status'])
        self.assertIsNone(first['status_updated_at'])
        self.assertTrue(first['window_active'])
        self.assertTrue(first['window_current'])
        self.assertTrue(first['block_active'])
        self.assertTrue(first['block_current'])
        self.assertFalse(second['block_current'])
        self.assertEqual(first['process'], 'fish')
        self.assertEqual(first['last_tty_write_at'], '2023-11-14T22:12:20+00:00')
        self.assertNotIn('pid', first)
        self.assertNotIn('host_id', first)

    def test_stat_failure_does_not_move_another_blocks_timestamp(self):
        del self.config['mtimes']['/dev/ttys001']
        first, second = self.json_rows()
        self.assertIsNone(first['last_tty_write_at'])
        self.assertEqual(second['last_tty_write_at'], '2023-11-14T21:13:20+00:00')

    def test_collection_failures_return_nonzero_without_partial_output(self):
        self.config['sessions'].append(dict(session_id='session:000002', label='other'))
        for key in ['whoami', 'sessions', 'windows:session:000002']:
            with self.subTest(key=key):
                self.config['failures'] = {key: 7}
                result = self.run_rexls('--json')
                self.assertEqual(result.returncode, 7, result.stderr)
                self.assertEqual(result.stdout, '')
                self.assertIn('mock failure: ' + key, result.stderr)

    def test_invalid_or_empty_json_is_an_error(self):
        for key in ['whoami', 'sessions', 'windows:session:000001']:
            for raw in ['invalid json', '', '{}']:
                with self.subTest(key=key, raw=raw):
                    self.config['raw'] = {key: raw}
                    result = self.run_rexls('--json')
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, '')

    def test_empty_results_are_successful(self):
        self.assertEqual(self.json_rows('-s', 'missing'), [])
        self.assertEqual(self.json_rows('-w', 'missing'), [])
        self.config['sessions'] = []
        self.assertEqual(self.json_rows(), [])
        result = self.run_rexls()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_filters_accept_labels_full_ids_and_suffixes(self):
        for session in ['demo', 'session:000001', '000001']:
            for window in ['Terminal', 'window:000001', '000001']:
                with self.subTest(session=session, window=window):
                    self.assertEqual(len(self.json_rows('-s', session, '-w', window)), 2)

    def test_labels_round_trip_without_tsv_escaping(self):
        label = 'project\\name\twith\nspaces'
        self.config['sessions'][0]['label'] = label
        window = self.config['windows']['session:000001']['windows'][0]
        window['label'] = label
        window['layers'][0]['blocks'][0]['label'] = label
        first = self.json_rows('-s', label, '-w', label)[0]
        for key in ['session_label', 'window_label', 'block_label']:
            self.assertEqual(first[key], label)

    def test_remote_pids_are_not_queried_locally(self):
        window = self.config['windows']['session:000001']['windows'][0]
        window['layers'][0]['blocks'][0]['host_id'] = 'remote'
        report_time = '2023-11-14T19:12:20.125-03:00'
        self.config['blocks']['block:000001']['program_status']['records'] = [
            dict(state='working', updated_at=report_time)]
        first, second = self.json_rows()
        self.assertIsNone(first['last_tty_write_at'])
        self.assertEqual(first['status_updated_at'], '2023-11-14T22:12:20+00:00')
        self.assertIsNotNone(second['last_tty_write_at'])
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([call for call in calls if call[0] == 'ps'],
                         [['ps', '-o', 'pid=,tty=', '-p', '102']])

    def test_unavailable_block_methods_have_null_values(self):
        self.config['failures'] = {method + ':block:000001': 3
                                   for method in ['title', 'process', 'program_status']}
        first, second = self.json_rows()
        for key in ['title', 'process', 'status', 'status_updated_at', 'last_tty_write_at']:
            self.assertIsNone(first[key])
        self.assertEqual(second['process'], 'fish')

    def test_empty_or_unexpected_block_results_have_null_values(self):
        for raw in ['', 'invalid json', '"text"', '{"title": 5}']:
            with self.subTest(raw=raw):
                self.config['raw'] = {method + ':block:000001': raw
                                      for method in ['title', 'process', 'program_status']}
                first, second = self.json_rows()
                for key in ['title', 'process', 'status', 'status_updated_at', 'last_tty_write_at']:
                    self.assertIsNone(first[key])
                self.assertEqual(second['title'], 'title 2')

    def test_table_shows_a_missing_session_label_as_a_dash(self):
        if not shutil.which('column'):
            self.skipTest('column is required')
        del self.config['sessions'][0]['label']
        result = self.run_rexls()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.splitlines()[1].startswith('-'))

    def test_status_priority_and_child_process_fallback(self):
        block = self.config['blocks']['block:000001']
        block['process'] = dict(child=dict(pid=101, script='/opt/bin/task'))
        block['program_status']['records'] = [dict(state=state) for state in
                                              ['done', 'working', 'error', 'blocked']]
        block['program_status']['records'][-1]['kind'] = 'approval'
        first = self.json_rows()[0]
        self.assertEqual(first['process'], 'task')
        self.assertEqual(first['status'], 'blocked:approval')

    def test_latest_report_uses_the_actual_time_instead_of_state_or_string_order(self):
        report_time = '2023-11-14T19:11:20.125-03:00'
        self.config['blocks']['block:000001']['program_status']['records'] = [
            dict(state='blocked', kind='permission', updated_at='2023-11-14T23:00:00+02:00'),
            dict(state='working', updated_at=report_time),
            dict(state='done', updated_at='2023-11-14T22:11:20.100Z'),
        ]
        first = self.json_rows()[0]
        self.assertEqual(first['status'], 'blocked:permission')
        self.assertEqual(first['status_updated_at'], '2023-11-14T22:11:20+00:00')
        self.assertEqual(first['last_tty_write_at'], '2023-11-14T22:12:20+00:00')

    def test_json_dates_share_format_and_whole_second_precision(self):
        for report_time in ['2023-11-14T22:12:20Z',
                            '2023-11-14T22:12:20.999999Z',
                            '2023-11-14T19:12:20.125-03:00',
                            '2023-11-15T03:42:20.125+05:30']:
            with self.subTest(report_time=report_time):
                self.config['blocks']['block:000001']['program_status']['records'] = [
                    dict(state='working', updated_at=report_time)]
                first = self.json_rows()[0]
                self.assertEqual(first['status_updated_at'], '2023-11-14T22:12:20+00:00')
                self.assertEqual(first['status_updated_at'], first['last_tty_write_at'])

    def test_both_dates_follow_the_local_timezone(self):
        self.config['blocks']['block:000001']['program_status']['records'] = [
            dict(state='working', updated_at='2023-11-14T22:12:20.125Z')]
        for zone, expected in [
            ('America/Sao_Paulo', '2023-11-14T19:12:20-03:00'),
            ('Asia/Kolkata', '2023-11-15T03:42:20+05:30'),
            ('America/New_York', '2023-11-14T17:12:20-05:00'),
        ]:
            with self.subTest(zone=zone):
                self.env['TZ'] = zone
                first = self.json_rows()[0]
                self.assertEqual(first['status_updated_at'], expected)
                self.assertEqual(first['last_tty_write_at'], expected)
                if shutil.which('column'):
                    result = self.run_rexls()
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.splitlines()[1].split()[-1], '1m')

    def test_bad_report_timestamps_do_not_hide_a_valid_report(self):
        records = [dict(state='working', updated_at=value) for value in
                   ['not a timestamp', '2023-99-14T22:12:20Z', None, 42]]
        records.append(dict(state='working'))
        self.config['blocks']['block:000001']['program_status']['records'] = records
        self.assertIsNone(self.json_rows()[0]['status_updated_at'])
        report_time = '2023-11-14T22:12:20Z'
        records.append(dict(state='idle', updated_at=report_time))
        self.assertEqual(self.json_rows()[0]['status_updated_at'], '2023-11-14T22:12:20+00:00')

    def test_report_times_are_available_even_when_tty_stat_fails(self):
        del self.config['mtimes']['/dev/ttys001']
        report_time = '2023-11-14T22:12:20Z'
        self.config['blocks']['block:000001']['program_status']['records'] = [
            dict(state='working', updated_at=report_time)]
        first = self.json_rows()[0]
        self.assertEqual(first['status_updated_at'], '2023-11-14T22:12:20+00:00')
        self.assertIsNone(first['last_tty_write_at'])

    def test_table_activity_prefers_reports_and_falls_back_to_tty_writes(self):
        if not shutil.which('column'):
            self.skipTest('column is required')
        self.config['blocks']['block:000001']['program_status']['records'] = [
            dict(state='working', updated_at='2023-11-14T20:13:20Z')]
        for args in [(), ('--long',)]:
            with self.subTest(args=args):
                result = self.run_rexls(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.splitlines()[0].split(),
                                 ['SESSION', 'WINDOW', 'BLOCK', 'PROCESS', 'TITLE', 'STATUS', 'ACTIVITY'])
                self.assertIn('*@', result.stdout)
                self.assertEqual(result.stdout.splitlines()[1].split()[-1], '2h')
                self.assertEqual(result.stdout.splitlines()[2].split()[-1], '~1h')
                self.assertEqual('window:000001' in result.stdout, bool(args))

    def test_table_activity_is_unknown_when_both_times_are_missing(self):
        if not shutil.which('column'):
            self.skipTest('column is required')
        del self.config['mtimes']['/dev/ttys001']
        result = self.run_rexls()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[1].split()[-1], '-')
        self.assertEqual(result.stdout.splitlines()[2].split()[-1], '~1h')

    def test_table_parses_fractional_report_times_and_timezone_offsets(self):
        if not shutil.which('column'):
            self.skipTest('column is required')
        for report_time in ['2023-11-14T22:12:20.000Z',
                            '2023-11-14T19:12:20.000-03:00',
                            '2023-11-15T03:42:20.000+05:30']:
            with self.subTest(report_time=report_time):
                self.config['blocks']['block:000001']['program_status']['records'] = [
                    dict(state='working', updated_at=report_time)]
                result = self.run_rexls()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.splitlines()[1].split()[-1], '1m')

    def test_help_distinguishes_reports_from_terminal_writes(self):
        result = self.run_rexls('--help')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ACTIVITY uses status_updated_at, falling back to last_tty_write_at when null', result.stdout)
        self.assertIn('A status report takes priority even when the TTY write is more recent', result.stdout)
        self.assertIn('JSON status_updated_at', result.stdout)
        self.assertIn('JSON last_tty_write_at', result.stdout)
        self.assertIn('An old report does not mean inactivity', result.stdout)
        self.assertIn('JSON timestamps use local time with whole seconds', result.stdout)
        self.assertIn('~ marks times estimated from terminal writes', result.stdout)


if __name__ == '__main__':
    unittest.main()
