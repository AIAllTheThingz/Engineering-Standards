from __future__ import annotations

import argparse
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import os
import shutil
import socket
import sys
import tarfile
import tempfile
import time
import unittest
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
VALIDATOR_PATH = ROOT / "scripts" / "bash-project-validation.py"
INSTALLER_PATH = ROOT / "scripts" / "Install-BashProjectToolchain.py"
NORMALIZER_PATH = ROOT / "scripts" / "Normalize-BashFunctionalEvidence.py"
LOCK_PATH = ROOT / "examples" / "bash-project" / "bash-toolchain.lock.json"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_module("bash_project_validation", VALIDATOR_PATH)
installer = load_module("install_bash_project_toolchain", INSTALLER_PATH)
normalizer = load_module("normalize_bash_functional_evidence", NORMALIZER_PATH)


class BashProjectValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="bash-validator-tests-")
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        for path in self.root.rglob("*"):
            try:
                path.chmod(0o700 if path.is_dir() else 0o600)
            except OSError:
                pass
        self.temporary.cleanup()

    def make_project(self, marker: str = "") -> Path:
        project = self.root / "project"
        for directory in ("cmd", "lib", "spec"):
            (project / directory).mkdir(parents=True, exist_ok=True)
        (project / "README.md").write_text("# Fixture\n\nSupported Bash 5.2.\n", encoding="utf-8")
        (project / "AGENTS.md").write_text("# Fixture instructions\n", encoding="utf-8")
        (project / "project-manifest.json").write_text(
            json.dumps(
                {
                    "projectName": "fixture",
                    "projectType": "bash",
                    "applicableStandards": ["agents/AGENTS_Bash.md"],
                    "requiredWorkflows": ["bash"],
                }
            ),
            encoding="utf-8",
        )
        (project / "governance.config.json").write_text("{}\n", encoding="utf-8")
        shutil.copyfile(LOCK_PATH, project / "bash-toolchain.lock.json")
        source_marker = marker if marker in {"SYNTAX_FAIL", "SHELLCHECK_FAIL", "FORMAT_FAIL"} else ""
        source = "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\"\n"
        if source_marker == "SYNTAX_FAIL":
            source += "if\n"
        else:
            source += f"# {source_marker}\n" if source_marker else ""
        (project / "cmd" / "fixture").write_text(source, encoding="utf-8")
        (project / "lib" / "fixture.sh").write_text(
            "#!/usr/bin/env bash\nfixture_value() {\n  printf 'fixture\\n'\n}\n",
            encoding="utf-8",
        )
        spec_marker = marker if marker in {"BATS_FAIL", "BATS_TIMEOUT"} else ""
        (project / "spec" / "fixture.bats").write_text(
            "#!/usr/bin/env bats\n@test \"fixture\" {\n  true\n}\n"
            + (f"# {spec_marker}\n" if spec_marker else ""),
            encoding="utf-8",
        )
        return project

    def make_fake_tools(self) -> dict[str, Path]:
        tools = self.root / "tools"
        tools.mkdir(exist_ok=True)
        scripts = {
            "shellcheck": """#!/usr/bin/env bash
if [[ ${1-} == --version ]]; then printf 'ShellCheck - shell script analysis tool\nversion: 0.11.0\n'; exit 0; fi
seen_rc=false
for argument in "$@"; do [[ $argument == --rcfile=/dev/null ]] && seen_rc=true; done
$seen_rc || exit 91
for argument in "$@"; do [[ -f $argument ]] && grep -q 'SHELLCHECK_FAIL' -- "$argument" && exit 1; done
exit 0
""",
            "shfmt": """#!/usr/bin/env bash
if [[ ${1-} == --version ]]; then printf 'v3.13.1\n'; exit 0; fi
joined=" $* "
[[ $joined == *' -ln bash '* && $joined == *' -i 2 '* && $joined == *' -ci '* && $joined == *' -bn '* && $joined == *' -sr '* ]] || exit 92
for argument in "$@"; do [[ -f $argument ]] && grep -q 'FORMAT_FAIL' -- "$argument" && exit 1; done
exit 0
""",
            "bats": """#!/usr/bin/env bash
if [[ ${1-} == --version ]]; then printf 'Bats 1.13.0\n'; exit 0; fi
printf ran > "$TMPDIR/bats-ran"
for argument in "$@"; do
  if [[ -f $argument ]] && grep -q 'BATS_TIMEOUT' -- "$argument"; then sleep 20; fi
  if [[ -f $argument ]] && grep -q 'BATS_FAIL' -- "$argument"; then printf 'not ok 1 fixture\n'; exit 1; fi
done
printf '1..1\nok 1 fixture\n'
exit 0
""",
        }
        result = {}
        for name, content in scripts.items():
            path = tools / name
            path.write_text(content, encoding="utf-8")
            path.chmod(0o700)
            result[name] = path
        return result

    def execute(self, marker: str = "", *, test_timeout: int = 10) -> tuple[int, Path]:
        project = self.make_project(marker)
        tools = self.make_fake_tools()
        evidence = self.root / "evidence"
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"),
            shellcheck=tools["shellcheck"],
            shfmt=tools["shfmt"],
            bats=tools["bats"],
            caller_root=project,
            project=project,
            project_path_input=".",
            work_root=self.root / "work",
            evidence_root=evidence,
            tool_lock=LOCK_PATH,
            command_timeout_seconds=10,
            test_timeout_seconds=test_timeout,
        )
        return validator.execute(args), evidence

    def test_clean_project_passes_every_functional_phase(self) -> None:
        code, evidence = self.execute()
        self.assertEqual(0, code)
        for name in ("bash-syntax.json", "bash-shellcheck.json", "bash-formatting.json", "bash-tests.json"):
            self.assertEqual("Passed", json.loads((evidence / name).read_text(encoding="utf-8"))["status"])
        syntax = json.loads((evidence / "bash-syntax.json").read_text(encoding="utf-8"))
        self.assertEqual(["cmd/fixture", "lib/fixture.sh"], syntax["details"]["files"])
        serial = json.loads((evidence / "bash-project-sbom.cdx.json").read_text(encoding="utf-8"))["serialNumber"]
        self.assertRegex(serial, r"^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        self.assertEqual(serial.removeprefix("urn:uuid:"), str(UUID(serial.removeprefix("urn:uuid:"))))

    def test_ignored_directories_cannot_hide_undeclared_bash_content(self) -> None:
        project = self.make_project()
        for directory in ("evidence", "generated", "output"):
            with self.subTest(directory=directory):
                hidden = project / directory / "hook.sh"
                hidden.parent.mkdir(exist_ok=True)
                hidden.write_text("#!/usr/bin/env bash\ntrue\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "outside declared"):
                    validator.reject_undeclared_bash_content(project)
                hidden.unlink()

    def test_caller_tool_configuration_is_rejected_before_copy(self) -> None:
        project = self.make_project()
        for name in (".batsrc", ".shellcheckrc"):
            with self.subTest(name=name):
                config = project / name
                config.write_text("caller-controlled configuration\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "prohibited caller tool configuration"):
                    validator.inspect_project_tree(project)
                config.unlink()

    def test_syntax_shellcheck_formatting_and_bats_failures_propagate(self) -> None:
        expectations = {
            "SYNTAX_FAIL": "bash-syntax.json",
            "SHELLCHECK_FAIL": "bash-shellcheck.json",
            "FORMAT_FAIL": "bash-formatting.json",
            "BATS_FAIL": "bash-tests.json",
        }
        for index, (marker, evidence_name) in enumerate(expectations.items()):
            with self.subTest(marker=marker):
                if index:
                    self.tearDown()
                    self.setUp()
                code, evidence = self.execute(marker)
                self.assertEqual(1, code)
                self.assertEqual("Failed", json.loads((evidence / evidence_name).read_text(encoding="utf-8"))["status"])
                if marker == "BATS_FAIL":
                    self.assertTrue((self.root / "work" / "tmp" / "bats-ran").exists())
                else:
                    tests = json.loads((evidence / "bash-tests.json").read_text(encoding="utf-8"))
                    self.assertEqual("NotRun", tests["status"])
                    self.assertIsNone(tests["exitCode"])
                    self.assertGreaterEqual(len(tests["failureReason"]), 10)
                    self.assertEqual(tests["failureReason"], tests["notRunReason"])
                    self.assertFalse((self.root / "work" / "tmp" / "bats-ran").exists())

    def test_bats_timeout_is_failed_and_bounded(self) -> None:
        code, evidence = self.execute("BATS_TIMEOUT", test_timeout=5)
        record = json.loads((evidence / "bash-tests.json").read_text(encoding="utf-8"))
        self.assertEqual(1, code)
        self.assertEqual("Failed", record["status"])
        self.assertTrue(record["details"]["timedOut"])
        self.assertLess(record["durationSeconds"], 10)

    def test_timeout_kills_detached_descendant_before_it_can_write(self) -> None:
        project = self.make_project()
        tools = self.make_fake_tools()
        tools["bats"].write_text(
            "#!/usr/bin/env bash\n"
            "if [[ ${1-} == --version ]]; then printf 'Bats 1.13.0\\n'; exit 0; fi\n"
            "setsid /usr/bin/bash -c 'sleep 8; printf escaped > \"$1\"' sandbox \"$TMPDIR/detached\" >/dev/null 2>&1 &\n"
            "sleep 20\n",
            encoding="utf-8",
        )
        tools["bats"].chmod(0o700)
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=tools["shellcheck"], shfmt=tools["shfmt"], bats=tools["bats"],
            caller_root=project, project=project, project_path_input=".", work_root=self.root / "work",
            evidence_root=self.root / "evidence", tool_lock=LOCK_PATH, command_timeout_seconds=10,
            test_timeout_seconds=5,
        )
        self.assertEqual(1, validator.execute(args))
        time.sleep(4)
        self.assertFalse((self.root / "work" / "tmp" / "detached").exists())

    def test_bats_sandbox_denies_project_and_external_file_mutation(self) -> None:
        project = self.make_project()
        original = (project / "cmd" / "fixture").read_text(encoding="utf-8")
        protected = self.root / "runner-command-file"
        protected.write_text("trusted\n", encoding="utf-8")
        tools = self.make_fake_tools()
        tools["bats"].write_text(
            "#!/usr/bin/env bash\n"
            "if [[ ${1-} == --version ]]; then printf 'Bats 1.13.0\\n'; exit 0; fi\n"
            "spec=${@: -1}\nproject=${spec%/spec/*}\n"
            "chmod 700 \"$project/cmd/fixture\"\n"
            "printf hostile >> \"$project/cmd/fixture\" 2>/dev/null || true\n"
            f"printf poisoned >> '{protected}' 2>/dev/null || true\n"
            "printf '1..1\\nok 1 sandbox\\n'\n",
            encoding="utf-8",
        )
        tools["bats"].chmod(0o700)
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=tools["shellcheck"], shfmt=tools["shfmt"], bats=tools["bats"],
            caller_root=project, project=project, project_path_input=".", work_root=self.root / "work",
            evidence_root=self.root / "evidence", tool_lock=LOCK_PATH, command_timeout_seconds=10,
            test_timeout_seconds=10,
        )
        self.assertEqual(0, validator.execute(args))
        self.assertEqual("trusted\n", protected.read_text(encoding="utf-8"))
        self.assertEqual(original, (self.root / "work" / "caller" / "cmd" / "fixture").read_text(encoding="utf-8"))

    def test_caller_cannot_precreate_or_tamper_with_reserved_evidence(self) -> None:
        project = self.make_project()
        tools = self.make_fake_tools()
        evidence = self.root / "evidence"
        tools["bats"].write_text(
            "#!/usr/bin/env bash\n"
            "if [[ ${1-} == --version ]]; then printf 'Bats 1.13.0\\n'; exit 0; fi\n"
            f"mkdir -p '{evidence}'\n"
            f"printf '{{}}\\n' > '{evidence}/attacker.json'\n"
            "printf '1..1\\nok 1 fixture\\n'\n",
            encoding="utf-8",
        )
        tools["bats"].chmod(0o700)
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=tools["shellcheck"], shfmt=tools["shfmt"], bats=tools["bats"],
            caller_root=project,
            project=project, project_path_input=".", work_root=self.root / "work", evidence_root=evidence,
            tool_lock=LOCK_PATH, command_timeout_seconds=10, test_timeout_seconds=10,
        )
        self.assertEqual(0, self._run_main(args))
        self.assertFalse((evidence / "attacker.json").exists())
        self.assertEqual("Passed", json.loads((evidence / "bash-tests.json").read_text(encoding="utf-8"))["status"])

    @staticmethod
    def _run_main(args: argparse.Namespace) -> int:
        try:
            return validator.execute(args)
        except Exception as exc:
            validator.write_failure_evidence(args, exc)
            return 1

    def test_environment_injection_and_path_shadowing_do_not_execute(self) -> None:
        project = self.make_project()
        sentinel = self.root / "sentinel"
        injection = self.root / "injection.sh"
        injection.write_text(f"printf injected >{sentinel}\n", encoding="utf-8")
        shadow = project / "cmd" / "shellcheck"
        shadow.write_text(f"#!/usr/bin/env bash\nprintf shadowed >{sentinel}\n", encoding="utf-8")
        shadow.chmod(0o700)
        old = {name: os.environ.get(name) for name in ("BASH_ENV", "ENV", "BATS_LIB_PATH", "SHELLCHECK_OPTS")}
        try:
            os.environ.update(
                {
                    "BASH_ENV": str(injection),
                    "ENV": str(injection),
                    "BATS_LIB_PATH": str(project),
                    "SHELLCHECK_OPTS": "--exclude=all",
                }
            )
            tools = self.make_fake_tools()
            args = argparse.Namespace(
                bash=Path("/usr/bin/bash"),
                shellcheck=tools["shellcheck"],
                shfmt=tools["shfmt"],
                bats=tools["bats"],
                caller_root=project,
                project=project,
                project_path_input=".",
                work_root=self.root / "work",
                evidence_root=self.root / "evidence",
                tool_lock=LOCK_PATH,
                command_timeout_seconds=10,
                test_timeout_seconds=10,
            )
            self.assertEqual(0, validator.execute(args))
            self.assertFalse(sentinel.exists())
        finally:
            for name, value in old.items():
                if value is None:
                    os.environ.pop(name, None)
                else:
                    os.environ[name] = value

    def test_caller_shellcheck_and_editorconfig_cannot_weaken_options(self) -> None:
        project = self.make_project()
        (project / ".shellcheckrc").write_text("disable=all\n", encoding="utf-8")
        (project / ".editorconfig").write_text("root=true\n[*]\nindent_size=8\n", encoding="utf-8")
        tools = self.make_fake_tools()
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=tools["shellcheck"], shfmt=tools["shfmt"], bats=tools["bats"],
            caller_root=project,
            project=project, project_path_input=".", work_root=self.root / "work", evidence_root=self.root / "evidence",
            tool_lock=LOCK_PATH, command_timeout_seconds=10, test_timeout_seconds=10,
        )
        self.assertEqual(0, validator.execute(args))

    def test_shellcheck_suppression_directive_is_rejected(self) -> None:
        project = self.make_project()
        with (project / "cmd" / "fixture").open("a", encoding="utf-8") as stream:
            stream.write("# shellcheck disable=SC2086\n")
        tools = self.make_fake_tools()
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=tools["shellcheck"], shfmt=tools["shfmt"], bats=tools["bats"],
            caller_root=project,
            project=project, project_path_input=".", work_root=self.root / "work", evidence_root=self.root / "evidence",
            tool_lock=LOCK_PATH, command_timeout_seconds=10, test_timeout_seconds=10,
        )
        self.assertEqual(1, validator.execute(args))
        record = json.loads((self.root / "evidence" / "bash-shellcheck.json").read_text(encoding="utf-8"))
        self.assertIn("directive", record["failureReason"].lower())

    def test_rooted_traversal_and_overlapping_paths_are_rejected(self) -> None:
        for value in ("/absolute", "../escape", "nested/../../escape", "C:\\absolute"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validator.validate_relative_project_path(value)
        project = self.make_project()
        with self.assertRaisesRegex(ValueError, "overlap"):
            validator.ensure_distinct_roots(project, project / "work", self.root / "evidence")

    def test_failure_evidence_never_replaces_a_preexisting_or_overlapping_path(self) -> None:
        project = self.make_project()
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=self.root / "shellcheck", shfmt=self.root / "shfmt",
            bats=self.root / "bats", caller_root=project, project=project, project_path_input=".",
            work_root=self.root / "work", evidence_root=project, tool_lock=LOCK_PATH,
            command_timeout_seconds=10, test_timeout_seconds=10,
        )
        with self.assertRaisesRegex(ValueError, "overlapping"):
            validator.write_failure_evidence(args, ValueError("overlap"))
        self.assertTrue((project / "README.md").is_file())
        args.evidence_root = project / "new-evidence"
        with self.assertRaisesRegex(ValueError, "overlapping"):
            validator.write_failure_evidence(args, ValueError("overlap"))
        self.assertFalse((project / "new-evidence").exists())

    def test_missing_project_path_still_produces_complete_failure_evidence(self) -> None:
        caller = self.make_project()
        evidence = self.root / "evidence"
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=self.root / "shellcheck", shfmt=self.root / "shfmt",
            bats=self.root / "bats", caller_root=caller, project=caller / "missing", project_path_input="missing",
            work_root=self.root / "work", evidence_root=evidence, tool_lock=LOCK_PATH,
            command_timeout_seconds=10, test_timeout_seconds=10,
        )
        validator.write_failure_evidence(args, FileNotFoundError("project path is missing"))
        for name in (*validator.PHASE_FILES.values(), "bash-validation.json", "local-test-results.json"):
            self.assertTrue((evidence / name).is_file(), name)
        structure = json.loads((evidence / "bash-validation.json").read_text(encoding="utf-8"))
        self.assertEqual("Blocked", structure["status"])

    def test_failure_evidence_uses_a_valid_minimal_cyclonedx_sbom(self) -> None:
        project = self.make_project()
        evidence = self.root / "evidence"
        args = argparse.Namespace(
            bash=Path("/usr/bin/bash"), shellcheck=self.root / "shellcheck", shfmt=self.root / "shfmt",
            bats=self.root / "bats", caller_root=project, project=project, project_path_input=".",
            work_root=self.root / "work", evidence_root=evidence, tool_lock=LOCK_PATH,
            command_timeout_seconds=10, test_timeout_seconds=10,
        )
        validator.write_failure_evidence(args, ValueError("controlled early failure"))
        sbom = json.loads((evidence / "bash-project-sbom.cdx.json").read_text(encoding="utf-8"))
        self.assertEqual("CycloneDX", sbom["bomFormat"])
        self.assertEqual("1.5", sbom["specVersion"])
        serial = sbom["serialNumber"]
        self.assertRegex(serial, r"^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        self.assertEqual(str(UUID(serial.removeprefix("urn:uuid:"))), serial.removeprefix("urn:uuid:"))
        self.assertEqual([], sbom["components"])
        properties = {item["name"]: item["value"] for item in sbom["metadata"]["component"]["properties"]}
        self.assertEqual("NotRun", properties["engineering-standards:status"])

    def test_symlink_hardlink_fifo_and_socket_entries_are_rejected(self) -> None:
        creators = {
            "symlink": lambda project: (project / "unsafe").symlink_to(self.root / "outside"),
            "hardlink": lambda project: os.link(project / "README.md", project / "unsafe"),
            "fifo": lambda project: os.mkfifo(project / "unsafe"),
            "socket": self._create_socket,
        }
        for index, (name, creator) in enumerate(creators.items()):
            with self.subTest(name=name):
                if index:
                    self.tearDown()
                    self.setUp()
                project = self.make_project()
                (self.root / "outside").write_text("outside", encoding="utf-8")
                created = creator(project)
                try:
                    with self.assertRaises(ValueError):
                        validator.inspect_project_tree(project)
                finally:
                    if isinstance(created, socket.socket):
                        created.close()

    def test_symlinked_project_root_is_rejected(self) -> None:
        project = self.make_project()
        linked_root = self.root / "linked-project"
        linked_root.symlink_to(project, target_is_directory=True)
        with self.assertRaises(ValueError):
            validator.inspect_project_tree(linked_root)

    def test_intermediate_project_path_symlink_cannot_escape_caller_root(self) -> None:
        project = self.make_project()
        caller = self.root / "caller"
        caller.mkdir()
        bridge = caller / "bridge"
        bridge.symlink_to(project, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symbolic-link"):
            validator.resolve_caller_project(caller, bridge, "bridge")

    def test_bash_executable_content_outside_declared_paths_is_rejected(self) -> None:
        project = self.make_project()
        fixtures = project / "fixtures"
        fixtures.mkdir()
        (fixtures / "ungated.sh").write_text("#!/usr/bin/env bash\nprintf unsafe\\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "outside declared"):
            validator.validate_structure(project)

    def _create_socket(self, project: Path) -> socket.socket:
        value = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        value.bind(str(project / "unsafe"))
        return value


class BashEvidenceNormalizerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="bash-normalizer-tests-")
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def bootstrap_record(self, status: str) -> dict[str, object]:
        return {
            "schemaVersion": "1.1.0",
            "name": "Bash functional toolchain bootstrap",
            "category": "dependency",
            "status": status,
            "requiredValidation": True,
            "evidenceSource": "Automated",
            "command": "python3 -I scripts/Install-BashProjectToolchain.py --lock <lock>",
            "workingDirectory": ".",
            "startedAtUtc": "2026-07-22T00:00:00Z",
            "completedAtUtc": "2026-07-22T00:00:01Z",
            "durationSeconds": 1,
            "runtime": "CPython 3.12.11",
            "toolName": "bash-toolchain-bootstrap",
            "toolVersion": "1.0.0",
            "exitCode": None if status == "Blocked" else 1,
            "summary": f"Bootstrap {status.lower()}.",
            "warnings": [],
            "failureReason": "Synthetic failed bootstrap reason." if status == "Failed" else None,
            "blockedReason": "Synthetic blocked bootstrap reason." if status == "Blocked" else None,
            "details": {"sanitizedOutput": "Synthetic bootstrap output."},
        }

    def write_bootstrap(self, record: dict[str, object]) -> Path:
        path = self.root / normalizer.BOOTSTRAP_FILE
        path.write_text(json.dumps(record), encoding="utf-8")
        return path

    def test_normalizes_canonical_blocked_and_failed_bootstrap_only_evidence(self) -> None:
        for status in ("Blocked", "Failed"):
            with self.subTest(status=status):
                path = self.write_bootstrap(self.bootstrap_record(status))
                normalizer.normalize_evidence(self.root)
                record = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(status, record["status"])
                self.assertEqual("bash-toolchain-bootstrap", record["details"]["toolName"])
                self.assertEqual("bash-toolchain-bootstrap/1.0.0", record["toolVersion"])

    def test_rejects_nonfailure_or_contradictory_bootstrap_only_evidence(self) -> None:
        cases = []
        passed = self.bootstrap_record("Passed")
        passed["exitCode"] = 0
        cases.append(("Passed", passed))
        blocked = self.bootstrap_record("Blocked")
        blocked["blockedReason"] = "short"
        cases.append(("blocked reason", blocked))
        failed = self.bootstrap_record("Failed")
        failed["exitCode"] = None
        cases.append(("failed fields", failed))
        for name, record in cases:
            with self.subTest(case=name):
                self.write_bootstrap(record)
                with self.assertRaises(ValueError):
                    normalizer.normalize_evidence(self.root)

    def test_full_evidence_requires_bootstrap_record(self) -> None:
        for name in normalizer.REQUIRED_FILES - {normalizer.BOOTSTRAP_FILE}:
            (self.root / name).write_text("{}\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, normalizer.BOOTSTRAP_FILE):
            normalizer.normalize_evidence(self.root)


class BashInstallerSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="bash-installer-tests-")
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_archive(self, members: list[tuple[str, bytes, int]]) -> Path:
        path = self.root / "fixture.tar.gz"
        with tarfile.open(path, "w:gz") as archive:
            for name, content, kind in members:
                info = tarfile.TarInfo(name)
                info.type = kind
                info.size = len(content) if kind == tarfile.REGTYPE else 0
                archive.addfile(info, io.BytesIO(content) if info.size else None)
        return path

    def test_archive_traversal_symlink_duplicate_and_case_collision_are_rejected(self) -> None:
        cases = {
            "absolute": [("/package/escape", b"x", tarfile.REGTYPE)],
            "backslash": [("package\\escape", b"x", tarfile.REGTYPE)],
            "traversal": [("package/../escape", b"x", tarfile.REGTYPE)],
            "symlink": [("package/link", b"", tarfile.SYMTYPE)],
            "hardlink": [("package/link", b"", tarfile.LNKTYPE)],
            "character-device": [("package/device", b"", tarfile.CHRTYPE)],
            "block-device": [("package/device", b"", tarfile.BLKTYPE)],
            "fifo": [("package/fifo", b"", tarfile.FIFOTYPE)],
            "duplicate": [("package/a", b"a", tarfile.REGTYPE), ("package/a", b"b", tarfile.REGTYPE)],
            "case-collision": [("package/A", b"a", tarfile.REGTYPE), ("package/a", b"b", tarfile.REGTYPE)],
        }
        for name, members in cases.items():
            with self.subTest(name=name):
                path = self.write_archive(members)
                with self.assertRaises(ValueError):
                    installer.inspect_archive(path, "package")
                path.unlink()

    def test_missing_offline_artifact_is_blocked_and_tampered_artifact_fails(self) -> None:
        lock = self.root / "lock.json"
        shutil.copyfile(LOCK_PATH, lock)
        cache = self.root / "cache"
        cache.mkdir()
        args = argparse.Namespace(
            lock=lock,
            cache=cache,
            tool_root=self.root / "tools-missing",
            evidence=self.root / "missing.json",
            paths_output=self.root / "missing-paths.json",
            offline=True,
        )
        with self.assertRaises(installer.BlockedError):
            installer.install(args)
        first_artifact = json.loads(lock.read_text(encoding="utf-8"))["tools"][0]["artifactFile"]
        (cache / first_artifact).write_bytes(b"tampered")
        args.tool_root = self.root / "tools-tampered"
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            installer.install(args)

    def test_tool_version_mismatch_fails(self) -> None:
        with self.assertRaisesRegex(ValueError, "version"):
            installer.verify_version("shfmt", "3.13.1", "v0.0.0")

    def test_installer_cli_preserves_blocked_and_failed_evidence_semantics(self) -> None:
        lock = self.root / "lock.json"
        shutil.copyfile(LOCK_PATH, lock)
        cache = self.root / "cache"
        cache.mkdir()

        def run(suffix: str) -> tuple[int, Path]:
            evidence = self.root / f"{suffix}.json"
            original_argv = sys.argv
            try:
                sys.argv = [
                    str(INSTALLER_PATH), "--lock", str(lock), "--cache", str(cache),
                    "--tool-root", str(self.root / f"tools-{suffix}"), "--evidence", str(evidence),
                    "--paths-output", str(self.root / f"paths-{suffix}.json"), "--offline",
                ]
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    exit_code = installer.main()
            finally:
                sys.argv = original_argv
            return exit_code, evidence

        blocked, blocked_evidence = run("blocked")
        self.assertEqual(2, blocked)
        self.assertEqual("Blocked", json.loads(blocked_evidence.read_text(encoding="utf-8"))["status"])

        first_artifact = json.loads(lock.read_text(encoding="utf-8"))["tools"][0]["artifactFile"]
        (cache / first_artifact).write_bytes(b"tampered")
        failed, failed_evidence = run("failed")
        self.assertEqual(1, failed)
        self.assertEqual("Failed", json.loads(failed_evidence.read_text(encoding="utf-8"))["status"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
