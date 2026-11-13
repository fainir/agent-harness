"""Plan and apply the Agent Harness installation."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import tempfile


REPO = Path(__file__).resolve().parents[1]
TOOLS = {
    "claude": ("CLAUDE.md", "settings.json"),
    "codex": ("AGENTS.md", "hooks.json"),
}
LEGACY_SKILLS = (
    "ship production-ready product-spec ux-ui-review qa-flows release-gates "
    "owner-actions run-company portfolio hire learn workspace"
).split()
START = "<!-- agent-harness:start -->"
END = "<!-- agent-harness:end -->"
STOP_CAP = "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP"


def arguments():
    parser = argparse.ArgumentParser(
        prog="install.sh", description="Install or remove Agent Harness.", allow_abbrev=False,
    )
    parser.add_argument("install", nargs="?", choices=("install",), help=argparse.SUPPRESS)
    parser.add_argument("--uninstall", action="store_true", help="Remove this installation.")
    parser.add_argument("--dry-run", action="store_true", help="Show the install plan without writing files.")
    parser.add_argument("--tool", choices=TOOLS, help="Install for one tool instead of detecting both.")
    parser.add_argument("--replace-links", action="store_true", help="Replace conflicting symlinks and save their targets for uninstall.")
    args = parser.parse_args()
    if args.uninstall and (args.install or args.dry_run or args.tool or args.replace_links):
        parser.error("--uninstall must be used on its own")
    return parser, args


def target(link):
    return os.readlink(link) if link.is_symlink() else None


def backup_dir(link):
    return link.with_name(link.name + ".bak-agent-harness")


def saved_link(link, source):
    backup = backup_dir(link)
    if backup.is_symlink() or not backup.is_dir():
        return None
    original = backup / "original"
    if original.is_symlink() and target(backup / "installed") == str(source):
        return original
    return None


def replace_link(link, original, source):
    backup = backup_dir(link)
    backup.mkdir(mode=0o700)
    saved = backup / "original"
    installed = backup / "installed"
    replacement = backup / "replacement"
    try:
        saved.symlink_to(original)
        installed.symlink_to(source)
        replacement.symlink_to(source)
        os.replace(replacement, link)
    except OSError:
        for item in (replacement, installed, saved):
            if item.is_symlink():
                item.unlink()
        backup.rmdir()
        raise


def restore_link(link, original):
    os.replace(original, link)
    (original.parent / "installed").unlink()
    if not any(original.parent.iterdir()):
        original.parent.rmdir()


def write_file(path, contents):
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, name = tempfile.mkstemp(prefix=".agent-harness-", dir=path.parent)
    tmp = Path(name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as file:
            file.write(contents)
        tmp.chmod(mode)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def rules_contents(old, adding):
    left = old.find(START)
    right = old.find(END, left + len(START))
    managed = left >= 0 and right >= 0
    newline = "\r\n" if "\r\n" in old else "\n"
    block = ""
    if adding:
        contents = (REPO / "rules/harness.md").read_text().rstrip().replace("\n", newline)
        block = f"{START}{newline}{contents}{newline}{END}"
    if managed:
        right += len(END)
        if not adding and old[right:].startswith(newline):
            right += len(newline)
        return old[:left] + block + old[right:]
    if not adding:
        return old
    separator = "" if not old or old.endswith(newline) else newline
    return old + separator + block + newline


def read_text(path):
    with path.open(encoding="utf-8", newline="") as file:
        return file.read()


def hook_commands(tool, hooks, quote):
    def command(name):
        return quote(str(hooks / name))

    commands = {
        "UserPromptSubmit": [f"bash {command('reply-budget.sh')}"],
        "Stop": [
            f"python3 -I {command('done-check.py')} --judge {tool}",
            f"bash {command('owner-action-nudge.sh')}",
            f"bash {command('continue-ledger.sh')}",
        ],
    }
    if tool == "claude":
        commands["PostToolUse"] = [f"bash {command('rules-reload.sh')}"]
        commands["PreToolUse"] = [f"bash {command('zsh-guard.sh')}"]
    return commands


def settings_contents(old, tool, hooks, old_hook_dirs, adding, owns_cap):
    data = json.loads(old) if old else {}
    added_cap = tool == "claude" and adding and STOP_CAP not in data.get("env", {})
    old_commands = {
        command
        for directory in old_hook_dirs
        for quote in (shlex.quote, lambda value: f'"{value}"')
        for commands in hook_commands(tool, directory, quote).values()
        for command in commands
    }
    events = data.get("hooks", {})
    removed = False
    for event, groups in list(events.items()):
        keep_groups = []
        for group in groups:
            before = group.get("hooks", [])
            after = [entry for entry in before if entry.get("command") not in old_commands]
            if after != before:
                removed = True
                if after:
                    keep_groups.append({**group, "hooks": after})
            else:
                keep_groups.append(group)
        if keep_groups:
            events[event] = keep_groups
        else:
            del events[event]
    if adding:
        for event, commands in hook_commands(tool, hooks, shlex.quote).items():
            group = {"hooks": [
                {"type": "command", "command": cmd, "timeout": 150 if "done-check" in cmd else 10}
                for cmd in commands
            ]}
            if event == "PreToolUse":
                group["matcher"] = "Bash"
            events.setdefault(event, []).append(group)
    if events:
        data["hooks"] = events
    else:
        data.pop("hooks", None)
    if added_cap:
        data.setdefault("env", {})[STOP_CAP] = "2"
    elif not adding and owns_cap and data.get("env", {}).get(STOP_CAP) == "2":
        del data["env"][STOP_CAP]
        if not data["env"]:
            del data["env"]
        removed = True
    if not adding and not removed:
        return old, False
    return json.dumps(data, indent=2) + "\n", added_cap


class Plan:
    def __init__(self, replace):
        self.replace = replace
        self.actions = []
        self.dirs = set()
        self.links = {}

    def add(self, message, action=None, *args):
        self.actions.append((message, action, args))

    def directory(self, path):
        path = path.resolve()
        if path.is_dir() or path in self.dirs:
            return
        if path.is_symlink() or path.exists():
            raise ValueError(f"Expected a directory at {path}")
        self.directory(path.parent)
        self.dirs.add(path)
        self.add(f"Create directory {path}", path.mkdir)

    def link(self, link, source):
        link = link.parent.resolve() / link.name
        if link in self.links:
            if self.links[link] == source:
                return True
            self.add(f"Keep link already planned at {link}")
            return False
        existing = target(link)
        if existing == str(source):
            self.add(f"Keep installed link {link} -> {source}")
            return True
        backup = backup_dir(link)
        if existing is not None and self.replace and not (backup.exists() or backup.is_symlink()):
            self.links[link] = source
            self.add(f"Replace link {link} -> {source} (save current target at {backup / 'original'})",
                     replace_link, link, existing, source)
            return True
        if existing is not None or link.exists() or backup.exists() or backup.is_symlink():
            self.add(f"Keep existing path or saved target at {link}")
            return False
        self.directory(link.parent)
        self.links[link] = source
        self.add(f"Create link {link} -> {source}", link.symlink_to, source)
        return True

    def unlink(self, link, source):
        link = link.parent.resolve() / link.name
        if link in self.links:
            return
        original = saved_link(link, source)
        if target(link) == str(source):
            self.links[link] = source
            if original is not None:
                self.add(f"Restore link {link} -> {target(original)}", restore_link, link, original)
            else:
                self.add(f"Remove installed link {link}", link.unlink)
        elif original is not None and not link.exists() and not link.is_symlink():
            self.links[link] = source
            self.add(f"Restore missing link {link} -> {target(original)}", restore_link, link, original)
        elif original is not None:
            self.add(f"Keep current path {link}; saved target is at {original}")

    def config(self, path, transform, backup=False):
        if path.is_symlink():
            path = path.resolve(strict=True)
        if path.exists() and not path.is_file():
            raise ValueError(f"Expected a configuration file at {path}")
        present = path.is_file()
        old = read_text(path) if present else ""
        new = transform(old)
        if new == old:
            return
        self.directory(path.parent)
        if backup and present:
            copy = path.with_name(path.name + ".bak-harness")
            number = 1
            while copy.exists() or copy.is_symlink():
                copy = path.with_name(f"{path.name}.bak-harness-{number}")
                number += 1
            self.add(f"Write backup {copy}", write_file, copy, old)
        action = "Update" if present else "Create"
        self.add(f"{action} {path}", write_file, path, new)

    def run(self, dry_run):
        for message, action, args in self.actions:
            if action is not None and not dry_run:
                action(*args)
            print(message)


def install_plan(home, args):
    adding = not args.uninstall
    plan = Plan(args.replace_links)
    skills = home / ".agents/skills"
    shared_hooks = home / ".agents/hooks"
    hooks = REPO / "hooks"
    old_hook_dirs = [hooks]
    if target(shared_hooks) == str(hooks) and saved_link(shared_hooks, hooks) is None:
        old_hook_dirs.append(shared_hooks)
    manifest = REPO / "skills/learn/scripts/managed-skills.txt"
    names = manifest.read_text().split() if manifest.is_file() else LEGACY_SKILLS

    if adding:
        plan.add("Shared Agent Harness files")
        plan.directory(home / ".agents/learnings")
        active = {name for name in names if plan.link(skills / name, REPO / "skills" / name)}
        plan.link(shared_hooks, hooks)
    else:
        active = {name for name in names if target(skills / name) == str(REPO / "skills" / name)}

    for tool, (rule_file, config_file) in TOOLS.items():
        folder = home / f".{tool}"
        selected = tool == args.tool if args.tool else folder.is_dir() or shutil.which(tool)
        if adding and not selected:
            continue
        if not adding and not folder.is_dir():
            continue
        config = folder / config_file
        if config.is_symlink():
            config = config.resolve(strict=True)
        cap_marker = config.with_name(config.name + ".agent-harness-stop-cap")
        owns_cap = tool == "claude" and target(cap_marker) == str(REPO / "hooks")
        settings = read_text(config) if config.is_file() else ""
        updated, added_cap = settings_contents(settings, tool, hooks, old_hook_dirs, adding, owns_cap)
        aliases = [folder / "skills" / name for name in names]
        if not adding and updated == settings and not owns_cap and not any(
            (name in active and target(alias) == str(skills / name)) or saved_link(alias, skills / name)
            for name, alias in zip(names, aliases)
        ):
            continue
        plan.add("Claude Code" if tool == "claude" else "Codex")
        for name, alias in zip(names, aliases):
            if alias.parent.resolve() == skills.resolve():
                continue
            if adding and name in active:
                plan.link(alias, skills / name)
            elif not adding and (name in active or saved_link(alias, skills / name)):
                plan.unlink(alias, skills / name)
        plan.config(folder / rule_file, lambda old: rules_contents(old, adding))
        plan.config(config, lambda old: updated, backup=True)
        if added_cap:
            if not (cap_marker.exists() or cap_marker.is_symlink()):
                plan.add(f"Record ownership of {STOP_CAP} at {cap_marker}", cap_marker.symlink_to, REPO / "hooks")
        if not adding and owns_cap:
            plan.add(f"Remove ownership marker {cap_marker}", cap_marker.unlink)

    if not adding:
        plan.add("Shared Agent Harness files")
        for name in names:
            plan.unlink(skills / name, REPO / "skills" / name)
        plan.unlink(shared_hooks, REPO / "hooks")
    return plan


def main():
    parser, args = arguments()
    home = Path.home().absolute()
    try:
        if args.dry_run:
            print("Install preview (no files changed)")
            install_plan(home, args).run(dry_run=True)
            return
        if args.uninstall and not home.is_dir():
            return
        home.mkdir(parents=True, exist_ok=True)
        # The directory descriptor serializes install/uninstall without a persistent lock file.
        lock = os.open(home, os.O_RDONLY)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
            install_plan(home, args).run(dry_run=False)
        finally:
            os.close(lock)
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        parser.exit(1, f"install.sh: {exc}\n")


if __name__ == "__main__":
    main()
