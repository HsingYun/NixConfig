"""Check source dependencies, without replacing Nix option/module evaluation."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
errors = []
references = re.compile(r"(?<![\w/])((?:\.\.?/)[A-Za-z0-9_./-]+)")
for source in root.rglob("*.nix"):
    relative = source.relative_to(root)
    for number, line in enumerate(source.read_text().splitlines(), 1):
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
# Role consumers may implement desktop policy, but cannot reselect concrete apps.
role_consumer = (root / "modules/home/integrations/applications.nix").read_text()
if re.search(r"\b(?:software|features)\b", role_consumer):
    errors.append("home/integrations/applications.nix: consume selected roles, not feature/package selection")
# Test registration belongs to tests; the output assembler only imports its entry.
for match in references.finditer((root / "lib/outputs.nix").read_text()):
    target = (root / "lib" / match[1]).resolve()
    if (root / "tests") in target.parents and target != root / "tests/default.nix":
        errors.append("lib/outputs.nix: individual checks belong in tests/default.nix")
if errors:
    raise SystemExit("\n".join(errors))
print("Architecture dependency boundaries passed")
