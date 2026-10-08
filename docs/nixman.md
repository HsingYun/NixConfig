# nixman

`nixman` previews configuration updates and manages the generations maintained
by NixOS, nix-darwin and standalone Home Manager. It uses their existing profiles
and activation mechanisms, without a separate generation database.

## Run

Every configured host installs `nixman` through the shared user software profile,
including NixOS, NixOS-WSL, Darwin and Arch. It is a repository-provided Nix
package, even when Homebrew or pacman is the preferred package manager. No
feature toggle or separate user-profile installation is required after applying
a configuration that includes it. The flake app remains available for the
initial update and for use outside these managed hosts.

The repository package is registered under `pkgs.hsingyun.nixconfig.nixman`.
Its package name (`pname`), executable, software identity and public flake output
are all `nixman`. The attribute namespace does not prefix the package name; Nix
store hashes distinguish derivations. Installing another package that provides
`bin/nixman` in the same environment can still cause a file collision.
The overlay preserves unrelated packages and rejects an existing package at
that exact attribute instead of silently replacing it.

```sh
# From a checkout
nix run .#nixman -- --help
nix run .#nixman -- status

# From GitHub
nix run github:HsingYun/NixConfig/master#nixman -- update \
  'github:HsingYun/NixConfig/master#Darwin'

# Optional: install on a machine not managed by this configuration
nix profile add github:HsingYun/NixConfig/master#nixman
```

The flake exports `apps.<system>.nixman` and `packages.<system>.nixman`, also as
the default app and package, for x86_64/aarch64 Linux and aarch64 macOS. Run it as your
normal user. System changes request `sudo`; standalone Home Manager must run as
the user whose home is managed. The app includes Nix and the Home Manager CLI.
NixOS and Darwin use the installed `nixos-rebuild` and `darwin-rebuild` commands.

## Commands

| Command | Behavior |
| --- | --- |
| `nixman status` | Show the backend, active and selected generations, and default update source. |
| `nixman update [FLAKE#HOST]` | Refresh the source, build and preview a candidate, then confirm activation. |
| `nixman generation list` | List upstream generation numbers; mark running and profile-selected configurations separately. |
| `nixman generation info ID` | Show creation time, store path, version and recorded provenance. |
| `nixman generation diff A B` | Compare two existing generations without activating either. |
| `nixman generation switch ID` | Preview and activate an existing generation. |
| `nixman rollback` | Preview and activate the available generation immediately before the running one. |
| `nixman generation gc [N]` | Delete the oldest N eligible generation links, or all eligible links when N is omitted. |
| `nixman gc` | Preview unreachable store paths, then invoke Nix garbage collection. |

`--backend nixos`, `--backend darwin` or `--backend home-manager` before the
command overrides automatic platform detection. NixOS-WSL uses the NixOS
backend; other Linux distributions use standalone Home Manager. System commands
manage the default `/nix/var/nix/profiles/system` profile. Home Manager profile
discovery follows upstream's XDG/per-user profile precedence.

Commands that activate or delete accept `--dry-run` and `--yes` (`-y`). The
default activation prompt is `[Y/n]`; the default deletion prompt is `[y/N]`.
EOF cancels, and noninteractive execution requires explicit `--yes` unless it
is a preview. `update --dry-run` may download and build store objects to produce
an accurate preview, but does not activate the configuration.

## Flake references and updates

Reference parsing is delegated to Nix, including local paths, registry names,
GitHub/GitLab references, Git transports and source archives. For example:

```sh
nixman update './configuration#ArchLinux'
nixman update 'path:/home/me/configuration#host'
nixman update 'git+file:///home/me/configuration?ref=main&dir=machines#host'
nixman update 'git+https://example.com/config.git?ref=main#host'
nixman update 'git+ssh://git@example.com/config?ref=main#host'
nixman update 'gitlab:owner/repository/main#host'
nixman update 'https://example.com/configuration.tar.gz#host'
nixman update 'flake:my-configuration#host'
```

The fragment is the configuration name in `nixosConfigurations`,
`darwinConfigurations` or `homeConfigurations`, according to the backend.
If omitted, nixman selects the sole configuration or a matching local name;
ambiguous selections require `#HOST`.

The source flake must have consistent locked inputs. Nix refreshes the source
reference, while `--no-update-lock-file` preserves its dependency versions.
To update those dependencies, use the repository's lock update workflow
separately. Nix's normal Git tracking rules apply to local Git flakes.

The update transaction:

1. Resolve the source with `--refresh` and retain it in the store.
2. Create a temporary flake around the source's upstream `extendModules` result.
   Preserve the source revision, timestamp and `?dir=` subflake selection.
3. Add a generation provenance record through upstream builder options.
4. Run the Nix build dry run, then build the candidate with a temporary GC root.
5. Display closure, managed-file and declared native-package differences.
6. Ask for confirmation and verify that the active/profile state is unchanged.
7. Invoke the upstream switch command against the same frozen wrapper flake.

