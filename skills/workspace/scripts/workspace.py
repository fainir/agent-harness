"""Build a project's workspace view from its own files: the ledger (COMPANY.md, READINESS.md, PORTFOLIO.md or any
table with ID and Status columns), the .claude/plan.md checkbox tasks, GOAL.md and the other root docs, research and docs
folders, the AGENTS.md lessons, the shared learnings logs for this project, every tracked file and the recent commits.
Writes <project>/.workspace/ data.json and a self-contained page (view.html next to this script with the data inlined),
ready to open locally or to publish as the project's private page. Secrets are redacted before anything is written: the
values in the project's .env files and anything shaped like an API key, token or private key. A project adds its own live
sections with an executable scripts/workspace-extra.py that prints JSON:
{"sections": [{"id", "title", "kind": "kpis|table|bars|markdown", ...}]}.
Every build is recorded in ~/.agents/workspaces/registry.json, which the all-projects page reads.
Usage: python3 -I workspace.py <project-dir> [...]       build each project's page
       python3 -I workspace.py --url <project-dir> <url>  record where that page is published
       python3 -I workspace.py --hub [--url <url>]        build the all-projects page (--url records where it is published)
       python3 -I workspace.py --stale                    registered projects whose files changed since their last build
       python3 -I workspace.py --diff <published> <new>   what a republish changes, to read before publishing (save the published
                                                          page with the Artifact tool's read, path index.html; <new> is .workspace/artifact.html)
No dependencies.
"""
import collections, datetime, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEARN = os.environ.get('LEARNINGS_DIR', os.path.expanduser('~/.agents/learnings'))
HUB = os.environ.get('WORKSPACES_DIR', os.path.expanduser('~/.agents/workspaces'))
REGISTRY = os.path.join(HUB, 'registry.json')
DOC_LIMIT = 80000  # characters kept per document
DOCS_MAX = 150  # sub-folder README/AGENTS/READINESS/PRODUCT files kept
FILES_MAX = 20000
SKIP_DIRS = {'.git', 'node_modules', '.runtime', '.workspace', '.venv', 'venv', '__pycache__', 'data', 'dist', 'build', 'out', 'target', 'vendor', 'coverage', 'Pods', 'DerivedData'}
STATUS_WORDS = {'done': 'verified', 'complete': 'verified', 'completed': 'verified', 'fixed': 'verified', 'shipped': 'verified', 'live': 'verified',
                'passed': 'verified', 'blocked': 'owner', 'active': 'building', 'doing': 'building', 'wip': 'building', 'in': 'building',
                'in-progress': 'building', 'partial': 'building', 'pending': 'todo', 'open': 'todo', 'deferred': 'todo', 'dropped': 'cut', 'skipped': 'cut'}
