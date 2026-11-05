#!/usr/bin/env bash
# PreToolUse hook for the Bash tool: when the shell is zsh (the macOS default), block the zsh traps agents keep
# falling into, with the fix, before the command runs. A rule line alone did not stop them (learnings inbox,
# 6 slips on 2026-10-30). Quoted strings and heredoc bodies are ignored, so scripts and messages never trip it.
# It also blocks `codex exec` with stdin left open, under any shell: codex reads stdin even with a prompt argument,
# and a Bash-tool or background shell never closes it, so the run waits forever (2026-11-01: 40 minutes; 2026-11-05).
# Exit 2 with the reason on stderr blocks the call; anything else lets it run. ZSH_GUARD_FORCE=1 checks under any shell.
# The check is Python, read from fd 3 so stdin stays the hook payload.
exec python3 -I /dev/fd/3 3<<'PY'
import json, os, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if data.get("tool_name") not in (None, "Bash"):
    sys.exit(0)
cmd = (data.get("tool_input") or {}).get("command") or ""

# Drop heredoc bodies, then quoted strings: what is left is what zsh itself parses.
out, end = [], None
for line in cmd.split("\n"):
    if end is not None:
        if line.strip() == end:
            end = None
        continue
    m = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
    if m:
        end = m.group(1)
    out.append(line)
bare = "\n".join(out)
bare = re.sub(r"'[^']*'", "''", bare)
bare = re.sub(r'"(?:[^"\\]|\\.)*"', '""', bare)

# Any shell: `codex exec` needs stdin closed (< /dev/null), fed (a pipe or heredoc), or it hangs at
# "Reading additional input from stdin". --help never reads it.
if re.search(r"\bcodex\s+exec\b", bare) and not re.search(r"<\s*/dev/null|<<|\|\s*codex\s+exec\b|\s--help\b|\s-h\b", bare):
    sys.stderr.write("zsh-guard: codex exec reads stdin even with a prompt argument, and the Bash tool (above all in the background) "
                     "never closes it, so it waits forever at 'Reading additional input from stdin'. Add < /dev/null to the codex exec "
                     "command (or feed it with a pipe or heredoc) and run it again.\n")
    sys.exit(2)
if not os.environ.get("SHELL", "").endswith("zsh") and os.environ.get("ZSH_GUARD_FORCE") != "1":
    sys.exit(0)

START = r"(?:^|[;&|(\n]|\bdo\b|\bthen\b|\belse\b)\s*"
TRAPS = [
    (START + r"(?:for\s+path\b|local\s+path\b|typeset\s+path\b|path=|read(?:\s+-\w+)*\s+path\b)",
     "zsh ties the variable `path` to PATH, so using it as a loop or scratch variable breaks every command after it. Rename it (p, pg, file)."),
    (r"\bset\s+--\s+\$\{?[A-Za-z_]",
     "zsh does not word-split an unquoted $VAR, so `set -- $var` sets one argument. List the words literally, use an array, write ${=var}, or run it under bash -c."),
    (r"\bfor\s+\w+\s+in\s+\$\{?[A-Za-z_]\w*\}?\s*(?:;|\n|$|do\b)",
     "zsh does not word-split an unquoted $VAR, so `for x in $list` runs once with the whole string. List the words literally, use an array, write ${=list}, or run it under bash -c."),
    (r"(?:^|\s)https?://[^\s'\"]*[?*\[]",
     "zsh treats ? * [ in an unquoted URL as a glob and stops with 'no matches found'. Quote the URL."),
    (r"--(?:include|exclude)(?:-dir)?=[^\s'\"]*\*|\s-i?name\s+[^\s'\"]*\*",
     "zsh expands an unquoted pattern itself, or stops with 'no matches found'. Quote it: --include='*.js', -name '*.png'."),
]
# zsh expands a word that starts with = into a command's path: `echo ======` and `[ "$a" == b ]` stop with
# "not found" (2 slips on 2026-10-30). Inside [[ ]] == is a comparison, so those are left out.
if re.search(r"(?:^|[\s;&|(])=\S", re.sub(r"\[\[.*?\]\]", "", bare)):
    TRAPS.append((r"", "zsh expands a word that starts with = into a command path, so `echo ======` or `[ $a == b ]` stops with 'not found'. "
                       "Quote it ('======'), compare with a single = inside [ ], or use [[ ]]."))
for pattern, why in TRAPS:
    if re.search(pattern, bare):
        sys.stderr.write("zsh-guard: " + why + " The Bash tool runs zsh here; fix the command and run it again.\n")
        sys.exit(2)
sys.exit(0)
PY
