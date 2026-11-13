#!/usr/bin/env python3
"""PROCESSES.md: a project's strategy, recurring processes and parallel lanes (processes skill).

Usage: python3 -I processes.py init  <dir>              write PROCESSES.md from the ledger and the schedules (never overwrites)
       python3 -I processes.py due   <dir> [--runner R] [--all]   processes due now (R: loop, session, agent, owner, task:<id>, ...)
       python3 -I processes.py mark  <dir> <ID> [ok|late|failing]  record a run: Last run = now, Health
       python3 -I processes.py plan  <dir>              dispatch plan, including dated result reviews
       python3 -I processes.py check <dir>              strategy, processes, runners, lanes; exit 1 on a structural problem
       python3 -I processes.py missing                  registered projects with a ledger and no PROCESSES.md
Stdlib only. Times are local, written as YYYY-MM-DD HH:MM.
"""
import calendar, datetime as dt, glob, json, os, plistlib, re, subprocess, sys

HOME = os.path.expanduser('~')
SKILLS = os.environ.get('HARNESS_SKILLS_DIR', os.path.join(HOME, '.agents', 'skills'))
TASKS = os.environ.get('SCHEDULED_TASKS_DIR', os.path.join(HOME, '.claude', 'scheduled-tasks'))
AGENTS = os.environ.get('LAUNCH_AGENTS_DIR', os.path.join(HOME, 'Library', 'LaunchAgents'))
REGISTRY = os.environ.get('WORKSPACES_REGISTRY', os.path.join(HOME, '.agents', 'workspaces', 'registry.json'))
LEDGERS = ('COMPANY.md', 'PORTFOLIO.md', 'READINESS.md')
RUNNERS = ('loop', 'session', 'agent', 'owner', 'worker')
RUNNER_PREFIXES = ('task:', 'automation:', 'human:')
STRATEGY_KEYS = ('Diagnosis', 'Guiding policy', 'Coherent actions', 'Feasible because', 'Next objective', 'Review by')
DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
OPEN = ('todo', 'building', 'defect', 'open', 'new')


def now():
    return dt.datetime.fromisoformat(os.environ['PROCESSES_NOW']) if os.environ.get('PROCESSES_NOW') else dt.datetime.now().replace(second=0, microsecond=0)


def read(p):
    try:
        with open(p, encoding='utf-8') as f:
            return f.read()
    except OSError:
        return ''


def cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def section(text, title):
    """Lines of the '## <title>' section (title matched by prefix, case-insensitive)."""
    out, on = [], False
    for line in text.split('\n'):
        if line.startswith('## '):
            on = line[3:].strip().lower().startswith(title.lower())
            continue
        if on:
            out.append(line)
    return out


def table(lines):
    """(header, rows, line indexes) of the first markdown table in lines."""
    head, rows, idx = None, [], []
    for i, line in enumerate(lines):
        if not line.startswith('|'):
            if head:
                break
            continue
        c = cells(line)
        if head is None:
            head = [h.lower() for h in c]
        elif not set(''.join(c)) <= set('-: '):
            rows.append(c)
            idx.append(i)
    return head or [], rows, idx


def col(head, name):
    return next((i for i, h in enumerate(head) if h.startswith(name)), None)


def parse_time(s):
    s = (s or '').strip()
    for fmt, n in (('%Y-%m-%d %H:%M', 16), ('%Y-%m-%d', 10)):
        try:
            return dt.datetime.strptime(s[:n], fmt)
        except ValueError:
            pass
    return None


def review_time(value):
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?', value):
        try:
            return dt.datetime.fromisoformat(value)
        except ValueError:
            pass
    return None


