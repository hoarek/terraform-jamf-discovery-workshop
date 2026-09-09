#!/usr/bin/env python3
"""Verify that every key an onboarder config can send resolves to a root variable.

Three modes, all of which exit non-zero on a mismatch:

  --config <path>   Walk an onboarder config JSON (form fields, radio and checkbox
                    option names, forced_modules) and check each key against
                    variables.tf. This is the pre-commit check.

  --spec <path>     Check every `- key:` in spec.yml against variables.tf. Catches
                    a spec entry that documents a variable nobody declared.

  --tfvars <path>   Check the generated tfvars.auto.tfvars.json. This is the CI
                    check, and it is the one that matters at deploy time: Terraform
                    errors on an undeclared variable in a -var-file, and failing
                    here produces a readable message instead of a wall of
                    "Value for undeclared variable" warnings followed by a
                    confusing apply failure.

With no arguments it runs --config and --spec against this repo's defaults.

Deliberately dependency-free: it runs on a bare GitHub Actions runner with no pip
install step, so no PyYAML and no HCL parser. variables.tf is scanned with a
regex, which is sufficient because the file is machine-formatted by
`terraform fmt` and every declaration is `variable "name" {` at column zero.
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Keys the wizard collects or emits that are deliberately not Terraform variables.
# Keep this list short and justified; it is the escape hatch that lets the check
# stay strict everywhere else.
NON_VARIABLE_KEYS = {
    # Written into tfvars by the onboarder for its own bookkeeping, not consumed
    # by Terraform.
    "unique_id",
    "session_id",
    "config_name",
    # Onboarder appends _filename to every file-upload field to record the
    # original filename. These are metadata, not Terraform variables.
    "device_enrollment_token_content_filename",
    "volume_purchasing_service_token_content_filename",
    "jamf_connect_license_content_filename",
    "google_ldap_keystore_file_content_filename",
    "google_sso_metadata_file_content_filename",
}

VARIABLE_RE = re.compile(r'^variable\s+"([^"]+)"\s*\{', re.MULTILINE)
SPEC_KEY_RE = re.compile(r'^\s*-\s+key:\s*(\S+)\s*$', re.MULTILINE)


def declared_variables(variables_tf: Path) -> set:
    if not variables_tf.is_file():
        sys.exit(f"error: {variables_tf} not found")
    return set(VARIABLE_RE.findall(variables_tf.read_text()))


def config_keys(config_path: Path) -> set:
    """Every variable name an onboarder config can put into tfvars.

    Field names live under sections[].form_elements.fields[].name for text and file
    inputs, and under sections[].form_elements.options[].name for radio and
    checkbox groups, where several options share one name. forced_modules is a
    flat list of include_ flags set to true.
    """
    data = json.loads(config_path.read_text())
    keys = set(data.get("forced_modules", []) or [])

    reserved = {
        "_comment", "terraform_repo", "terraform_repo_branch", "workflow_file",
        "spec_url", "page_template", "conditional_sidebar", "forced_modules",
    }

    for page_name, page in data.items():
        if page_name in reserved or not isinstance(page, dict):
            continue
        for section in page.get("sections", []) or []:
            elements = section.get("form_elements", {}) or {}
            for group in ("fields", "options"):
                for item in elements.get(group, []) or []:
                    name = item.get("name")
                    if name:
                        keys.add(name)

    return keys - NON_VARIABLE_KEYS


def spec_keys(spec_path: Path) -> set:
    return set(SPEC_KEY_RE.findall(spec_path.read_text())) - NON_VARIABLE_KEYS


def tfvars_keys(tfvars_path: Path) -> set:
    data = json.loads(tfvars_path.read_text())
    if not isinstance(data, dict):
        sys.exit(f"error: {tfvars_path} does not contain a JSON object")
    return set(data.keys()) - NON_VARIABLE_KEYS


def check(label: str, keys: set, declared: set) -> bool:
    missing = sorted(keys - declared)
    if missing:
        print(f"FAIL  {label}: {len(missing)} key(s) with no matching root variable")
        for key in missing:
            print(f"        {key}")
        return False
    print(f"ok    {label}: all {len(keys)} key(s) resolve to a root variable")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--variables", type=Path, default=REPO_ROOT / "variables.tf")
    parser.add_argument("--config", type=Path, action="append", default=[])
    parser.add_argument("--spec", type=Path, action="append", default=[])
    parser.add_argument("--tfvars", type=Path, action="append", default=[])
    parser.add_argument("--list-unused", action="store_true",
                        help="also list declared variables no config or spec mentions")
    args = parser.parse_args()

    if not (args.config or args.spec or args.tfvars):
        args.spec = [REPO_ROOT / "spec.yml"]
        default_config = REPO_ROOT.parent / "modular_onboarder" / "configs" / "discovery-workshop.json"
        if default_config.is_file():
            args.config = [default_config]
        else:
            print(f"note  no config checked: {default_config} not found. "
                  f"Pass --config <path> to check one.")

    declared = declared_variables(args.variables)
    print(f"variables.tf declares {len(declared)} variables\n")

    ok = True
    seen = set()

    for path in args.config:
        keys = config_keys(path)
        seen |= keys
        ok &= check(f"config {path.name}", keys, declared)

    for path in args.spec:
        keys = spec_keys(path)
        seen |= keys
        ok &= check(f"spec {path.name}", keys, declared)

    for path in args.tfvars:
        keys = tfvars_keys(path)
        seen |= keys
        ok &= check(f"tfvars {path.name}", keys, declared)

    if args.list_unused:
        unused = sorted(declared - seen)
        if unused:
            print(f"\nnote  {len(unused)} declared variable(s) not mentioned by the "
                  f"checked files (defaults apply):")
            for name in unused:
                print(f"        {name}")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