PLAN_MARKS = {' ': 'todo', '~': 'building', 'x': 'verified', 'X': 'verified', '!': 'owner', '-': 'cut'}
TOKENS = [re.compile(p) for p in (
    r'\bsk-(?:ant-|proj-)?[A-Za-z0-9_\-]{20,}', r'\b[rsp]k_(?:live|test)_[A-Za-z0-9]{16,}', r'\bwhsec_[A-Za-z0-9]{16,}', r'\bgh[pousr]_[A-Za-z0-9]{30,}',
    r'\bgithub_pat_[A-Za-z0-9_]{30,}', r'\bxox[abposr]-[A-Za-z0-9\-]{10,}', r'\bAKIA[0-9A-Z]{16}\b', r'\bAIza[0-9A-Za-z_\-]{35}', r'\b\d{8,10}:AA[A-Za-z0-9_\-]{30,}',
    r'\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}', r'\bnpm_[A-Za-z0-9]{36}', r'\bglpat-[A-Za-z0-9_\-]{20}', r'\bshpat_[a-fA-F0-9]{32}',
    r'\bre_[A-Za-z0-9]{8}_[A-Za-z0-9]{16,}', r'\bSG\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}',
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----', r'(?<=://)[^/\s:@\'"]+:[^/\s@\'"]+(?=@)')]
SECRET_NAME = re.compile(r'KEY|SECRET|TOKEN|PASS|PWD|PRIVATE|CREDENTIAL|AUTH|SID|DSN|DATABASE_URL|REDIS_URL|WEBHOOK|COOKIE|SESSION|SALT|SIGN', re.I)


def read(p):
    try:
        return open(p, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError):
        return ''


def sections(text):
    """'## Heading' -> body text, in order."""
    out, name, buf = [], '', []
    for line in text.split('\n'):
        m = re.match(r'^##\s+(.+?)\s*$', line)
        if m:
            out.append((name, '\n'.join(buf))); name, buf = m.group(1), []
        else:
            buf.append(line)
    out.append((name, '\n'.join(buf)))
    return out


def cells(line):
    line = line.strip()
    if line.startswith('|'):
        line = line[1:]
    if line.endswith('|'):
        line = line[:-1]
    return [c.strip() for c in re.split(r'(?<!\\)\|', line)]


def tables(body):
    """Markdown tables in a block -> list of (header, rows as dicts)."""
    out, lines, i = [], body.split('\n'), 0
    while i < len(lines) - 1:
        if lines[i].strip().startswith('|') and re.match(r'^\s*\|?\s*:?-{2,}', lines[i + 1]):
            head = cells(lines[i]); rows = []; i += 2
            while i < len(lines) and lines[i].strip().startswith('|'):
                c = cells(lines[i]); rows.append({head[k]: (c[k] if k < len(c) else '') for k in range(len(head))}); i += 1
            out.append((head, rows))
        else:
            i += 1
    return out


def items(body, numbered=False):
    pat = r'^\s*\d+\.\s+(.*)$' if numbered else r'^\s*-\s+(.*)$'
    return [m.group(1).strip() for m in (re.match(pat, l) for l in body.split('\n')) if m]


def first_word(s):
    w = re.sub(r'[`*_]', '', s).strip().split(' ')[0].lower().strip(':,.') if s.strip() else ''
    return 'verified' if w.startswith('✅') else STATUS_WORDS.get(w, w or 'todo')


def pretty(s):
    """A folder slug reads as words; a name someone wrote stays as written."""
    return s.replace('-', ' ').replace('_', ' ').title() if re.fullmatch(r'[a-z0-9]+(?:[-_ ][a-z0-9]+)*', s) else s


def pick(row, *names):
    for n in names:
        for k in row:
            if k.lower().startswith(n):
                return row[k]
    return ''


def heading_name(text):
    """'# Acme - Company ledger', '# FeedBot - Company Plan', '# Project Plan: MODULO - kits' -> the name; '' for a bare plan title."""
    h = re.search(r'^#\s+(.+?)\s*$', text, re.M)
    t = re.sub(r'^project plan\s*:\s*', '', h.group(1), flags=re.I) if h else ''
    if not t or re.match(r'^plan\b', t, re.I):
        return ''
    t = re.split(r'\s+[-–—]\s+', t)[0]
    return re.sub(r'\s*\b(?:(?:company|portfolio|master|project)\s+)?(?:readiness|ledger|plan)\s*$', '', t, flags=re.I).strip(' -:')


def plan_rows(text, rel):
    """Checkbox tasks ('- [ ]' todo, '[~]' building, '[x]' done, '[!]' blocked, '[-]' cut) -> rows; the nearest heading is the track."""
    rows, track = [], ''
    for line in text.split('\n'):
        h = re.match(r'^#{2,4}\s+(.+?)\s*$', line)
        if h:
            track = h.group(1)
        m = re.match(r'^\s*[-*]\s+\[([ xX~!\-])\]\s+(.+)$', line)
        if not m:
            continue
        parts = re.split(r'\s+(?:-\s+)?DoD:\s*', m.group(2), maxsplit=1)
        title, dod = parts[0], (parts[1] if len(parts) > 1 else '')
        i = re.match(r'([A-Z]{1,3}\d+[a-z]?)\b[\s:.\-]*(.+)$', title)
        rows.append({'id': i.group(1) if i else 'T%d' % (len(rows) + 1), 'title': i.group(2) if i else title, 'status': PLAN_MARKS[m.group(1)],
                     'status_text': '', 'track': track, 'serves': '', 'owner': '', 'due': '', 'evidence': '', 'dod': dod, 'source': rel, 'scope': 'plan'})
    return rows


def ledger_files(root):
    found = []
    for base in ['', *sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)) and d not in SKIP_DIRS and not d.startswith('.'))]:
        for name in ('COMPANY.md', 'READINESS.md', 'PORTFOLIO.md'):
            p = os.path.join(root, base, name)
            if os.path.isfile(p):
                found.append(os.path.join(base, name) if base else name)
    return found


