#!/usr/bin/env python3
"""Stop hook: the done check, for Claude Code and Codex.

Lets a turn end when its last message shows finished or owner-blocked work (a NEEDS YOU line,
"Goal condition met", "no change", or a short answer with a clean working tree). Otherwise a
low-effort judge (claude haiku or codex) reads the user's last request and the agent's last message
and answers DONE or CONTINUE; CONTINUE becomes the next turn's prompt. One continuation per turn
(stop_hook_active). Any failure lets the turn end: this hook never traps a session.

Usage in a hook config: python3 -I done-check.py --judge claude   (or --judge codex)
Env: DONE_CHECK_MODEL (claude judge model, default haiku), DONE_CHECK_PROFILE (codex profile).
"""
import json
import os
import re
import subprocess
import sys

JUDGE = sys.argv[sys.argv.index("--judge") + 1] if "--judge" in sys.argv[:-1] else "codex"
SKIP = ("# AGENTS.md", "<environment_context>", "<skills_instructions>", "<turn_aborted>", "<permissions",
        "<system-reminder>", "<command-", "<local-command", "Caveat:", "[Request interrupted")


def out(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.exit(0)


def text_of(content):
    if isinstance(content, str):
        return content
    parts = []
    for c in content if isinstance(content, list) else []:
        if not isinstance(c, dict):
            continue
        if c.get("type") == "tool_result":
            return ""  # a tool result, not a person or a reply
        if c.get("type") in ("text", "input_text", "output_text"):
            parts.append(c.get("text", ""))
    return " ".join(parts)


def read_transcript(path):
    """Last real user prompt and last assistant text, from a Codex rollout or a Claude Code transcript."""
    prompt, last = "", ""
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                pl = rec.get("payload") if isinstance(rec.get("payload"), dict) else None
                if rec.get("type") == "response_item" and pl and pl.get("type") == "message":  # Codex
                    role, t = pl.get("role"), text_of(pl.get("content")).strip()
                elif rec.get("type") in ("user", "assistant") and isinstance(rec.get("message"), dict) and not rec.get("isMeta"):
                    role, t = rec["type"], text_of(rec["message"].get("content")).strip()  # Claude Code
                else:
                    continue
                if role == "user" and t and not t.startswith(SKIP):
                    prompt = t
                elif role == "assistant" and t:
                    last = t
    except Exception:
        pass
    return prompt, last


def git_dirty(cwd):
    try:
        r = subprocess.run(["git", "status", "--porcelain"], cwd=cwd, capture_output=True, text=True, timeout=10)
        if r.returncode != 0:
            return "not a git repo"
        lines = [l for l in r.stdout.splitlines() if l.strip()]
        return "\n".join(lines[:15]) if lines else "clean"
    except Exception:
        return "unknown"


def ledger_open_rows(cwd):
    for name in ("READINESS.md", "COMPANY.md", "PORTFOLIO.md"):
        p = os.path.join(cwd, name)
        if os.path.exists(p):
            try:
                rows = [l for l in open(p, encoding="utf-8", errors="ignore") if re.match(r"^\| [A-Z]+\d", l)]
            except Exception:
                return "unknown"
            open_rows = [l for l in rows if not re.search(r"\|\s*(verified|owner|waiting|cut|human)", l)]
            return "%d of %d in %s" % (len(open_rows), len(rows), name)
    return "no ledger"


def ask_judge(text, cwd):
    env = dict(os.environ, DONE_CHECK="1")
    if JUDGE == "claude":
        cmd = ["claude", "-p", text, "--model", os.environ.get("DONE_CHECK_MODEL", "haiku"), "--no-session-persistence"]
        attempts = [env, {k: v for k, v in env.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL")}]
    else:
        prof = os.environ.get("DONE_CHECK_PROFILE") or ("monitor" if os.path.exists(os.path.expanduser("~/.codex/monitor.config.toml")) else "")
        cmd = ["codex", "exec", "--skip-git-repo-check", "-C", cwd] + (["--profile", prof] if prof else []) + [text]
        attempts = [env]
    for e in attempts:  # a session's own token can expire mid-session; the second attempt uses the CLI login
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=120, env=e, cwd=cwd, stdin=subprocess.DEVNULL)
            lines = [l.strip() for l in r.stdout.splitlines() if l.strip()]
            if r.returncode == 0 and lines:
                return lines[-1]
        except Exception:
            continue
    return "DONE"


if os.environ.get("DONE_CHECK"):  # the judge's own process: never recurse
    out({})
try:
    payload = json.load(sys.stdin)
except Exception:
    out({})
if payload.get("stop_hook_active"):
    out({})
cwd = payload.get("cwd") or os.getcwd()
prompt, last_t = read_transcript(payload.get("transcript_path") or "")
last = (payload.get("last_assistant_message") or last_t or "").strip()
low = last.lower()
if "needs you" in low or "goal condition met" in low or low.rstrip(".") in ("no change", "done", ""):
    out({})
dirty = git_dirty(cwd)
if len(prompt.split()) <= 25 and len(last.split()) <= 120 and dirty in ("clean", "not a git repo"):
    out({})  # a short request answered briefly with nothing changed on disk
verdict = ask_judge(
    "You are a done-check judge for a coding agent. Reply with exactly one line: DONE, or CONTINUE: <one sentence "
    "telling the agent what to finish>.\n\nThe user's last request:\n%s\n\nThe agent's final message:\n%s\n\n"
    "Uncommitted files in the working tree:\n%s\n\nLedger rows still open: %s\n\nRules: DONE when the request is "
    "answered, or the work is verifiably finished with evidence, or the only remaining items are explicitly handed "
    "to the owner (a NEEDS YOU line) or to a third party. CONTINUE when work was announced but not done, verification "
    "is missing, a plan or a list of next steps was given instead of doing them, or the message defers work to a later "
    "turn. Do not run tools; judge from the text."
    % (prompt[:1500] or "(unknown)", last[:2000] or "(empty)", dirty, ledger_open_rows(cwd)),
    cwd,
)
if verdict.upper().startswith("CONTINUE"):
    reason = verdict.split(":", 1)[1].strip() if ":" in verdict else "finish the request"
    out({"decision": "block", "reason": reason + " (done check: finish it now with evidence, then report; one NEEDS YOU line only if the owner must act)"})
out({})
