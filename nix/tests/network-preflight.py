"""Check running native network units without touching the system bus."""

import importlib.util
import subprocess
import sys
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("network", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def check(units):
    result = subprocess.CompletedProcess([], 0, stdout="\n".join(
        f"{unit} loaded active running Network service" for unit in units
    ))
    with patch.object(helper.subprocess, "run", return_value=result) as run:
        helper.check("/test/systemctl")
        assert run.call_args.kwargs["check"]
        assert "--state=active,activating,reloading" in run.call_args.args[0]


for unit in ["dhcpcd.service", "dhcpcd@eth0.service", "netctl@wifi.service",
             "netctl-auto@wlan0.service", "netctl-ifplugd@enp1s0.service",
             "systemd-networkd.service", "connman.service"]:
    try:
        check([unit])
    except RuntimeError as error:
        assert unit in str(error)
    else:
        raise AssertionError(f"Missed competing manager: {unit}")
check([])
check(["wpa_supplicant.service", "iwd.service", "systemd-networkd-wait-online.service"])
check(["NetworkManager.service", "dhcpcd@eth0.service"])
with patch.object(helper.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "systemctl")):
    try:
        helper.check()
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError("Failed systemd query allowed activation")
print("Native network preflight passed")