def git(root, *args):
    try:
        return subprocess.run(['git', '-C', root, *args], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


def collect(root):
    root = os.path.abspath(root)
    name = os.path.basename(root)
    data = {'project': {'folder': name, 'name': pretty(name), 'generated': datetime.datetime.now().astimezone().isoformat(timespec='minutes')},
            'kpis': [], 'rows': [], 'owner_actions': [], 'waiting': [], 'decisions': [], 'log': [], 'docs': [], 'lessons': [],
            'learnings': [], 'runs': [], 'owner_asks': [], 'files': [], 'commits': [], 'links': [], 'extra': []}
    p = data['project']
    for rel in ('COMPANY.md', 'PORTFOLIO.md', 'READINESS.md', '.claude/plan.md'):
        n = heading_name(read(os.path.join(root, rel)))
        if n:
            p['name'] = pretty(n)
            break
    for rel in ledger_files(root):
        text = read(os.path.join(root, rel)); scope = os.path.dirname(rel) or 'company'
        for key in ('Goal', 'Stage', 'Thesis'):
            m = re.search(r'^' + key + r':\s*(.+)$', text, re.M)
            if m and key.lower() not in p:
                p[key.lower()] = m.group(1).strip()
        for sec, body in sections(text):
            low = sec.lower()
            for head, rows in tables(body):
                hl = [x.lower() for x in head]
                if 'kpi' in hl:
                    data['kpis'] += [{'kpi': r.get('KPI', ''), 'source': pick(r, 'source'), 'now': pick(r, 'now'), 'target': pick(r, 'target'), 'by': pick(r, 'by'), 'updated': pick(r, 'updated')} for r in rows]
                elif 'id' in hl and any(x.startswith('status') for x in hl):
                    for r in rows:
                        status_cell = pick(r, 'status')
                        title = pick(r, 'action', 'flow', 'gate', 'item', 'task', 'what') or next((v for k, v in r.items() if k.lower() not in ('id',)), '')
                        data['rows'].append({'id': r.get('ID', ''), 'title': title, 'status': first_word(status_cell), 'status_text': status_cell,
                                             'track': pick(r, 'track') or sec, 'serves': pick(r, 'serves'), 'owner': pick(r, 'owner'), 'due': pick(r, 'due', 'updated'),
                                             'evidence': pick(r, 'evidence'), 'source': rel, 'scope': scope})
                elif low.startswith('waiting'):
                    data['waiting'] += [{'what': pick(r, 'what'), 'since': pick(r, 'since'), 'next': pick(r, 'next'), 'notes': pick(r, 'notes'), 'source': rel} for r in rows]
                elif low.startswith('scope'):
                    for r in rows:
                        data['links'] += [u.rstrip(').,') for u in re.findall(r'https?://\S+', ' '.join(r.values()))]
            if low.startswith('owner actions'):
                for it in items(body, numbered=True):
                    data['owner_actions'].append({'text': it, 'done': bool(re.search(r'\bdone\b', it[:120], re.I)), 'source': rel})
            elif low.startswith('decisions'):
                for it in items(body):
                    m = re.match(r'(\d{4}-\d{2}-\d{2})\s+-\s+(.*)', it)
                    data['decisions'].append({'date': m.group(1) if m else '', 'text': m.group(2) if m else it, 'source': rel})
            elif low.startswith('log'):
                for it in items(body):
                    m = re.match(r'(\d{4}-\d{2}-\d{2})\s+-\s+(.*)', it)
                    data['log'].append({'date': m.group(1) if m else '', 'text': m.group(2) if m else it, 'source': rel})
    plan = read(os.path.join(root, '.claude', 'plan.md'))
    data['rows'] += plan_rows(plan, '.claude/plan.md')
    goal = read(os.path.join(root, 'GOAL.md'))
    paras = [x for x in (re.sub(r'^(?:#.*(?:\n|$))+', '', b).strip() for b in goal.split('\n\n')) if x]
    if paras and paras[0].lower().startswith('thesis:'):
        p.setdefault('thesis', paras.pop(0)[7:].strip())
    if paras:
        p.setdefault('goal', paras[0])
        p['goal_more'] = paras[1] if len(paras) > 1 else ''
    m = re.search(r'^Thesis:\s*(.+)$', goal, re.M)
    if m:
        p.setdefault('thesis', m.group(1).strip())
    for sec, body in (sections(plan) if 'goal' not in p else []):
        para = next((b.strip() for b in body.split('\n\n') if b.strip() and not b.strip().startswith(('#', '|', '```'))), '')
        if para and re.match(r'(the\s+)?(goal|vision|overview|mission|summary)', sec, re.I):
            p['goal'] = re.sub(r'\s+', ' ', re.sub(r'(?m)^\s*(?:>|[-*]|\d+\.)\s+', '', para))[:400]
            break
    data['links'] = sorted(set(data['links']))
    # documents: root docs, the plan, research, docs, money notes, sub-project ledgers and AGENTS.md
    def add_doc(rel, group):
        text = read(os.path.join(root, rel))
        if not text.strip():
            return
        h = re.search(r'^#\s+(.+?)\s*$', text, re.M)
        st = os.stat(os.path.join(root, rel))
        data['docs'].append({'path': rel, 'group': group, 'title': h.group(1).strip() if h else rel, 'updated': datetime.date.fromtimestamp(st.st_mtime).isoformat(),
                             'words': len(text.split()), 'md': text[:DOC_LIMIT], 'truncated': len(text) > DOC_LIMIT})
    for f in sorted(os.listdir(root)):
        if f.endswith('.md') and os.path.isfile(os.path.join(root, f)):
            add_doc(f, 'Project')
    for rel in ('.claude/plan.md', '.claude/handoff.md'):
        if os.path.isfile(os.path.join(root, rel)):
            add_doc(rel, 'Plan')
    for folder, group in (('research', 'Research'), ('docs', 'Docs'), ('money', 'Money'), ('knowledge', 'Knowledge')):
        d = os.path.join(root, folder)
        if os.path.isdir(d):
            for f in sorted(os.listdir(d)):
                if f.endswith('.md') and os.path.isfile(os.path.join(d, f)):
                    add_doc(os.path.join(folder, f), group)
    walked = 0
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root)
        dirnames[:] = [] if rel_dir.count(os.sep) >= 3 else sorted(x for x in dirnames if x not in SKIP_DIRS and not x.startswith('.'))
        if rel_dir == '.' or rel_dir.split(os.sep)[0] in ('research', 'docs', 'money', 'knowledge'):
            continue
        for f in sorted(filenames):
            if f in ('README.md', 'AGENTS.md', 'READINESS.md', 'PRODUCT.md') and walked < DOCS_MAX:
                add_doc(os.path.join(rel_dir, f), rel_dir.split(os.sep)[0].title()); walked += 1
    # lessons this project keeps for itself
    for doc in data['docs']:
        if doc['path'].endswith('AGENTS.md'):
            for sec, body in sections(doc['md']):
                if sec.lower().startswith('working here'):
                    data['lessons'] += [{'text': t, 'source': doc['path']} for t in items(body)]
    # shared learnings for this project
    keys = {name.lower(), p['name'].lower()}
    for line in read(os.path.join(LEARN, 'inbox.md')).split('\n'):
        c = cells(line) if line.startswith('|') else []
        if len(c) >= 6 and c[1].lower() in keys:
            data['learnings'].append({'date': c[0], 'phase': c[2], 'what': c[3], 'cause': c[4], 'change': c[5], 'status': c[-1]})
    for line in read(os.path.join(LEARN, 'runs.log')).split('\n'):
        c = [x.strip() for x in line.split('|')]
        if len(c) >= 8 and c[1].lower() in keys:
            vt = c[3].split('/')
            data['runs'].append({'date': c[0], 'tool': c[2], 'verified': vt[0], 'total': vt[1] if len(vt) > 1 else '', 'defects': c[4], 'owner': c[5], 'reruns': c[6], 'minutes': c[7], 'note': c[8] if len(c) > 8 else ''})
    for line in read(os.path.join(LEARN, 'owner-actions.log')).split('\n'):
        c = [x.strip() for x in line.split('|')]
        if len(c) >= 5 and c[1].lower() in keys:
            data['owner_asks'].append({'date': c[0], 'class': c[2], 'what': c[3], 'never_again': c[4]})
    # files and commits; a folder outside git lists what is on disk
    paths = [x for x in git(root, 'ls-files').split('\n') if x]
    if not paths and git(root, 'rev-parse', '--is-inside-work-tree').strip() != 'true':
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [x for x in dirnames if x not in SKIP_DIRS and not x.startswith('.')]
            paths += [os.path.relpath(os.path.join(dirpath, f), root) for f in filenames if not f.startswith('.')]
            if len(paths) > FILES_MAX:
                break
    for rel in paths[:FILES_MAX]:
        full = os.path.join(root, rel)
        if os.path.isfile(full):
            st = os.stat(full)
            data['files'].append({'path': rel, 'size': st.st_size, 'modified': datetime.date.fromtimestamp(st.st_mtime).isoformat()})
    for line in git(root, 'log', '-40', '--date=short', '--pretty=%h%x09%ad%x09%s').split('\n'):
        if line.count('\t') >= 2:
            h, d, s = line.split('\t', 2)
            data['commits'].append({'hash': h, 'date': d, 'subject': s})
    remote = git(root, 'remote', 'get-url', 'origin').strip()
    m = re.match(r'(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:)([^/]+/[^/.]+)', remote)
    if m:
        p['repo'] = 'https://github.com/' + m.group(1)
        p['branch'] = git(root, 'rev-parse', '--abbrev-ref', 'HEAD').strip() or 'main'
    # the project's own live sections
    extra = os.path.join(root, 'scripts', 'workspace-extra.py')
    if os.path.isfile(extra):
        try:
            out = subprocess.run([sys.executable, '-I', extra, root], capture_output=True, text=True, timeout=120).stdout
            data['extra'] = json.loads(out).get('sections', [])
        except (OSError, subprocess.SubprocessError, ValueError) as e:
            data['extra'] = [{'id': 'extra', 'title': 'Live data', 'kind': 'markdown', 'md': 'The project script failed: ' + str(e)[:200]}]
    return data


