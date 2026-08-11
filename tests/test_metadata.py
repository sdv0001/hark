#!/usr/bin/env python3
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def commands(document, event):
    return [item for group in document["hooks"][event] for item in group["hooks"]]


class PluginContracts(unittest.TestCase):
    def test_codex_manifest_uses_default_discovery(self):
        manifest = load(".codex-plugin/plugin.json")
        self.assertEqual("hark", manifest["name"])
        self.assertNotIn("hooks", manifest)
        self.assertIn("interface", manifest)

    def test_claude_manifest_selects_its_hook_file(self):
        self.assertEqual(
            "./hooks/claude.json",
            load(".claude-plugin/plugin.json")["hooks"],
        )

    def test_codex_event_roles(self):
        hooks = load("hooks/hooks.json")
        expected = {
            "Stop": "done",
            "PermissionRequest": "attention",
            "SubagentStop": "subagent",
            "SessionEnd": "bye",
        }
        self.assertEqual(set(expected), set(hooks["hooks"]))
        for event, role in expected.items():
            command = commands(hooks, event)[0]
            self.assertIn(f'hark.sh" {role}', command["command"])
            self.assertIn("PLUGIN_ROOT", command["command"])
            self.assertIn(role, command["commandWindows"])
            self.assertNotIn("async", command)

    def test_claude_event_roles_use_documented_fields(self):
        hooks = load("hooks/claude.json")
        expected = {
            "Stop": "done",
            "PermissionRequest": "attention",
            "PostToolUseFailure": "error",
            "StopFailure": "error",
            "SubagentStop": "subagent",
            "SessionEnd": "bye",
        }
        self.assertEqual(set(expected), set(hooks["hooks"]))
        for event, role in expected.items():
            command = commands(hooks, event)[0]
            self.assertIn(f'hark.sh" {role}', command["command"])
            self.assertIn("CLAUDE_PLUGIN_ROOT", command["command"])
            self.assertTrue(command["async"])
            self.assertNotIn("commandWindows", command)

    def test_runtime_has_no_legacy_codex_path(self):
        legacy = ("Get-CodexRole", "codex_role", "install_codex", "notify payload")
        for path in ("scripts/hark.sh", "scripts/hark.ps1"):
            source = (ROOT / path).read_text(encoding="utf-8")
            for marker in legacy:
                self.assertNotIn(marker, source, f"{marker!r} remains in {path}")

    def test_codex_documentation_uses_native_plugin_install(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        guide = (ROOT / "integrations/codex.md").read_text(encoding="utf-8")
        for document in (readme, guide):
            self.assertIn("Codex 0.147", document)
            self.assertIn("codex plugin marketplace add sdv0001/hark", document)
            self.assertIn("codex plugin add hark@hark", document)
            self.assertNotIn("hark.sh install codex", document)
            self.assertNotIn("plugins cannot contribute hooks", document)


if __name__ == "__main__":
    unittest.main()
