"""Exercise the Things skill script against a fixture database and a fake `open`."""

import datetime as dt
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import parse_qs, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'claude/.claude/skills/things/scripts/things'

SCHEMA = '''
CREATE TABLE TMTask (
  uuid TEXT PRIMARY KEY, type INTEGER, status INTEGER DEFAULT 0, trashed INTEGER DEFAULT 0,
  title TEXT, notes TEXT, start INTEGER DEFAULT 1, startDate INTEGER, startBucket INTEGER DEFAULT 0,
  deadline INTEGER, deadlineSuppressionDate INTEGER, reminderTime INTEGER,
  creationDate REAL, userModificationDate REAL DEFAULT 1, stopDate REAL,
  checklistItemsCount INTEGER DEFAULT 0, openChecklistItemsCount INTEGER DEFAULT 0,
  openUntrashedLeafActionsCount INTEGER DEFAULT 0,
  rt1_repeatingTemplate TEXT, rt1_recurrenceRule BLOB, rt1_nextInstanceStartDate INTEGER,
  rt1_instanceCreationPaused INTEGER DEFAULT 0,
  "index" INTEGER DEFAULT 0, todayIndex INTEGER DEFAULT 0, area TEXT, project TEXT, heading TEXT);
CREATE TABLE TMArea (uuid TEXT PRIMARY KEY, title TEXT, visible INTEGER, "index" INTEGER);
CREATE TABLE TMTag (uuid TEXT PRIMARY KEY, title TEXT, shortcut TEXT, parent TEXT, "index" INTEGER);
CREATE TABLE TMTaskTag (tasks TEXT, tags TEXT);
CREATE TABLE TMChecklistItem (uuid TEXT, title TEXT, status INTEGER, "index" INTEGER, task TEXT);
CREATE TABLE TMSettings (uriSchemeAuthenticationToken TEXT);
'''

# Stands in for macOS `open`: records the URL and applies it to the fixture database the
# way Things would, unless THINGS_FAKE_DROP says to ignore it.
FAKE_OPEN = r'''
import json, os, sqlite3, sys, time, urllib.parse
url = sys.argv[-1]
with open(os.environ['THINGS_CALLS'], 'a') as calls:
    calls.write(json.dumps(sys.argv[1:]) + '\n')
if os.environ.get('THINGS_FAKE_DROP'):
    sys.exit(0)
query = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)
con = sqlite3.connect(os.environ['THINGS_DB'])
for op in json.loads(query['data'][0]):
    attrs = op['attributes']
    if op.get('operation') == 'update':
        status = 3 if attrs.get('completed') else 2 if attrs.get('canceled') else None
        con.execute('UPDATE TMTask SET userModificationDate = userModificationDate + 1, '
                    'status = COALESCE(?, status) WHERE uuid = ?', (status, op['id']))
    else:
        con.execute('INSERT INTO TMTask (uuid, type, title, creationDate, start) VALUES (?, 0, ?, ?, 0)',
                    ('NEW' + str(time.time()), attrs['title'], time.time()))
con.commit()
'''


def pack(d):
    return d.year << 16 | d.month << 12 | d.day << 7


class ThingsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='things-')
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.db = self.directory / 'main.sqlite'
        self.calls = self.directory / 'calls.jsonl'
        mock_bin = self.directory / 'bin'
        mock_bin.mkdir()
        fake = mock_bin / 'open'
        fake.write_text('#!' + sys.executable + '\n' + FAKE_OPEN)
        fake.chmod(0o755)
        self.env = dict(os.environ, THINGS_DB=str(self.db), THINGS_CALLS=str(self.calls),
                        PATH=str(mock_bin) + os.pathsep + os.environ['PATH'],
                        THINGS_WRITE_TIMEOUT='2')
        self.env.pop('THINGS_AUTH_TOKEN', None)

        today = dt.date.today()
        day = lambda n: pack(today + dt.timedelta(days=n))
        con = sqlite3.connect(self.db)
        con.executescript(SCHEMA)
        con.execute("INSERT INTO TMSettings VALUES ('secret-token')")
        con.executemany('INSERT INTO TMArea VALUES (?, ?, 1, ?)',
                        [('FIN', 'Finance', 0), ('WORK', 'Trabalho', 1)])
        con.execute("INSERT INTO TMTag VALUES ('NEXT', 'Next', NULL, NULL, 0)")
        rows = [
            # uuid, type, title, start, startDate, startBucket, deadline, extra
            ('PROJ', 1, 'Atualização RDS', 1, None, 0, None, dict(area='WORK')),
            ('HEAD', 2, 'SOLAR', 1, None, 0, None, dict(project='PROJ')),
            ('PAST', 0, 'Pagar fatura', 1, day(-3), 0, day(-1), dict(area='FIN')),
            ('EVENING', 0, 'Ajustar stopwords', 1, day(0), 1, None, dict(heading='HEAD')),
            ('UNPROCESSED', 0, 'Agendada para hoje', 2, day(0), 0, None, dict(area='FIN')),
            ('DUE', 0, 'Prazo vencido sem data', 1, None, 0, day(-2), {}),
            ('SUPPRESSED', 0, 'Prazo suprimido', 1, None, 0, day(-2), dict(deadlineSuppressionDate=1)),
            ('FUTURE', 0, 'Daqui a três dias', 2, day(3), 0, None, {}),
            ('ANYTIME', 0, 'Qualquer hora', 1, None, 0, None, {}),
            ('DONE', 0, 'Concluída', 1, day(-1), 0, None, dict(status=3, stopDate=1)),
            ('TRASHED', 0, 'Na lixeira', 1, day(-1), 0, None, dict(trashed=1)),
            ('TEMPLATE', 0, 'Modelo repetido', 2, None, 0, pack(dt.date(4001, 1, 1)),
             dict(rt1_recurrenceRule=b'rule', rt1_nextInstanceStartDate=day(2), area='FIN')),
            ('INSTANCE', 0, 'Instância repetida', 1, day(-1), 0, None,
             dict(rt1_repeatingTemplate='TEMPLATE', area='FIN')),
        ]
        for uuid, type_, title, start, start_date, bucket, deadline, extra in rows:
            columns = dict(uuid=uuid, type=type_, title=title, start=start, startDate=start_date,
                           startBucket=bucket, deadline=deadline, **extra)
            con.execute(f'INSERT INTO TMTask ({", ".join(columns)}) VALUES ({", ".join("?" * len(columns))})',
                        list(columns.values()))
        con.execute("INSERT INTO TMTaskTag VALUES ('PAST', 'NEXT')")
        con.commit()
        con.close()

    def run_things(self, *args, **env):
        return subprocess.run([sys.executable, str(SCRIPT), *args], env=dict(self.env, **env),
                              text=True, capture_output=True, timeout=30)

    def json_of(self, *args):
        result = self.run_things(*args, '--json')
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def calls_made(self):
        if not self.calls.exists():
            return []
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_today_follows_things_rules(self):
        items = {item['uuid']: item for item in self.json_of('today')}
        self.assertEqual(set(items), {'PAST', 'EVENING', 'UNPROCESSED', 'DUE', 'INSTANCE'})
        self.assertTrue(items['EVENING']['evening'])
        self.assertEqual((items['EVENING']['area'], items['EVENING']['project'], items['EVENING']['heading']),
                         ('Trabalho', 'Atualização RDS', 'SOLAR'))
        self.assertEqual(items['PAST']['tags'], ['Next'])
        self.assertEqual(items['PAST']['deadline'], (dt.date.today() - dt.timedelta(days=1)).isoformat())
        self.assertTrue(items['INSTANCE']['repeating'])

    def test_upcoming_lists_scheduled_items_and_next_repeat(self):
        items = {item['uuid']: item for item in self.json_of('upcoming', '--days', '7')}
        self.assertEqual(set(items), {'FUTURE', 'TEMPLATE'})
        self.assertEqual(items['TEMPLATE']['start_date'], (dt.date.today() + dt.timedelta(days=2)).isoformat())
        self.assertIsNone(items['TEMPLATE']['deadline'])

    def test_logbook_and_trash(self):
        self.assertEqual([item['uuid'] for item in self.json_of('logbook')], [])  # stopDate is 1970
        self.assertEqual([item['uuid'] for item in self.json_of('logbook', '--days', '100000')], ['DONE'])
        self.assertNotIn('TRASHED', [item['uuid'] for item in self.json_of('search', 'lixeira', '--all')])

    def test_project_name_ignores_case_and_accents(self):
        project = self.json_of('project', 'atualizacao rds')
        self.assertEqual(project['uuid'], 'PROJ')
        self.assertEqual([item['uuid'] for item in project['items']], ['EVENING'])

    def test_unknown_name_fails(self):
        result = self.run_things('project', 'inexistente')
        self.assertEqual(result.returncode, 1)
        self.assertIn("no project matches 'inexistente'", result.stderr)

    def test_complete_sends_one_batch_and_verifies(self):
        result = self.run_things('complete', 'PAST', 'DUE')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('updated'), 2)
        (call,) = self.calls_made()
        self.assertEqual(call[0], '-g')
        self.assertTrue(call[1].startswith('things:///json?'))
        query = parse_qs(urlsplit(call[1]).query)
        self.assertEqual(query['auth-token'], ['secret-token'])
        self.assertEqual(query['reveal'], ['false'])
        self.assertEqual(json.loads(query['data'][0]), [
            {'type': 'to-do', 'operation': 'update', 'id': uuid, 'attributes': {'completed': True}}
            for uuid in ('PAST', 'DUE')])
        self.assertEqual({item['uuid'] for item in self.json_of('logbook', '--days', '100000')}, {'DONE'})

    def test_dropped_write_is_reported(self):
        result = self.run_things('complete', 'PAST', THINGS_FAKE_DROP='1')
        self.assertEqual(result.returncode, 1)
        self.assertIn('UNCHANGED', result.stdout)
        self.assertIn('show no change', result.stderr)

    def test_add_reports_the_new_item(self):
        result = self.run_things('add', 'Ligar para a Cemig', '--when', 'today', '--list', 'finance')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Ligar para a Cemig', result.stdout)
        (call,) = self.calls_made()
        data = json.loads(parse_qs(urlsplit(call[1]).query)['data'][0])
        self.assertEqual(data, [{'type': 'to-do', 'attributes': {
            'title': 'Ligar para a Cemig', 'when': 'today', 'list-id': 'FIN'}}])

    def test_unknown_tag_is_refused_before_writing(self):
        result = self.run_things('add', 'Algo', '--tags', 'Next, Inexistente')
        self.assertEqual(result.returncode, 1)
        self.assertIn("tag 'Inexistente' does not exist", result.stderr)
        self.assertEqual(self.calls_made(), [])


if __name__ == '__main__':
    unittest.main()