"Frozen" applies to one update transaction. If `master` resolves to commit A
before preview and advances to B while you review it, confirming still uses A.
The next update resolves `master` again and can use B. Local sources are also
pinned by their captured content hash; later edits cannot silently replace the
previewed candidate. If that captured source cannot be recovered, the update
fails rather than applying different contents.

The temporary wrapper has its own lock file; your repository's `flake.lock`
is not edited. Nix supplies the immutable source and build outputs. Homebrew
and pacman/AUR still perform their native actions at activation time: freezing
the flake does not freeze their repositories, package versions or machine state.

If configuration payloads and dependencies are unchanged, nixman reports
`No configuration changes detected` and asks whether to continue activation
and generation registration. Nix may reuse an existing generation when its
store path is unchanged. Reapplying may still repair drift or execute native
package-manager actions configured by the target flake.

## Saved source and previews

Each generation created by nixman contains `nixman.json` in its store root.
It records the update reference, configuration name, locked source identity,
backend, managed file sources and native package declarations. Relative local
references are saved using Nix's canonical absolute reference. The next
`nixman update` without an argument reads the running generation's record and
passes the same default source into its successor.

Installing the command alone does not create this provenance record. A first
update through nixman must specify the source. `status` can report that the
profile matches the running configuration while the default update source is
unavailable: these describe configuration identity and recorded provenance,
respectively.

Switching to another recorded generation restores that generation's default
source. Generations created without nixman remain usable, but do not have this
record: specify the source explicitly for the first update. Ordinary rebuilds
outside nixman do not inherit the record automatically. No mutable global file
is used to guess which source belongs to an older generation.

The record is public within the Nix store. Keep credentials in Nix's credential
configuration, not in flake URLs; inline credentials are rejected.

### Example generation record

This illustrative Darwin record uses placeholder hashes and reduced file and
package lists. Actual records contain the full declared lists. `flake` remains
the update source (for example, a branch), while `lockedReference`, `revision`
and `sourceHash` identify the source used for this particular generation.
`revision` can be `null` for a path source without Git revision metadata.

```json
{
  "schema": 1,
  "backend": "darwin",
  "configuration": "Darwin",
  "flake": "github:HsingYun/NixConfig/master#Darwin",
  "lockedReference": "github:HsingYun/NixConfig/<commit>?narHash=sha256-<hash>",
  "revision": "<commit>",
  "sourceHash": "sha256-<hash>",
  "managedFiles": {
    "/etc/nix/nix.conf": "/nix/store/<hash>-nix.conf",
    "/Users/hsingyun/.config/ghostty/config": "/nix/store/<hash>-ghostty-config"
  },
  "native": {
    "homebrew": {
      "brews": ["git", "watch"],
      "casks": ["ghostty", "google-chrome"],
      "taps": [],
      "masApps": {},
      "onActivation": {
        "cleanup": "none",
        "autoUpdate": false,
        "upgrade": false
      }
    },
    "pacman": {}
  }
}
```

`nixman generation info ID` prints this record along with generation details.
On NixOS and Darwin, the running generation exposes it at
`/run/current-system/nixman.json` after activation through nixman. The file is a
symlink to a read-only JSON object in the Nix store. It contains declared source
paths and native package intent, not copies of managed file contents or an
inventory of the live machine.

### Preview boundaries

The preview uses Nix's closure comparison and upstream module declarations.
Recorded generations include embedded Home Manager files as well as system
files; the preview lists paths without printing their contents. Older system
generations without a file manifest can be compared at `/etc`, but their
embedded home-file baseline is reported as unavailable.

Homebrew and pacman/AUR declarations are shown separately. They describe desired
configuration, not a resolved native package transaction or an inventory of
already installed software. Dropping a declaration may retain an installed
package. Native versions, application data and arbitrary activation effects
are not restored by a Nix generation switch. These are configuration generations,
not filesystem snapshots.

## Cleanup and failure behavior

`generation gc N` interprets N as a count, not a generation-number threshold.
The running and profile-selected generations are always excluded, including
the parent generation of a running NixOS specialisation. Both are protected
when a boot-only or failed activation leaves their values different. If the
running configuration cannot be identified, generation deletion is refused.

Generation cleanup delegates explicit, previewed IDs to `nix-env`; it does not
collect store objects. `nixman gc` uses Nix's reachability analysis and garbage
collector, including its handling of stale build remnants. It does not expire
generation links. Changes to the previewed state cause an abort before
execution; Nix remains responsible for liveness checks while collecting.

Candidate builds are temporarily rooted until the transaction finishes. A
declined update leaves no new profile generation, and an unsuccessful activation
does not become the remembered default merely because it was built. Upstream
activation is not a filesystem transaction: an error can occur after some
effects or a profile change. Use `status` and `generation list` to distinguish
the running configuration from the selected profile before retrying.
