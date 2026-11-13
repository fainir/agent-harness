"""Exercise the public installer against a disposable home."""
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
import unittest


INSTALL = Path(__file__).resolve().parents[1] / "install.sh"


def snapshot(root):
    return {
        str(path.relative_to(root)): (
            ("link", os.readlink(path)) if path.is_symlink()
            else ("dir", path.stat().st_mode) if path.is_dir()
            else ("file", path.stat().st_mode, path.read_bytes())
        )
        for path in root.rglob("*")
    }


class InstallerTest(unittest.TestCase):
    def setUp(self):
        temp = TemporaryDirectory(prefix="agent-harness-test-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name) / "fake home"

    def invoke(self, *args, code=0):
        result = subprocess.run(
            ["bash", str(INSTALL), *args],
            env={**os.environ, "HOME": str(self.home)},
            capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result

    def symlink(self, path, target):
        link = self.home / path
        link.parent.mkdir(parents=True, exist_ok=True)
        link.symlink_to(target)
        return link

    def test_help_and_invalid_flags_never_write(self):
        for flags, code in [
            (("--help",), 0), (("-h",), 0), (("--wat",), 2),
            (("--dry",), 2), (("install", "oops"), 2),
            (("--tool", "typo"), 2), (("--uninstall", "--dry-run"), 2),
            (("--uninstall", "--replace-links"), 2),
        ]:
            with self.subTest(flags=flags):
                result = self.invoke(*flags, code=code)
                self.assertIn("usage:", result.stdout + result.stderr)
                self.assertFalse(self.home.exists())

    def test_preview_matches_each_tools_install_and_keeps_other_tool_untouched(self):
        for tool, other, config in [
            ("codex", "claude", "hooks.json"),
            ("claude", "codex", "settings.json"),
        ]:
            with self.subTest(tool=tool):
                self.home = self.home.parent / f"fake home {tool}"
                other_file = self.home / f".{other}/user.txt"
                other_file.parent.mkdir(parents=True)
                other_file.write_text("untouched")
                before = snapshot(self.home)
                preview = self.invoke("--dry-run", "--tool", tool).stdout.splitlines()
                self.assertEqual(snapshot(self.home), before)
                self.assertEqual(preview[0], "Install preview (no files changed)")
                self.assertTrue(any(line.endswith(f".{tool}/{config}") for line in preview))
                self.assertFalse(any(f"/.{other}/" in line for line in preview))
                self.assertEqual(preview[1:], self.invoke("--tool", tool).stdout.splitlines())
                self.assertEqual(list(other_file.parent.iterdir()), [other_file])
                self.assertTrue((self.home / f".{tool}/skills/ship").is_symlink())

    def test_preserves_existing_skill_and_hooks_paths(self):
        custom_shared = self.symlink(".agents/skills/ship", "../custom//./ship")
        custom_alias = self.symlink(".claude/skills/learn", "../custom/learn")
        custom_hooks = self.symlink(".agents/hooks", "../custom/hooks")
        regular = self.home / ".codex/skills/learn"
        regular.parent.mkdir(parents=True)
        regular.write_text("user skill")
        self.invoke()
        self.assertFalse((self.home / ".codex/skills/ship").is_symlink())
        settings = json.loads((self.home / ".codex/hooks.json").read_text())
        commands = [entry["command"] for group in settings["hooks"]["Stop"] for entry in group["hooks"]]
        self.assertTrue(any(str(INSTALL.parent / "hooks/done-check.py") in command for command in commands))
        self.invoke("--uninstall")
        self.assertEqual(os.readlink(custom_shared), "../custom//./ship")
        self.assertEqual(os.readlink(custom_alias), "../custom/learn")
        self.assertEqual(os.readlink(custom_hooks), "../custom/hooks")
        self.assertEqual(regular.read_text(), "user skill")

    def test_replace_then_reinstall_and_restore_exact_targets(self):
        original = {
            ".agents/skills/ship": "../custom//./ship",
            ".agents/hooks": "../missing/hooks",
            ".codex/skills/ship": "../../absent/ship",
            ".claude/skills/learn": "/unused//./claude-learn",
        }
        links = {name: self.symlink(name, value) for name, value in original.items()}
        regular = self.home / ".claude/skills/portfolio"
        regular.write_text("keep file even when replacing links")
        before = snapshot(self.home)
        preview = self.invoke("--dry-run", "--replace-links").stdout.splitlines()
        self.assertEqual(snapshot(self.home), before)
        self.assertEqual(sum(line.startswith("Replace link ") for line in preview), 4)
        self.assertEqual(preview[1:], self.invoke("--replace-links").stdout.splitlines())
        installed = snapshot(self.home)
        self.invoke("--replace-links")
        self.assertEqual(snapshot(self.home), installed)
        for name, link in links.items():
            self.assertNotEqual(os.readlink(link), original[name])
        self.invoke("--uninstall")
        for name, link in links.items():
            self.assertEqual(os.readlink(link), original[name])
            self.assertFalse(link.with_name(link.name + ".bak-agent-harness").exists())
        self.assertEqual(regular.read_text(), "keep file even when replacing links")

    def test_uninstall_keeps_user_change_and_restores_missing_replacement(self):
        edited = self.symlink(".agents/skills/ship", "../old-ship")
        missing = self.symlink(".codex/skills/learn", "../old-learn")
        self.invoke("--replace-links")
        edited.unlink()
        edited.symlink_to("../new-ship")
        missing.unlink()
        result = self.invoke("--uninstall")
        self.assertIn("saved target is at", result.stdout)
        self.assertEqual(os.readlink(edited), "../new-ship")
        self.assertEqual(os.readlink(edited.with_name("ship.bak-agent-harness") / "original"), "../old-ship")
        self.assertEqual(os.readlink(missing), "../old-learn")

    def test_uninstall_from_another_checkout_does_not_remove_managed_links(self):
        original = self.symlink(".agents/skills/ship", "/elsewhere/agent-harness/skills/ship")
        alias = self.symlink(".codex/skills/ship", str(original))
        hooks = self.symlink(".agents/hooks", "/elsewhere/agent-harness/hooks")
        before = snapshot(self.home)
        self.invoke("--uninstall")
        self.assertEqual(snapshot(self.home), before)
        self.assertTrue(alias.is_symlink() and hooks.is_symlink())

    def test_uninstall_ignores_unowned_backup_and_hooks(self):
        self.symlink(".agents/skills/ship.bak-agent-harness/original", "../foreign")
        self.symlink(".agents/hooks", "/elsewhere/custom/hooks")
        config = self.home / ".claude/settings.json"
        config.parent.mkdir()
        custom = f'bash "{self.home}/.agents/hooks/reply-budget.sh"'
        config.write_text(json.dumps({"hooks": {"UserPromptSubmit": [{"hooks": [
            {"type": "command", "command": custom},
        ]}]}}))
        before = snapshot(self.home)
        self.invoke("--uninstall")
        self.assertEqual(snapshot(self.home), before)
        self.invoke("--tool", "claude", "--replace-links")
        self.invoke("--tool", "claude", "--replace-links")
        self.invoke("--uninstall")
        commands = json.loads(config.read_text())["hooks"]["UserPromptSubmit"][0]["hooks"]
        self.assertEqual(commands, [{"type": "command", "command": custom}])

    def test_uninstall_removes_only_the_cap_the_installer_set(self):
        config = self.home / ".claude/settings.json"
        config.parent.mkdir(parents=True)
        name = "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP"
        config.write_text(json.dumps({"env": {name: "2"}}))
        self.invoke("--tool", "claude")
        self.invoke("--uninstall")
        self.assertEqual(json.loads(config.read_text())["env"][name], "2")
        config.write_text("{}")
        self.invoke("--tool", "claude")
        self.invoke("--tool", "claude")
        self.assertEqual(json.loads(config.read_text())["env"][name], "2")
        self.invoke("--uninstall")
        self.assertNotIn("env", json.loads(config.read_text()))

    def test_shared_skills_directory_alias_cannot_create_self_links(self):
        alias = self.symlink(".claude/skills", "../.agents/skills")
        for flags in (("--tool", "claude"), ("--tool", "claude", "--replace-links")):
            preview = self.invoke("--dry-run", *flags).stdout.splitlines()[1:]
            self.assertEqual(preview, self.invoke(*flags).stdout.splitlines())
            self.assertTrue((alias / "ship/SKILL.md").is_file())
        self.invoke("--uninstall")
        self.assertEqual(os.readlink(alias), "../.agents/skills")
        self.assertFalse((alias / "ship").is_symlink())

    def test_existing_config_backups_and_rule_bytes_are_preserved(self):
        folder = self.home / ".codex"
        folder.mkdir(parents=True)
        backup = folder / "hooks.json.bak-harness"
        backup.write_text("my earlier backup")
        settings = folder / "hooks.json"
        settings.write_bytes(b"{}\r\n")
        rules = folder / "AGENTS.md"
        original = b"\r\n# User rules\r\n\r\n"
        rules.write_bytes(original)
        self.invoke("--tool", "codex")
        self.assertEqual((folder / "hooks.json.bak-harness-1").read_bytes(), b"{}\r\n")
        self.invoke("--uninstall")
        self.assertEqual(backup.read_text(), "my earlier backup")
        self.assertEqual(rules.read_bytes(), original)

    def test_invalid_config_leaves_links_and_files_untouched(self):
        config = self.home / ".codex/hooks.json"
        config.parent.mkdir(parents=True)
        config.write_text("{broken")
        before = snapshot(self.home)
        for flags in (("--tool", "codex"), ("--dry-run", "--tool", "codex")):
            result = self.invoke(*flags, code=1)
            self.assertIn("install.sh:", result.stderr)
            self.assertEqual(snapshot(self.home), before)

    def test_legacy_install_can_be_updated_and_removed(self):
        shared = self.symlink(".agents/skills/ship", str(INSTALL.parent / "skills/ship"))
        alias = self.symlink(".codex/skills/ship", str(shared))
        hooks = self.symlink(".agents/hooks", str(INSTALL.parent / "hooks"))
        config = self.home / ".codex/hooks.json"
        legacy_command = f'bash "{hooks}/reply-budget.sh"'
        user_command = f'bash "{hooks}/my-own.sh"'
        config.write_text(json.dumps({"hooks": {"UserPromptSubmit": [{"hooks": [
            {"type": "command", "command": cmd} for cmd in (legacy_command, user_command)
        ]}]}}))
        self.invoke("--tool", "codex")
        self.assertEqual(config.read_text().count("reply-budget.sh"), 1)
        self.invoke("--uninstall")
        self.assertTrue(all(not p.is_symlink() for p in (shared, alias, hooks)))
        self.assertNotIn("reply-budget.sh", config.read_text())
        self.assertIn("my-own.sh", config.read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
