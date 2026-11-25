"""Portable ownership/rejection controls; no app binary or runtime acceptance."""
from pathlib import Path
import runpy
import unittest

API = runpy.run_path(str(Path(__file__).with_name("miniapps-consumer-runtime-closure.py")))


class OriginalEngineOwnershipControls(unittest.TestCase):
    def setUp(self):
        self.original = {
            "application_executable": "Maktabah",
            "allowed_original_framework_modules": ["React", "React_Core", "ExpoModulesCore", "hermes"],
        }

    def test_original_static_and_locked_framework_owner_remain_distinct(self):
        self.assertEqual(API["original_image_owner"]("Maktabah", self.original),
                         "ORIGINAL_SEFARIA_STATIC_LINK_IN_APPLICATION")
        self.assertEqual(API["original_image_owner"]("Frameworks/React_Core.framework/React_Core", self.original),
                         "ORIGINAL_SEFARIA_LOCKED_POD_FRAMEWORK")

    def test_added_runtime_in_sdk_extension_or_nested_framework_is_not_original_owner(self):
        for path in [
            "Frameworks/AnytypeOriginalEditor.framework/AnytypeOriginalEditor",
            "PlugIns/Widget.appex/Frameworks/React.framework/React",
            "Frameworks/Secondary/React.framework/React",
            "Frameworks/React.framework/Frameworks/React.framework/React",
        ]:
            with self.subTest(path=path):
                self.assertIsNone(API["original_image_owner"](path, self.original))

    def test_every_new_hanlin_runtime_family_is_rejected_independently(self):
        for name in API["NEW_ENGINE_NAMES"]:
            with self.subTest(name=name):
                self.assertIsNotNone(API["NEW_ENGINE_NAME"].search("Frameworks/" + name + ".framework/" + name))
                self.assertIsNotNone(API["NEW_ENGINE_SYMBOL"].search("_$s" + name + "Runtime"))
        self.assertIsNotNone(API["NEW_ENGINE_SYMBOL"].search("_ZN2v87Isolate"))
        self.assertIsNone(API["NEW_ENGINE_NAME"].search("Frameworks/ExpoModulesCore.framework/ExpoModulesCore"))

    def test_shared_bridge_picker_and_frozen_existing_ui_are_not_active_engine_names(self):
        for name in ["HanlinMiniAppsBridge", "HanlinMiniAppsPicker", "HanlinChatUI", "HanlinScriptUI"]:
            with self.subTest(name=name):
                self.assertIsNone(API["NEW_ENGINE_SYMBOL"].search("_$s" + name + "Descriptor"))


if __name__ == "__main__":
    unittest.main()
