"""Build a project's workspace view from its own files: the ledger (COMPANY.md, READINESS.md, PORTFOLIO.md or any
table with ID and Status columns), GOAL.md and the other root docs, research and docs folders, the AGENTS.md lessons,
the shared learnings logs for this project, every tracked file and the recent commits. Writes <project>/.workspace/
data.json and a self-contained index.html (view.html next to this script with the data inlined), ready to open
locally or to publish as the project's private page. A project adds its own live sections with an executable
scripts/workspace-extra.py that prints JSON: {"sections": [{"id", "title", "kind": "kpis|table|bars|markdown", ...}]}.
Usage: python3 -I workspace.py <project-dir>     No dependencies.
"""
import datetime, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEARN = os.environ.get('LEARNINGS_DIR', os.path.expanduser('~/.agents/learnings'))
DOC_LIMIT = 80000  # characters kept per document
SKIP_DIRS = {'.git', 'node_modules', '.runtime', '.workspace', '.venv', '__pycache__', 'data'}


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
    w = re.sub(r'[`*_]', '', s).strip().split(' ')[0].lower() if s.strip() else ''
    return {'done': 'verified', 'complete': 'verified', 'blocked': 'owner'}.get(w, w or 'todo')


def pick(row, *names):
    for n in names:
        for k in row:
            if k.lower().startswith(n):
                return row[k]
    return ''


def ledger_files(root):
    found = []
    for base in ['', *sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)) and d not in SKIP_DIRS and not d.startswith('.'))]:
        for name in ('COMPANY.md', 'READINESS.md', 'PORTFOLIO.md'):
            p = os.path.join(root, base, name)
            if os.path.isfile(p):
                found.append(os.path.join(base, name) if base else name)
    return found


def collect(root):
    root = os.path.abspath(root)
    name = os.path.basename(root)
    data = {'project': {'folder': name, 'name': name.replace('-', ' ').title(), 'generated': datetime.datetime.now().astimezone().isoformat(timespec='minutes')},
            'kpis': [], 'rows': [], 'owner_actions': [], 'waiting': [], 'decisions': [], 'log': [], 'docs': [], 'lessons': [],
            'learnings': [], 'runs': [], 'owner_asks': [], 'files': [], 'commits': [], 'links': [], 'extra': []}
    p = data['project']
    for rel in ledger_files(root):
        text = read(os.path.join(root, rel)); scope = os.path.dirname(rel) or 'company'
        h = re.search(r'^#\s+(.+?)\s*$', text, re.M)
        if h and rel in ('COMPANY.md', 'PORTFOLIO.md'):
            p['name'] = re.split(r'\s+-\s+', h.group(1))[0].strip()
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
    goal = read(os.path.join(root, 'GOAL.md'))
    if goal:
        first = next((b for b in goal.split('\n\n') if b.strip() and not b.startswith('#')), '')
        p.setdefault('goal', first.strip())
        m = re.search(r'^Thesis:\s*(.+)$', goal, re.M)
        if m:
            p.setdefault('thesis', m.group(1).strip())
    data['links'] = sorted(set(data['links']))
    # documents: root docs, research, docs, sales and money notes, sub-project ledgers and AGENTS.md
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
    for folder, group in (('research', 'Research'), ('docs', 'Docs'), ('money', 'Money'), ('knowledge', 'Knowledge')):
        d = os.path.join(root, folder)
        if os.path.isdir(d):
            for f in sorted(os.listdir(d)):
                if f.endswith('.md') and os.path.isfile(os.path.join(d, f)):
                    add_doc(os.path.join(folder, f), group)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [x for x in dirnames if x not in SKIP_DIRS and not x.startswith('.')]
        rel_dir = os.path.relpath(dirpath, root)
        if rel_dir == '.' or rel_dir.split(os.sep)[0] in ('research', 'docs', 'money', 'knowledge'):
            continue
        for f in filenames:
            if f in ('README.md', 'AGENTS.md', 'READINESS.md', 'PRODUCT.md'):
                add_doc(os.path.join(rel_dir, f), rel_dir.split(os.sep)[0].title())
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
    # files and commits
    def git(*args):
        try:
            return subprocess.run(['git', '-C', root, *args], capture_output=True, text=True, timeout=30).stdout
        except (OSError, subprocess.SubprocessError):
            return ''
    for rel in git('ls-files').split('\n'):
        full = os.path.join(root, rel)
        if rel and os.path.isfile(full):
            st = os.stat(full)
            data['files'].append({'path': rel, 'size': st.st_size, 'modified': datetime.date.fromtimestamp(st.st_mtime).isoformat()})
    for line in git('log', '-40', '--date=short', '--pretty=%h%x09%ad%x09%s').split('\n'):
        if line.count('\t') >= 2:
            h, d, s = line.split('\t', 2)
            data['commits'].append({'hash': h, 'date': d, 'subject': s})
    remote = git('remote', 'get-url', 'origin').strip()
    m = re.match(r'(?:https://(?:[^@/]+@)?github\.com/|git@github\.com:)([^/]+/[^/.]+)', remote)
    if m:
        p['repo'] = 'https://github.com/' + m.group(1)
        p['branch'] = git('rev-parse', '--abbrev-ref', 'HEAD').strip() or 'main'
    # the project's own live sections
    extra = os.path.join(root, 'scripts', 'workspace-extra.py')
    if os.path.isfile(extra):
        try:
            out = subprocess.run([sys.executable, '-I', extra, root], capture_output=True, text=True, timeout=120).stdout
            data['extra'] = json.loads(out).get('sections', [])
        except (OSError, subprocess.SubprocessError, ValueError) as e:
            data['extra'] = [{'id': 'extra', 'title': 'Live data', 'kind': 'markdown', 'md': 'The project script failed: ' + str(e)[:200]}]
    return data


def main():
    if len(sys.argv) < 2 or not os.path.isdir(sys.argv[1]):
        sys.exit('usage: workspace.py <project-dir>')
    root = os.path.abspath(sys.argv[1])
    data = collect(root)
    out = os.path.join(root, '.workspace'); os.makedirs(out, exist_ok=True)
    blob = json.dumps(data, ensure_ascii=False)
    open(os.path.join(out, 'data.json'), 'w', encoding='utf-8').write(blob)
    view = read(os.path.join(HERE, '..', 'view.html'))
    page = view.replace('__WORKSPACE_DATA__', blob.replace('</', '<\\/'))
    page = page.replace('<title>Project Workspace</title>', '<title>%s Workspace</title>' % data['project']['name'].replace('<', ''), 1)
    open(os.path.join(out, 'artifact.html'), 'w', encoding='utf-8').write(page)  # body only: the Artifact publish adds the document shell
    open(os.path.join(out, 'index.html'), 'w', encoding='utf-8').write(
        '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"></head><body>\n' + page + '\n</body></html>\n')
    gi = os.path.join(root, '.gitignore')
    if os.path.isdir(os.path.join(root, '.git')) and '.workspace/' not in read(gi):
        with open(gi, 'a', encoding='utf-8') as f:
            f.write(('' if read(gi).endswith('\n') or not read(gi) else '\n') + '.workspace/\n')
    print('%s: %d rows, %d docs, %d files, %d lessons, %d learnings, %d extra sections -> %s' % (
        data['project']['name'], len(data['rows']), len(data['docs']), len(data['files']), len(data['lessons']), len(data['learnings']),
        len(data['extra']), os.path.relpath(os.path.join(out, 'index.html'), root)))


if __name__ == '__main__':
    main()