def env_values(root):
    """Values in the project's .env files that could be secrets: under a secret-looking name, or long mixed letters and digits."""
    vals = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [] if os.path.relpath(dirpath, root).count(os.sep) >= 3 else [x for x in dirnames if x not in SKIP_DIRS]
        for f in filenames:
            if f.startswith('.env') or f.endswith('.env'):
                for line in read(os.path.join(dirpath, f)).split('\n'):
                    m = re.match(r'\s*(?:export\s+)?([A-Za-z_]\w*)\s*=\s*(.*)$', line)
                    v = m.group(2).strip().strip('\'"') if m else ''
                    if len(v) >= 8 and (SECRET_NAME.search(m.group(1)) or (len(v) >= 16 and ' ' not in v and re.search(r'[A-Za-z]', v) and re.search(r'\d', v))):
                        vals.add(v)
    return sorted(vals, key=len, reverse=True)


def redact(obj, values, hits):
    if isinstance(obj, str):
        for v in values:
            if v in obj:
                hits[0] += obj.count(v); obj = obj.replace(v, '[redacted]')
        for r in TOKENS:
            obj, n = r.subn('[redacted]', obj); hits[0] += n
        return obj
    if isinstance(obj, list):
        return [redact(x, values, hits) for x in obj]
    if isinstance(obj, dict):
        return {k: redact(v, values, hits) for k, v in obj.items()}
    return obj


