"""Tests for processes.py: python3 -I ~/.agents/skills/processes/scripts/test_processes.py"""
import contextlib, importlib.util, io, os, plistlib, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('processes', os.path.join(HERE, 'processes.py'))
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

COMPANY = """# Acme - Company ledger

## Tracks

| ID | Track | Action (plain words) | Serves | Owner | Status | Due | Evidence |
|---|---|---|---|---|---|---|---|
| G1 | growth | Outreach to 10 editors | Paid orders | me | todo | | |
| G2 | growth | Old channel | Paid orders | me | cut (no fit) | | |
| S1 | support | Answer the inbox | Paid orders | me | building | | |
| P1 | product | Checkout fix | Paid orders | me | verified | | |
"""


def slurp(p):
    with open(p) as f:
        return f.read()


def run(fn, *a):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = fn(*a)
    return code, out.getvalue()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = os.path.join(self.tmp.name, 'acme')
        os.makedirs(os.path.join(self.d, 'sales'))
        os.makedirs(os.path.join(self.d, 'money'))
        os.makedirs(os.path.join(self.d, 'store'))
        with open(os.path.join(self.d, 'COMPANY.md'), 'w') as f:
            f.write(COMPANY)
        for f in ('money/ledger.md', 'sales/pitch.md'):
            open(os.path.join(self.d, f), 'w').close()
        self.agents = os.path.join(self.tmp.name, 'LaunchAgents')
        self.tasks = os.path.join(self.tmp.name, 'tasks')
        os.makedirs(self.agents)
        os.makedirs(self.tasks)
        P.AGENTS, P.TASKS = self.agents, self.tasks
        os.environ['PROCESSES_NOW'] = '2026-11-04T17:00'

    def tearDown(self):
        os.environ.pop('PROCESSES_NOW', None)
        self.tmp.cleanup()

    def write(self, text):
        with open(os.path.join(self.d, 'PROCESSES.md'), 'w') as f:
            f.write(text)


class Init(Base):
    def test_init_seeds_company_processes_schedule_tasks_and_lanes_and_never_overwrites(self):
        with open(os.path.join(self.agents, 'com.harness.acme.plist'), 'wb') as f:
            plistlib.dump({'Label': 'x', 'ProgramArguments': ['/bin/bash', 'run.sh', self.d], 'StartInterval': 3600}, f)
        os.makedirs(os.path.join(self.tasks, 'acme-outreach'))
        with open(os.path.join(self.tasks, 'acme-outreach', 'SKILL.md'), 'w') as f:
            f.write('---\ndescription: Daily outreach\n---\nRepo: %s\n' % self.d)
        os.makedirs(os.path.join(self.tasks, 'acme-daily'))
        with open(os.path.join(self.tasks, 'acme-daily', 'SKILL.md'), 'w') as f:
            f.write('---\ndescription: Daily ops for Acme\n---\nRun the heartbeat in %s\n' % self.d)
        code, out = run(P.cmd_init, self.d)
        self.assertEqual(code, 0)
        text = slurp(os.path.join(self.d, 'PROCESSES.md'))
        self.assertIn('| P1 | Build loop', text)
        self.assertIn('every 1h | loop', text)
        self.assertIn('| Daily ops | daily 09:00 | task:acme-daily |', text)  # the heartbeat task, not any task
        self.assertIn('| Daily outreach | (as scheduled) | task:acme-outreach |', text)
        self.assertIn('| B growth |', text)
        self.assertIn('sales/', text.split('| B growth |')[1].split('\n')[0])
        self.assertIn('money/', text.split('| C ops |')[1].split('\n')[0])
        self.assertNotIn('<PROCESS ROWS>', text)
        code, out = run(P.cmd_init, self.d)
        self.assertIn('exists', out)

    def test_unscheduled_folder_gets_session_runner_not_loop(self):
        run(P.cmd_init, self.d)
        text = slurp(os.path.join(self.d, 'PROCESSES.md'))
        self.assertIn('| P1 | Build loop: highest-leverage buildable row | every 3h | session |', text)


class Cadence(unittest.TestCase):
    t = P.dt.datetime(2026, 11, 4, 17, 0)  # a Wednesday

    def due(self, when, last):
        return P.cadence(when, P.parse_time(last), self.t)[1]

    def test_cadences(self):
        self.assertTrue(self.due('every run', '2026-11-04 16:59'))
        self.assertTrue(self.due('hourly', '2026-11-04 15:59'))
        self.assertFalse(self.due('hourly', '2026-11-04 16:30'))
        self.assertFalse(self.due('every 3h', '2026-11-04 15:00'))
        self.assertTrue(self.due('daily 16:30', '2026-11-03 16:31'))
        self.assertFalse(self.due('daily 16:30', '2026-11-04 16:35'))
        self.assertFalse(self.due('daily 18:00', '2026-11-03 18:05'))  # today's 18:00 has not come
        self.assertTrue(self.due('weekly sun', '2026-10-31 10:00'))  # last Sunday was Nov 1
        self.assertFalse(self.due('weekly sun', '2026-11-01 11:00'))
        self.assertTrue(self.due('monthly 1', '2026-10-15'))
        self.assertFalse(self.due('monthly 1', '2026-11-01 09:00'))
        self.assertTrue(self.due('daily', ''))  # never run
        self.assertEqual(P.cadence('on new order', None, self.t)[0], 'event')
        self.assertEqual(P.cadence('before deploy', None, self.t)[0], 'event')
        self.assertEqual(P.cadence('sometimes', None, self.t)[0], 'unknown')


