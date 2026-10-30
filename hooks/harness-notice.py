"""Tell a running Claude Code or Codex session which harness files changed after it started.

A session reads its global rules (~/.claude/CLAUDE.md or ~/.codex/AGENTS.md) once, at start, and keeps any skill it
already read in its context. Scripts and hook scripts always run from disk, so they need no notice; the rules and the
skill documents do. Called from hooks that both tools already run (UserPromptSubmit reply-budget.sh, Claude Code's
PostToolUse counter), so a change reaches every running session without a restart or a new hook registration.
Reads the hook payload on stdin; prints one line, or with --json EVENT the hookSpecificOutput JSON; once per change.
Never blocks: any failure prints nothing.
"""
import glob, hashlib, json, os, re, subprocess, sys, time

HOME = os.path.expanduser('~')
SKILLS = os.environ.get('HARNESS_SKILLS_DIR', os.path.join(HOME, '.agents', 'skills'))
RULES = {'claude': os.environ.get('HARNESS_RULES_CLAUDE') or os.environ.get('HARNESS_RULES_FILE') or os.path.join(HOME, '.claude', 'CLAUDE.md'),
         'codex': os.environ.get('HARNESS_RULES_CODEX', os.path.join(HOME, '.codex', 'AGENTS.md'))}


def ancestors():
    """(command, start epoch) of this hook's parent processes, nearest first."""
    pid, out = os.getppid(), []
    for _ in range(8):
        line = subprocess.run(['ps', '-o', 'ppid=,lstart=,command=', '-p', str(pid)], capture_output=True, text=True, timeout=5).stdout.strip()
        if not line:
            break
        ppid, rest = line.split(None, 1)
        try:
            out.append((rest[24:].strip(), time.mktime(time.strptime(rest[:24], '%a %b %d %H:%M:%S %Y'))))
        except ValueError:
            pass
        pid = int(ppid)
        if pid <= 1:
            break
    return out


def main():
    as_json = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == '--json' else ''
    try:
        payload = json.loads(sys.stdin.read() or '{}')
    except ValueError:
        payload = {}
    tp = payload.get('transcript_path') or ''
    start = float(os.environ.get('HARNESS_SESSION_START') or 0)
    if not start and tp and os.path.isfile(tp):
        start = getattr(os.stat(tp), 'st_birthtime', 0)  # the transcript is born with the session
    procs = [] if start else ancestors()
    start = start or next((t for c, t in procs if re.search(r'\b(codex|claude)\b', c)), 0)
    if not start:
        return
    tool = os.environ.get('HARNESS_TOOL') or ('codex' if '/.codex/' in tp or any(re.search(r'\bcodex\b', c) for c, _ in procs) else 'claude')
    key = hashlib.sha1((tp or payload.get('session_id') or str(start)).encode()).hexdigest()[:16]
    seen_file = os.path.join(os.environ.get('TMPDIR', '/tmp'), '.harness-notice-' + key)
    try:
        seen = float(open(seen_file).read().strip() or 0)
    except (OSError, ValueError):
        seen = 0
    since = max(start, seen)
    changed = []
    rules = RULES[tool]
    if os.path.isfile(rules) and os.path.getmtime(rules) > since:
        changed.append((os.path.getmtime(rules), 'the global rules ' + rules.replace(HOME, '~', 1)))
    skills = {}
    for doc in glob.glob(os.path.join(SKILLS, '*', '*.md')):
        m = os.path.getmtime(doc)
        if m > since:
            name = os.path.basename(os.path.dirname(doc))
            skills[name] = max(skills.get(name, 0), m)
    if not changed and not skills:
        return
    newest = max([m for m, _ in changed] + list(skills.values()))
    open(seen_file, 'w').write(str(newest))
    names = sorted(skills, key=lambda n: -skills[n])
    parts = [t for _, t in changed]
    if names:
        parts.append('the skill%s %s (%s/<name>/)' % ('s' if len(names) > 1 else '', ', '.join(names[:10]) + (' and %d more' % (len(names) - 10) if len(names) > 10 else ''),
                                                      SKILLS.replace(HOME, '~', 1)))
    text = ('Harness updated after this session started: %s. Re-read the ones that bear on your current work before the next step and follow '
            'the current versions; scripts and hooks already run the new code.' % '; '.join(parts))
    if as_json:
        print(json.dumps({'hookSpecificOutput': {'hookEventName': as_json, 'additionalContext': text}}))
    else:
        print(text)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        pass