def leaks(text, values):
    return sum(text.count(v) for v in values) + sum(len(r.findall(text)) for r in TOKENS)


def ignore_workspace(root):
    """Keep .workspace/ out of git through the clone's own exclude list, so no tracked file changes."""
    if git(root, 'rev-parse', '--is-inside-work-tree').strip() != 'true':
        return
    if subprocess.run(['git', '-C', root, 'check-ignore', '-q', '.workspace/index.html'], capture_output=True).returncode == 0:
        return
    ex = git(root, 'rev-parse', '--git-path', 'info/exclude').strip()
    if ex:
        ex = ex if os.path.isabs(ex) else os.path.join(root, ex)
        os.makedirs(os.path.dirname(ex), exist_ok=True)
        old = read(ex)
        with open(ex, 'a', encoding='utf-8') as f:
            f.write(('' if not old or old.endswith('\n') else '\n') + '.workspace/\n')


def signature(root):
    mt = [os.stat(os.path.join(root, x)).st_mtime for x in ledger_files(root) + ['.claude/plan.md', '.claude/handoff.md', 'GOAL.md', 'AGENTS.md', 'OWNER.md']
          if os.path.isfile(os.path.join(root, x))]
    return '%s:%d' % (git(root, 'rev-parse', '--short', 'HEAD').strip(), max(mt or [0]))


