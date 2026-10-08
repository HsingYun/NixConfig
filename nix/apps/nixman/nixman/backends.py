"""Platform adapters; activation and generation ownership stay with upstream."""
from dataclasses import dataclass
import os
from pathlib import Path
import platform
import pwd
import socket

from .runtime import Error, executable, run, WRAPPER_OPTIONS
from .profiles import metadata


@dataclass(frozen=True)
class Backend:
    name: str
    collection: str
    output: str
    command: str

    @property
    def system(self):
        return self.name != "home-manager"

    def profile(self):
        state = Path(os.environ.get("NIX_STATE_DIR", "/nix/var/nix"))
        if self.system:
            return Path("/nix/var/nix/profiles/system")
        user = pwd.getpwuid(os.getuid()).pw_name
        local = state_home() / "nix/profiles"
        global_ = state / "profiles/per-user" / user
        # Match Home Manager's precedence, including initial installations.
        if local.is_dir():
            return local / "home-manager"
        if global_.is_dir():
            return global_ / "home-manager"
        raise Error("No Home Manager profile directory exists. Initialize Nix's user profile first.")

    def active(self):
        if self.system:
            return resolved(Path("/run/current-system"))
        current = state_home() / "home-manager/gcroots/current-home"
        if current.exists():
            return resolved(current)
        user = pwd.getpwuid(os.getuid()).pw_name
        legacy = Path(os.environ.get("NIX_STATE_DIR", "/nix/var/nix")) / "gcroots/per-user" / user / "current-home"
        return resolved(legacy)

    def validate_user(self):
        if not self.system and os.geteuid() == 0:
            raise Error("Run Home Manager as the target user, without sudo. Native system steps request sudo themselves.")

    def default_names(self):
        hostname = socket.gethostname()
        short = hostname.split(".")[0]
        if self.name == "darwin" and platform.system() == "Darwin":
            return [run(["scutil", "--get", "LocalHostName"], capture=True).strip()]
        if self.system:
            return [hostname, short]
        user = pwd.getpwuid(os.getuid()).pw_name
        return [f"{user}@{short}", f"{user}@{hostname}", f"{user}@{socket.getfqdn()}", user]

    def update(self, wrapper):
        run([executable(self.command), "switch", "--flake", f"{wrapper}#nixman",
             *WRAPPER_OPTIONS, "--no-update-lock-file"], privileged=self.system)

    def switch(self, profile, generation):
        if self.name == "darwin":
            run([executable(self.command), "switch", "--switch-generation", str(generation.id)],
                privileged=True)
            return
        activate = generation.path / ("bin/switch-to-configuration" if self.system else "activate")
        if not activate.is_file() or not os.access(activate, os.X_OK):
            raise Error(f"Generation has no executable activation entry point: {activate}")
        # These are upstream's documented activation entry points for an
        # already-built generation; never reconstruct units or managed files.
        run([executable("nix-env"), "--profile", profile, "--switch-generation", str(generation.id)],
            privileged=self.system)
        if self.name == "nixos":
            run([activate, "switch"], privileged=True)
        else:
            args = [activate]
            if (generation.path / "gen-version").exists():
                args += ["--driver-version", "1"]
            run(args)


def state_home():
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))


def resolved(path):
    return path.resolve() if path.exists() else None


BACKENDS = {
    "nixos": Backend("nixos", "nixosConfigurations", "config.system.build.toplevel", "nixos-rebuild"),
    "darwin": Backend("darwin", "darwinConfigurations", "system", "darwin-rebuild"),
    "home-manager": Backend("home-manager", "homeConfigurations", "activationPackage", "home-manager"),
}


def generation_backend(path):
    if path is None:
        return None
    record = metadata(path)
    if record is not None:
        if record.get("backend") not in BACKENDS:
            raise Error(f"Unknown backend in generation metadata: {path}")
        return BACKENDS[record["backend"]]
    for name, marker in (("nixos", "nixos-version"), ("darwin", "darwin-version"),
                         ("home-manager", "hm-version")):
        if (path / marker).is_file():
            return BACKENDS[name]
    if (path / "activate").is_file() and (path / "home-files").exists():
        return BACKENDS["home-manager"]
    return None


def detect():
    """Identify existing upstream generations, without guessing from the OS."""
    for path in (resolved(Path("/run/current-system")), BACKENDS["home-manager"].active(),
                 resolved(Path("/nix/var/nix/profiles/system"))):
        backend = generation_backend(path)
        if backend is not None:
            return backend
    raise Error("Cannot identify an existing configuration. Run 'nixman update FLAKE#HOST' first.")