def cadence(when, last, t):
    """(kind, due, period) for a When cell. kind: run | time | event | unknown."""
    w = (when or '').strip().lower()
    if not w:
        return 'unknown', False, None
    if w.startswith(('on ', 'before ', 'after ', 'when ')):
        return 'event', False, None
    if w in ('every run', 'each run', 'always'):
        return 'run', True, None
    m = re.match(r'(hourly|every (\d+)\s*(m|min|minutes?|h|hours?|d|days?)\b)', w)
    if m:
        n = 1 if m.group(1) == 'hourly' else int(m.group(2))
        unit = 'h' if m.group(1) == 'hourly' else m.group(3)[0]
        period = dt.timedelta(minutes=n) if unit == 'm' else dt.timedelta(hours=n) if unit == 'h' else dt.timedelta(days=n)
        return 'time', last is None or t - last >= period, period
    hm = re.search(r'(\d{1,2}):(\d{2})', w)
    hh, mm = (int(hm.group(1)), int(hm.group(2))) if hm else (0, 0)
    if w.startswith(('daily', 'every day', 'weekdays')):
        occ = t.replace(hour=hh, minute=mm)
        if occ > t:
            occ -= dt.timedelta(days=1)
        while w.startswith('weekdays') and occ.weekday() > 4:
            occ -= dt.timedelta(days=1)
        return 'time', last is None or last < occ, dt.timedelta(days=1)
    if w.startswith('weekly'):
        day = next((i for i, d in enumerate(DAYS) if re.search(r'\b' + d, w)), None)
        if day is None:
            return 'time', last is None or t - last >= dt.timedelta(days=7), dt.timedelta(days=7)
        occ = t.replace(hour=hh, minute=mm) - dt.timedelta(days=(t.weekday() - day) % 7)
        if occ > t:
            occ -= dt.timedelta(days=7)
        return 'time', last is None or last < occ, dt.timedelta(days=7)
    if w.startswith('monthly'):
        m = re.search(r'monthly\s+(\d{1,2})\b', w)
        day = int(m.group(1)) if m else 1
        y, mo = t.year, t.month
        occ = dt.datetime(y, mo, min(day, calendar.monthrange(y, mo)[1]), hh, mm)
        if occ > t:
            y, mo = (y - 1, 12) if mo == 1 else (y, mo - 1)
            occ = dt.datetime(y, mo, min(day, calendar.monthrange(y, mo)[1]), hh, mm)
        return 'time', last is None or last < occ, dt.timedelta(days=31)
    return 'unknown', False, None


def load(d):
    p = os.path.join(d, 'PROCESSES.md')
    text = read(p)
    if not text:
        return None
    head, rows, _ = table(section(text, 'Processes'))
    procs = []
    for r in rows:
        g = lambda name: r[col(head, name)] if col(head, name) is not None and col(head, name) < len(r) else ''
        procs.append({'id': g('id'), 'name': g('process'), 'when': g('when'), 'runner': g('runner'), 'how': g('how'),
                      'done': g('done'), 'last': g('last'), 'health': g('health')})
    lhead, lrows, _ = table(section(text, 'Lanes'))
    lanes = []
    for r in lrows:
        g = lambda name: r[col(lhead, name)] if col(lhead, name) is not None and col(lhead, name) < len(r) else ''
        lanes.append({'lane': g('lane'), 'covers': g('covers'), 'runner': g('runner'), 'owns': g('owns'), 'wip': g('wip'), 'waits': g('waits')})
    strategy = {}
    for line in section(text, 'Strategy'):
        m = re.match(r'\s*[-*]\s*([A-Za-z ]+?):\s*(.*)', line)
        if m:
            strategy[m.group(1).strip()] = m.group(2).strip()
    return {'path': p, 'text': text, 'procs': procs, 'lanes': lanes, 'strategy': strategy, 'head': head}


def iter_ledger_rows(d):
    """Yield each row with its source ledger, including IDs reused across files."""
    for name in LEDGERS:
        heading, head = '', None
        for line in read(os.path.join(d, name)).split('\n'):
            if line.startswith('## '):
                heading, head = line[3:].strip().lower(), None
                continue
            if not line.startswith('|'):
                head = None
                continue
            c = cells(line)
            if head is None:
                head = [h.lower() for h in c]
                continue
            if set(''.join(c)) <= set('-: ') or not re.match(r'^[A-Z][A-Za-z]*\d+[a-z]?$', c[0]):
                continue
            si, ti, ai = col(head, 'status'), col(head, 'track'), col(head, 'action')
            if ai is None:
                ai = col(head, 'flow')
            st = c[si].split(' ')[0].strip('(').lower() if si is not None and si < len(c) else ''
            di = col(head, 'due')
            due = c[di] if di is not None and di < len(c) else ''
            track = c[ti] if ti is not None and ti < len(c) else heading
            action = c[ai] if ai is not None and ai < len(c) else (c[2] if len(c) > 2 else '')
            yield name, c[0], st, track, action, due