GOOD = """# Acme - how we work

## Strategy

- Diagnosis: 0 sales, 52 visits a week
- Guiding policy: distribution before product
- Coherent actions: G1 outreach, S1 inbox
- Feasible because: free channels only
- Next objective: first order by 2026-12-15
- Review by: 2026-11-18

## Processes

| ID | Process | When | Runner | How (where the steps live) | Done when | Last run | Health |
|---|---|---|---|---|---|---|---|
| P1 | Build loop | every run | session | money/ledger.md | a row verified | 2026-11-04 16:00 | ok |
| P2 | Outreach | daily 16:30 | task:acme-outreach | sales/pitch.md | sent | 2026-11-03 16:40 | ok |
| P3 | Money close | monthly 1 | session | money/ledger.md | closed | 2026-11-01 09:00 | ok |

## Lanes

| Lane | Covers (tracks, processes) | Runner | Owns (files) | WIP | Waits on |
|---|---|---|---|---|---|
| A build | product rows, P1 | session | store/ | 1 | - |
| B growth | growth and sales rows, P2 | agent | sales/ | 1 | - |
| C ops | support, money rows, P3 | agent | money/ | 1 | - |
"""


class CheckDueMarkPlan(Base):
    def test_good_file_due_and_mark(self):
        os.makedirs(os.path.join(self.tasks, 'acme-outreach'))
        open(os.path.join(self.tasks, 'acme-outreach', 'SKILL.md'), 'w').close()
        self.write(GOOD)
        code, out = run(P.cmd_check, self.d)
        self.assertEqual(code, 0, out)
        self.assertIn('ok: 3 processes, 3 lanes', out)
        code, out = run(P.cmd_due, self.d)
        self.assertIn('P1 Build loop', out)
        self.assertIn('P2 Outreach', out)
        self.assertNotIn('P3', out)
        code, out = run(P.cmd_due, self.d, 'task:')
        self.assertNotIn('P1', out)
        self.assertIn('P2', out)
        code, out = run(P.cmd_mark, self.d, 'P2', 'ok')
        self.assertEqual(code, 0, out)
        text = slurp(os.path.join(self.d, 'PROCESSES.md'))
        self.assertIn('| P2 | Outreach | daily 16:30 | task:acme-outreach | sales/pitch.md | sent | 2026-11-04 17:00 | ok |', text)
        self.assertIn('| A build |', text)  # the rest of the file is kept
        code, out = run(P.cmd_due, self.d)
        self.assertNotIn('P2', out)

    def test_plan_groups_open_rows_by_lane(self):
        self.write(GOOD)
        code, out = run(P.cmd_plan, self.d)
        self.assertEqual(code, 0)
        growth = out.split('B growth')[1].split('C ops')[0]
        self.assertIn('row: G1', growth)
        self.assertNotIn('G2', growth)  # cut rows are not work
        self.assertIn('row: S1', out.split('C ops')[1])
        self.assertNotIn('P1 Checkout', out)  # verified rows are not work
        self.assertIn('parallel now: A build, B growth, C ops', out)

    def test_plan_lists_each_due_process_once_with_its_runner(self):
        extra = (
            '| P4 | Weekly growth review | weekly sun | session | money/ledger.md | recorded | 2026-10-25 09:00 | ok |\n'
            '| P5 | Recheck after approval | on approval | owner | money/ledger.md | recorded | - | new |\n'
        )
        self.write(GOOD.replace('\n## Lanes', extra + '\n## Lanes')
                   .replace('support, money rows, P3', 'support, money rows, P2, P3'))
        _, due = run(P.cmd_due, self.d)
        code, out = run(P.cmd_plan, self.d)
        self.assertEqual(code, 0)
        due_ids = [line.split()[0] for line in due.splitlines()]
        self.assertEqual(due_ids, ['P1', 'P2', 'P4'])
        plan_ids = [line.split()[1] for line in out.splitlines() if line.startswith('  due: ')]
        self.assertCountEqual(plan_ids, due_ids)
        growth, rest = out.split('B growth', 1)[1].split('C ops', 1)
        self.assertIn('  due: P2 Outreach | runner: task:acme-outreach', growth)
        self.assertNotIn('  due: P2', rest)
        unassigned = out.split('Due processes outside lanes:', 1)[1]
        self.assertIn('  due: P4 Weekly growth review | runner: session', unassigned)

    def test_plan_lists_dated_result_reviews_separately_from_work(self):
        self.write(GOOD.replace('every run | session', 'every run | loop'))
        fixture = os.path.join(self.d, 'COMPANY.md')
        with open(fixture, 'a') as f:
            for row_id, status, due in (
                ('G3', 'waiting', '2026-11-04 16:59'),
                ('G4', 'waiting (read results)', '2026-11-04'),
                ('G5', 'waiting', '2026-11-04 17:00'),
                ('G6', 'waiting', '2026-11-04 17:01'),
                ('G7', 'waiting', '2026-11-03 29:00'),
                ('G8', 'waiting', '2026-02-30'),
                ('G9', 'waiting', 'after G3'),
                ('G10', 'owner', '2026-11-04'),
                ('G11', 'verified', '2026-11-04'),
                ('G12', 'waiting', '2026-11-03 after review'),
                ('G13', 'waiting', '2026-11-05'),
                ('G14', 'waiting', ''),
            ):
                f.write(f'| {row_id} | growth | Read buyer results | Paid orders | me | {status} | {due} | - |\n')

        code, out = run(P.cmd_plan, self.d)
        self.assertEqual(code, 0, out)
        plan, reviews = out.split('Result reviews due', 1)
        self.assertIn('row: G1 ', plan)
        for row_id in ('G3', 'G4', 'G5'):
            self.assertNotIn(f'row: {row_id} ', plan)
            self.assertIn(f'  {row_id} ', reviews)
        self.assertLess(reviews.index('  G4 '), reviews.index('  G3 '))
        self.assertLess(reviews.index('  G3 '), reviews.index('  G5 '))
        for row_id in range(6, 15):
            self.assertNotIn(f'  G{row_id} ', reviews)
        self.assertIn('P1 Build loop', run(P.cmd_due, self.d, 'loop')[1])
        self.assertNotIn('G3', run(P.cmd_due, self.d, 'loop')[1])

    def test_reviews_keep_rows_with_the_same_id_in_separate_ledgers(self):
        self.write(GOOD)
        with open(os.path.join(self.d, 'READINESS.md'), 'w') as f:
            f.write('## Flows\n\n| ID | Flow (user words) | Surfaces | Status | Due | Evidence |\n'
                    '|---|---|---|---|---|---|\n'
                    '| P1 | Confirm the checkout result | phone | waiting | 2026-11-04 | - |\n')

        code, out = run(P.cmd_plan, self.d)
        self.assertEqual(code, 0, out)
        self.assertIn('P1 2026-11-04 | READINESS.md | Confirm the checkout result', out)
        self.assertNotIn('row: P1', out)

    def test_check_flags_placeholders_bad_runner_missing_task_late_overlap_and_unknown_rows(self):
        bad = GOOD.replace('- Diagnosis: 0 sales, 52 visits a week', '- Diagnosis: <the one challenge>')
        bad = bad.replace('G1 outreach, S1 inbox', 'G1 outreach, G2 old, Z9 ghost')
        bad = bad.replace('| session | money/ledger.md | closed |', '| robot | money/ledger.md | closed |')
        bad = bad.replace('2026-11-03 16:40', '2026-10-20 16:40')
        bad = bad.replace('| agent | sales/ |', '| agent | sales/, store/pins |')
        self.write(bad)
        code, out = run(P.cmd_check, self.d)
        self.assertEqual(code, 1, out)
        self.assertIn('WARN strategy not written yet: Diagnosis', out)
        self.assertIn('G2, which is cut', out)
        self.assertIn('Z9, which is not a ledger row', out)
        self.assertIn('FAIL P3 runner "robot"', out)
        self.assertIn('desktop task acme-outreach, which does not exist', out)
        self.assertIn('P2 is late', out)
        self.assertIn('lanes A build and B growth both own store', out)

    def test_loop_without_schedule_and_missing_strategy_line(self):
        self.write(GOOD.replace('| P1 | Build loop | every run | session |', '| P1 | Build loop | every run | loop |').replace('- Review by: 2026-11-18\n', ''))
        code, out = run(P.cmd_check, self.d)
        self.assertEqual(code, 1)
        self.assertIn('FAIL strategy has no "Review by" line', out)
        self.assertIn('P1 runs on loop, but no schedule runs this folder', out)

    def test_no_file(self):
        code, out = run(P.cmd_check, self.d)
        self.assertEqual(code, 1)
        self.assertIn('run init', out)


if __name__ == '__main__':
    unittest.main(verbosity=1)
