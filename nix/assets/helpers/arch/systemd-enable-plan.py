"""Run the vendor enable operation against a private configuration copy.

Invoked only inside native-systemd's private mount namespace. --root=/ makes
systemctl operate on files, without contacting or reloading the host manager.
"""

import subprocess
import sys

mount, shadow, destination, systemctl, *units = sys.argv[1:]
subprocess.run([mount, "--bind", shadow, destination], check=True)
subprocess.run([systemctl, "--quiet", "--root=/", "enable", "--", *units], check=True)
