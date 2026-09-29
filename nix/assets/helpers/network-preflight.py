"""Refuse to start NetworkManager alongside an existing native manager."""

import re
import subprocess
import sys


MANAGER = re.compile(
    r"(?:systemd-networkd|connman|dhcpcd(?:@.+)?|netctl(?:-auto|-ifplugd)?@.+)\.service\Z"
)


def check(command="/usr/bin/systemctl"):
    result = subprocess.run([
        command, "list-units", "--type=service", "--state=active,activating,reloading",
        "--plain", "--no-legend", "--no-pager", "--full",
    ], check=True, text=True, capture_output=True)
    active = {line.split()[0] for line in result.stdout.splitlines() if line.strip()}
    if "NetworkManager.service" in active:
        return
    conflicts = sorted(unit for unit in active if MANAGER.fullmatch(unit))
    if conflicts:
        raise RuntimeError(
            f"Arch desktop uses NetworkManager, but {', '.join(conflicts)} is active. "
            "Migrate the host network configuration before applying the desktop feature; "
            "the current connection was left intact."
        )


if __name__ == "__main__":
    try:
        check()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