def ledger_rows(entries):
    """Keep existing first-ledger precedence for buildable rows and strategy references."""
    out = {}
    for _, row_id, status, track, action, _ in entries:
        out.setdefault(row_id, (status, track, action))
    return out


def runner_ok(r):
    parts = [p.strip().strip('`') for p in re.split(r'\s+or\s+|/|,', r or '') if p.strip()]
    return bool(parts) and all(p in RUNNERS or p.startswith(RUNNER_PREFIXES) for p in parts), parts


def loop_scheduled(d):
    d = os.path.abspath(d)
    for p in glob.glob(os.path.join(AGENTS, '*.plist')):
        try:
            with open(p, 'rb') as f:
                pl = plistlib.load(f)
        except Exception:
            continue
        if any(os.path.abspath(os.path.expanduser(a)) == d for a in pl.get('ProgramArguments', []) if isinstance(a, str)):
            return pl.get('StartInterval')
    try:
        cron = subprocess.run(['crontab', '-l'], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        cron = ''
    return 'cron' if d in cron else None


def desktop_tasks(d):
    d = os.path.abspath(d)
    out = []
    for p in sorted(glob.glob(os.path.join(TASKS, '*', 'SKILL.md'))):
        t = read(p)
        if d in t or d.replace(HOME, '~', 1) in t:
            m = re.search(r'^description:\s*(.*)$', t, re.M)
            out.append((os.path.basename(os.path.dirname(p)), (m.group(1) if m else '').strip().strip('"')[:90],
                        bool(re.search(r'heartbeat|daily ops', t, re.I))))
    return out


def how_exists(how, d):
    paths = re.findall(r'[~\w./-]+\.(?:md|sh|py|js|json|toml)\b', how or '')
    if not paths:
        return True
    for p in paths:
        cands = [os.path.expanduser(p), os.path.join(d, p), os.path.join(SKILLS, p)]
        if any(os.path.exists(c) for c in cands):
            return True
    return False


def cmd_init(d):
    p = os.path.join(d, 'PROCESSES.md')
    if os.path.exists(p):
        print('exists: ' + p + ' (never overwritten); run check')
        return 0
    ledger = next((n for n in LEDGERS if os.path.exists(os.path.join(d, n))), None)
    name = os.path.basename(os.path.abspath(d))
    m = re.search(r'^#\s+(.+?)(?:\s+-\s+.*)?$', read(os.path.join(d, ledger)) if ledger else '', re.M)
    if m:
        name = m.group(1).strip()
    every = loop_scheduled(d)
    loop_when = 'every %dh' % max(1, every // 3600) if isinstance(every, int) else 'every 3h'
    loop_runner = 'loop' if every else 'session'
    tasks = desktop_tasks(d)
    ops = next((tid for tid, _, beat in tasks if beat), None)  # only a heartbeat task runs daily ops
    S = '~/.agents/skills/'
    if ledger == 'PORTFOLIO.md':
        seeds = [('Tick: one worker per active company', loop_when, loop_runner, S + 'portfolio/scripts/tick.sh', 'logs read, table updated, gates applied'),
                 ('Gates and cut rule', 'every run', loop_runner, S + 'portfolio/SKILL.md section 4', 'every company row has stage, KPI and next action'),
                 ('Intake: queue to new companies', 'weekly mon', 'session', S + 'portfolio/SKILL.md section 3', 'the batch is full'),
                 ('Weekly portfolio review', 'weekly sun', 'session', S + 'portfolio/SKILL.md section 5', 'one decision per company, three for the portfolio, one process improved')]
    elif ledger == 'COMPANY.md':
        seeds = [('Build loop: highest-leverage buildable row', loop_when, loop_runner, S + 'run-company/SKILL.md section 3', 'a row verified with evidence, or "no change"'),
                 ('Numbers and inboxes', 'every run', loop_runner, S + 'run-company/heartbeat.md steps 1-2', 'KPIs refreshed; every reply acted on'),
                 ('Daily ops', 'daily 09:00', 'task:' + ops if ops else 'session', S + 'run-company/heartbeat.md', 'the heartbeat report or "no change"'),
                 ('Weekly review', 'weekly sun', 'session', S + 'run-company/SKILL.md section 6', 'three Decision lines; one process improved (Changes)'),
                 ('Monthly money close', 'monthly 1', loop_runner, 'money/ledger.md', 'the 10-line close'),
                 ('Strategy review', 'monthly 1', 'session', S + 'processes/SKILL.md section 5', 'Strategy re-read against the numbers; Review by moved')]
    else:
        seeds = [('Build loop: highest-value row', 'every run', loop_runner, S + 'ship/SKILL.md', 'a row verified with evidence'),
                 ('QA regression sweep', 'weekly fri', 'agent', S + 'qa-flows/SKILL.md', 'every verified flow re-checked on the real surface'),
                 ('Release gates', 'before deploy', 'session', S + 'release-gates/SKILL.md', 'every gate verified, owner or waiting'),
                 ('Deploy and smoke test', 'on merge to main', 'session', S + 'ship/SKILL.md section Deploy', 'production answers; smoke flow passed'),
                 ('Weekly review', 'weekly sun', 'session', S + 'learn/SKILL.md', 'rows, learnings and one process improved')]
    known = {s[2] for s in seeds if s[2].startswith('task:')}
    for tid, desc, _ in tasks:
        if 'task:' + tid not in known:
            seeds.append((desc or tid, '(as scheduled)', 'task:' + tid, '~/.claude/scheduled-tasks/%s/SKILL.md' % tid, 'its report'))
    rows = ['| P%d | %s | %s | %s | %s | %s | - | new |' % (i + 1, *s) for i, s in enumerate(seeds)]
    dirs = sorted(x for x in os.listdir(d) if os.path.isdir(os.path.join(d, x)) and not x.startswith('.') and x not in ('node_modules', 'qa'))
    growth = [x for x in dirs if re.search(r'sales|market|growth|outreach|social|seo|content|pins|ads', x, re.I)]
    ops = [x for x in dirs if re.search(r'money|finance|support|hires|legal|admin|ops', x, re.I)]
    build = [x for x in dirs if x not in growth and x not in ops]
    owns = lambda xs: ', '.join(x + '/' for x in xs) or '(name the folders)'
    lanes = ['| A build | product rows, P1 | session or agent | %s | 1 | - |' % owns(build),
             '| B growth | growth and sales rows | agent | %s | 1 | - |' % owns(growth),
             '| C ops | support, money, admin rows | agent | %s | 1 | - |' % owns(ops)]
    text = read(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'template.md'))
    text = text.replace('<Project>', name).replace('<LEDGER>', ledger or 'the ledger')
    text = text.replace('<PROCESS ROWS>', '\n'.join(rows)).replace('<LANE ROWS>', '\n'.join(lanes))
    with open(p, 'w', encoding='utf-8') as f:
        f.write(text)
    print('wrote %s: %d processes, %d lanes (loop %s, %d desktop task(s)). Next: write the Strategy from real numbers, '
          'then fit processes and lanes to this project (processes skill, section 2).' % (p, len(rows), len(lanes), 'scheduled' if every else 'not scheduled', len(tasks)))
    return 0


def due_list(model, runner=None, include_events=False):
    t, out = now(), []
    for pr in model['procs']:
        ok, parts = runner_ok(pr['runner'])
        if runner and not any(x == runner or (runner.endswith(':') and x.startswith(runner)) for x in parts):
            continue
        kind, due, _ = cadence(pr['when'], parse_time(pr['last']), t)
        if due or (include_events and kind == 'event'):
            out.append((pr, kind))
    return out


def cmd_due(d, runner=None, include_events=False):
    model = load(d)
    if not model:
        print('no PROCESSES.md in %s: run init' % d)
        return 1
    rows = due_list(model, runner, include_events)
    if not rows:
        print('nothing due' + (' for ' + runner if runner else ''))
        return 0
    for pr, kind in rows:
        print('%s %s | %s | %s | how: %s | last %s' % (pr['id'], pr['name'], 'on event: ' + pr['when'] if kind == 'event' else pr['when'],
                                                      pr['runner'], pr['how'], pr['last'] or '-'))
    return 0


def cmd_mark(d, pid, health='ok'):
    p = os.path.join(d, 'PROCESSES.md')
    lines = read(p).split('\n')
    sec = [i for i, l in enumerate(lines) if l.startswith('## ')]
    start = next((i for i in sec if lines[i][3:].strip().lower().startswith('processes')), None)
    if start is None:
        print('no Processes table in ' + p)
        return 1
    end = next((i for i in sec if i > start), len(lines))
    head, rows, idx = table(lines[start + 1:end])
    li, hi = col(head, 'last'), col(head, 'health')
    for r, i in zip(rows, idx):
        if r[0] == pid and li is not None and hi is not None:
            r[li] = now().strftime('%Y-%m-%d %H:%M')
            r[hi] = health
            lines[start + 1 + i] = '| ' + ' | '.join(r) + ' |'
            with open(p, 'w', encoding='utf-8') as f:
                f.write('\n'.join(lines))
            print('%s marked %s at %s' % (pid, health, r[li]))
            return 0
    print('no process %s (or no Last run / Health column) in %s' % (pid, p))
    return 1


def overlaps(lanes):
    norm = lambda s: s.strip().strip('`').rstrip('/').lstrip('./')
    owned = [(ln['lane'], [norm(x) for x in re.split(r'[,;]', ln['owns']) if norm(x) and not x.strip().startswith(('(', '-'))]) for ln in lanes]
    out = []
    for i in range(len(owned)):
        for j in range(i + 1, len(owned)):
            for a in owned[i][1]:
                for b in owned[j][1]:
                    if a == b or a.startswith(b + '/') or b.startswith(a + '/'):
                        out.append((owned[i][0], owned[j][0], a if len(a) <= len(b) else b))
    return out


def cmd_plan(d):
    model = load(d)
    if not model:
        print('no PROCESSES.md in %s: run init' % d)
        return 1
    entries = list(iter_ledger_rows(d))
    rows = ledger_rows(entries)
    due = due_list(model)
    clash = {(a, b) for a, b, _ in overlaps(model['lanes'])}
    for ln in model['lanes']:
        words = [w.strip().lower() for w in re.split(r'[,;]| and ', ln['covers']) if w.strip()]
        mine = [pr for pr, _ in due if pr['id'].lower() in [re.sub(r'\W', '', w) for w in ln['covers'].lower().split()]]
        cand = [(k, v) for k, v in rows.items() if v[0] in OPEN and any(w.split()[0] in (v[1] or '').lower() for w in words if w.split())]
        try:
            wip = int(re.sub(r'\D', '', ln['wip']) or 1)
        except ValueError:
            wip = 1
        print('%s (%s, WIP %d, owns %s)%s' % (ln['lane'], ln['runner'], wip, ln['owns'] or '-', ' waits on ' + ln['waits'] if ln['waits'] not in ('', '-') else ''))
        for pr in mine:
            print('  due: %s %s' % (pr['id'], pr['name']))
        for k, v in cand[:wip + 2]:
            print('  row: %s %s (%s)' % (k, v[2][:90], v[0]))
        if not mine and not cand:
            print('  nothing open')
    free = [ln['lane'] for ln in model['lanes'] if ln['waits'] in ('', '-')]
    print('parallel now: ' + (', '.join(free) or 'none') + ('' if not clash else '; not together: ' + ', '.join('%s+%s' % c for c in sorted(clash))))
    reviews = []
    current = now()
    for ledger, row_id, status, _, action, deadline in entries:
        if status != 'waiting':
            continue
        at = review_time(deadline)
        if at is not None and at <= current:
            reviews.append((at, ledger, row_id, deadline, action))
    if reviews:
        print('Result reviews due (use the authorized process or session):')
        for _, ledger, row_id, deadline, action in sorted(reviews):
            print(f'  {row_id} {deadline} | {ledger} | {action[:90]}')
    return 0


def cmd_check(d):
    model, fails, warns = load(d), [], []
    if not model:
        print('FAIL no PROCESSES.md in %s: run init' % d)
        return 1
    s = model['strategy']
    for k in STRATEGY_KEYS:
        v = s.get(k, '')
        if not v:
            fails.append('strategy has no "%s" line' % k)
        elif '<' in v and '>' in v:
            warns.append('strategy not written yet: ' + k)
    rb = parse_time(s.get('Review by', ''))
    if rb and rb < now():
        warns.append('strategy review overdue (Review by %s)' % rb.date())
    rows = ledger_rows(iter_ledger_rows(d))
    for k in re.findall(r'\b([A-Z][A-Za-z]?\d{1,3}[a-z]?)\b', s.get('Coherent actions', '')):
        if k not in rows:
            warns.append('coherent action names %s, which is not a ledger row' % k)
        elif rows[k][0] == 'cut':
            warns.append('coherent action names %s, which is cut' % k)
    if not model['procs']:
        fails.append('no processes in the Processes table')
    loop = None
    t = now()
    for pr in model['procs']:
        missing = [n for n in ('id', 'name', 'when', 'runner', 'how', 'done') if not pr[n]]
        if missing:
            fails.append('%s is missing %s' % (pr['id'] or '(row)', ', '.join(missing)))
            continue
        ok, parts = runner_ok(pr['runner'])
        if not ok:
            fails.append('%s runner "%s" is not one of %s or task:/automation:/human:<name>' % (pr['id'], pr['runner'], '/'.join(RUNNERS)))
        for x in parts:
            if x == 'loop':
                loop = loop if loop is not None else (loop_scheduled(d) or False)
                if loop is False:
                    warns.append('%s runs on loop, but no schedule runs this folder (run-company scripts/schedule.sh)' % pr['id'])
            if x.startswith('task:') and not os.path.exists(os.path.join(TASKS, x[5:], 'SKILL.md')):
                warns.append('%s names desktop task %s, which does not exist' % (pr['id'], x[5:]))
        kind, due, period = cadence(pr['when'], parse_time(pr['last']), t)
        if kind == 'unknown' and pr['when'] != '(as scheduled)':
            warns.append('%s When "%s" is not a cadence this script reads (every run, hourly, every 3h, daily 16:30, weekly sun, monthly 1, on <event>)' % (pr['id'], pr['when']))
        last = parse_time(pr['last'])
        if period and last and t - last > 2 * period:
            warns.append('%s is late: last run %s, cadence %s' % (pr['id'], pr['last'], pr['when']))
        if pr['health'].lower().startswith('failing'):
            warns.append('%s is failing: fix its How before more rows on its lane' % pr['id'])
        if not how_exists(pr['how'], d):
            warns.append('%s How names a file that does not exist: %s' % (pr['id'], pr['how']))
    for a, b, path in overlaps(model['lanes']):
        warns.append('lanes %s and %s both own %s: give each file set one writer' % (a, b, path))
    n = model['text'].count('\n')
    if n > 150:
        warns.append('PROCESSES.md is %d lines; keep it under 150 (move long steps into the files the How column names)' % n)
    for x in fails:
        print('FAIL ' + x)
    for x in warns:
        print('WARN ' + x)
    if not fails and not warns:
        print('ok: %d processes, %d lanes, strategy written' % (len(model['procs']), len(model['lanes'])))
    return 1 if fails else 0


def cmd_missing():
    try:
        reg = json.load(open(REGISTRY, encoding='utf-8')).get('projects', {})
    except Exception:
        reg = {}
    n = 0
    for path in sorted(reg):
        if os.path.isdir(path) and any(os.path.exists(os.path.join(path, x)) for x in LEDGERS) and not os.path.exists(os.path.join(path, 'PROCESSES.md')):
            print(path.replace(HOME, '~', 1))
            n += 1
    print('%d project(s) with a ledger and no PROCESSES.md' % n)
    return 0


def main(argv):
    if len(argv) < 2 or argv[1] not in ('init', 'due', 'mark', 'plan', 'check', 'missing'):
        print(__doc__.strip())
        return 2
    cmd = argv[1]
    if cmd == 'missing':
        return cmd_missing()
    d = argv[2] if len(argv) > 2 else '.'
    if cmd == 'init':
        return cmd_init(d)
    if cmd == 'due':
        runner = argv[argv.index('--runner') + 1] if '--runner' in argv and argv.index('--runner') + 1 < len(argv) else None
        return cmd_due(d, runner, '--all' in argv)
    if cmd == 'mark':
        if len(argv) < 4:
            print('usage: processes.py mark <dir> <ID> [ok|late|failing]')
            return 2
        return cmd_mark(d, argv[3], argv[4] if len(argv) > 4 else 'ok')
    if cmd == 'plan':
        return cmd_plan(d)
    return cmd_check(d)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
