"""Check source dependencies, without replacing Nix option/module evaluation."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
errors = []
adapter_directory = root / "modules/home/software/adapters"
registered_adapters = set()
references = re.compile(r"(?<![\w/])((?:\.\.?/)[A-Za-z0-9_./-]+)")
# Home implementations, presets and integrations have explicit directories;
# the home root contains only its entry point, so new files cannot blur them.
for home in (root / "ports").glob("*/home"):
    for source in home.glob("*.nix"):
        if source.name != "default.nix":
            errors.append(f"{source.relative_to(root)}: place home port modules in capabilities, features or integrations")
for source in root.rglob("*.nix"):
    relative = source.relative_to(root)
    for number, line in enumerate(source.read_text().splitlines(), 1):
        if relative.parts[:3] == ("modules", "home", "features") and re.search(
            r"\bsoftware\.[A-Za-z0-9_-]+\.(?:provider|providedCapabilities)\b", line
        ):
            errors.append(f"{relative}:{number}: provider-dependent implementation belongs in a software adapter or port")
        if relative.parts[:3] in {("modules", "home", "features"), ("modules", "home", "shared")} and re.search(
            r"^\s*(?:[A-Za-z0-9_.-]+\.)?(?:package|packageConfigurable)\s*=\s*(?:lib\.mkDefault\s+)?software\.", line
        ):
            errors.append(f"{relative}:{number}: register a software consumer instead of assigning its package separately")
        # Only literal references are inspected; normal Nix evaluation checks
        # computed imports and the supported public option interfaces.
        for match in references.finditer(line.split("#", 1)[0]):
            target = (source.parent / match[1]).resolve()
            try:
                destination = target.relative_to(root)
            except ValueError:
                continue
            if relative.parts[0] in {"modules", "ports"}:
                module = target / "default.nix" if target.is_dir() else target
                if module.parent == adapter_directory:
                    registered_adapters.add(module)
            if relative == Path("lib/features/catalog.nix") and destination.parts[0] == "ports":
                errors.append(f"{relative}:{number}: register platform implementations in the port")
            if relative.parts[0] == "modules" and destination.parts[0] in {"ports", "tests"}:
                errors.append(f"{relative}:{number}: common modules must not depend on {destination.parts[0]}")
            if (relative.parts[:3] == ("assets", "helpers", "common")
                    and destination.parts[:2] == ("assets", "helpers")
                    and len(destination.parts) > 2 and destination.parts[2] != "common"):
                errors.append(f"{relative}:{number}: common helpers must not depend on platform adapters")
            if relative.parts[:2] == ("lib", "software") and (destination.parts[0] in {"modules", "ports", "tests"} or destination.parts[:2] == ("lib", "platforms")):
                errors.append(f"{relative}:{number}: pure software logic must not import implementations")
            if relative.parts[:2] == ("assets", "helpers") and destination.parts[0] == "contracts":
                errors.append(f"{relative}:{number}: helpers are tools, not public contracts")
# An adapter file must be wired into production, not merely imported by a test.
for adapter in sorted(adapter_directory.glob("*.nix")):
    if adapter not in registered_adapters:
        errors.append(f"{adapter.relative_to(root)}: interface adapter has no production import")

# Role-consumer independence is checked by isolated Home Manager evaluation in
# tests/home/application-roles.nix.
# Test registration belongs to tests; the output assembler only imports its entry.
for match in references.finditer((root / "lib/outputs.nix").read_text()):
    target = (root / "lib" / match[1]).resolve()
    if (root / "tests") in target.parents and target != root / "tests/default.nix":
        errors.append("lib/outputs.nix: individual checks belong in tests/default.nix")
if errors:
    raise SystemExit("\n".join(errors))
print("Architecture dependency boundaries passed")
