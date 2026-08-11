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


if __name__ == "__main__":
    unittest.main()