def load_registry():
    try:
        reg = json.load(open(REGISTRY, encoding='utf-8'))
    except (OSError, ValueError):
        reg = {}
    reg.setdefault('hub_url', ''); reg.setdefault('projects', {})
    return reg


def save_registry(reg):
    os.makedirs(HUB, exist_ok=True)
    tmp = '%s.%d.tmp' % (REGISTRY, os.getpid())
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(reg, f, ensure_ascii=False, indent=1)
    os.replace(tmp, REGISTRY)


def page_from(template, marker, blob, title=None):
    page = read(os.path.join(HERE, '..', template)).replace(marker, blob.replace('</', '<\\/'))
    if title:
        page = page.replace('<title>Project Workspace</title>', '<title>%s Workspace</title>' % title.replace('<', ''), 1)
    return page


def write_page(out, page):
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, 'artifact.html'), 'w', encoding='utf-8').write(page)  # body only: the Artifact publish adds the document shell
    open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(
        '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"></head><body>\n' + page + '\n</body></html>\n')


def build(root):
    data = collect(root)
    data['project']['hub'] = load_registry()['hub_url']
    values, hits = env_values(root), [0]
    data = redact(data, values, hits)
    blob = json.dumps(data, ensure_ascii=False)
    page = page_from('view.html', '__WORKSPACE_DATA__', blob, data['project']['name'])
    if leaks(page, values):
        print('%s: secret-shaped text survived redaction; page not written' % root, file=sys.stderr)
        return False
    out = os.path.join(root, '.workspace')
    write_page(out, page)
    open(os.path.join(out, 'data.json'), 'w', encoding='utf-8').write(blob)
    ignore_workspace(root)
    p, rows = data['project'], data['rows']
    counts = collections.Counter(r['status'] for r in rows)
    needs = [a['text'] for a in data['owner_actions'] if not a['done']] or [(r['id'] + ' ' + r['title']).strip() for r in rows if r['status'] == 'owner']
    url = next((m.group(1) for rel in ledger_files(root) for m in [re.search(r'^Workspace:\s*(https://\S+)', read(os.path.join(root, rel)), re.M)] if m), '')
    reg = load_registry()
    old = reg['projects'].get(root, {})
    reg['projects'][root] = {'name': p['name'], 'path': root, 'where': root.replace(os.path.expanduser('~'), '~', 1), 'stage': p.get('stage', ''),
                             'goal': p.get('goal', '')[:300], 'goal_more': p.get('goal_more', '')[:300], 'total': len(rows), 'counts': dict(counts), 'needs': needs[:3], 'needs_total': len(needs),
                             'waiting': len(data['waiting']) or counts.get('waiting', 0), 'docs': len(data['docs']), 'files': len(data['files']),
                             'last_commit': data['commits'][0]['date'] if data['commits'] else '', 'last_subject': data['commits'][0]['subject'] if data['commits'] else '',
                             'repo': p.get('repo', ''), 'generated': p['generated'], 'sig': signature(root), 'live': bool(data['extra']), 'url': url or old.get('url', '')}
    save_registry(reg)
    print('%s: %d rows, %d docs, %d files, %d lessons, %d learnings, %d extra sections, %d secrets redacted, secret check clean -> %s' % (
        p['name'], len(rows), len(data['docs']), len(data['files']), len(data['lessons']), len(data['learnings']), len(data['extra']), hits[0],
        os.path.join(out, 'artifact.html')))
    return True


def hub(url):
    reg = load_registry()
    if url:
        reg['hub_url'] = url; save_registry(reg)
    projects = sorted((e for k, e in reg['projects'].items() if os.path.isdir(k)), key=lambda e: (e.get('last_commit') or e.get('generated', '')[:10]), reverse=True)
    shared = collections.Counter(e.get('goal', '') for e in projects)
    for e in projects:  # a goal sentence several projects share says less than the project's own next paragraph
        if e.get('goal') and shared[e['goal']] > 1 and e.get('goal_more'):
            e['goal'] = e['goal_more']
    blob = json.dumps({'generated': datetime.datetime.now().astimezone().isoformat(timespec='minutes'), 'projects': projects}, ensure_ascii=False)
    page = page_from('hub.html', '__HUB_DATA__', blob)
    if leaks(page, []):
        sys.exit('hub: secret-shaped text found; page not written')
    out = os.path.join(HUB, 'hub')
    write_page(out, page)
    print('%d projects, %d published -> %s' % (len(projects), sum(1 for e in projects if e.get('url')), os.path.join(out, 'artifact.html')))


def page_parts(path):
    """A built or published page: its template, with the data swapped for a marker, and the embedded data."""
    if not os.path.isfile(path):
        sys.exit('%s: no such file' % path)
    t = read(path)
    m = re.search(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', t, re.S)
    if not m:
        sys.exit('%s: no workspace data in this page' % path)
    return t[:m.start(1)] + '@@DATA@@' + t[m.end(1):], json.loads(m.group(1).replace('<\\/', '</'))


def diff(published, new):
    """Everything a republish changes, so the page is read before it goes out without reading all of it again."""
    import difflib
    (ot, od), (nt, nd) = page_parts(published), page_parts(new)
    out = []
    tpl = [l for l in difflib.unified_diff(ot.split('\n'), nt.split('\n'), lineterm='', n=0) if l.startswith('+') and not l.startswith('+++')]
    if tpl:  # lines only the published copy has are the publish wrapper, so only added lines count
        out += ['template: %d new or changed lines' % len(tpl)] + ['  ' + l for l in tpl]
    for k, n in nd.items():
        o = od.get(k)
        if k == 'project':
            out += ['project: %s = %s' % (f, json.dumps(n[f], ensure_ascii=False)) for f in n if f != 'generated' and n.get(f) != (o or {}).get(f)]
        elif k == 'docs':
            old = {d['path']: d.get('md', '') for d in o or []}
            for d in n:
                if old.get(d['path']) == d.get('md', ''):
                    continue
                lines = [l for l in difflib.unified_diff(old.get(d['path'], '').split('\n'), d.get('md', '').split('\n'), lineterm='', n=0)
                         if l[:1] in '+-' and l[:3] not in ('+++', '---')]
                out += ['doc %s: %s' % (d['path'], 'new' if d['path'] not in old else '%d changed lines' % len(lines))] + ['  ' + l for l in lines]
        elif k == 'files':
            old = {f['path'] for f in o or []}
            fresh = [f['path'] for f in n if f['path'] not in old]
            if fresh:
                out.append('files: new ' + ', '.join(fresh))
        elif isinstance(n, list):
            seen = {json.dumps(x, sort_keys=True) for x in o or []}
            fresh = [x for x in n if json.dumps(x, sort_keys=True) not in seen]
            if fresh:
                out += ['%s: %d new or changed' % (k, len(fresh))] + ['  ' + json.dumps(x, ensure_ascii=False) for x in fresh]
        elif n != o:
            out.append('%s: %s' % (k, json.dumps(n, ensure_ascii=False)))
    print('\n'.join(out) if out else 'no changes since the published page')


def main():
    a = sys.argv[1:]
    if a[:1] == ['--diff'] and len(a) == 3:
        return diff(a[1], a[2])
    if a[:1] == ['--hub']:
        return hub(a[2] if a[1:2] == ['--url'] and len(a) > 2 else '')
    if a == ['--stale']:
        for k, e in sorted(load_registry()['projects'].items()):
            if os.path.isdir(k) and (e.get('live') or signature(k) != e.get('sig')):
                print(k)
        return
    if a[:1] == ['--url'] and len(a) == 3:
        reg, root = load_registry(), os.path.abspath(a[1])
        if root not in reg['projects']:
            sys.exit('build it first: workspace.py ' + root)
        reg['projects'][root]['url'] = a[2]; save_registry(reg)
        return
    if not a or not all(os.path.isdir(x) for x in a):
        sys.exit('usage:' + __doc__.split('Usage:')[1].split('No dependencies')[0].rstrip())
    ok = True
    for x in a:
        try:
            ok = build(os.path.abspath(x)) and ok
        except Exception as e:  # one broken project never stops the others
            print('%s: failed: %s' % (x, e), file=sys.stderr); ok = False
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
