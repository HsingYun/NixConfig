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
| `nixman info` | Print the running generation's `nixman.json` as formatted JSON. |
| `nixman update [FLAKE#HOST]` | Refresh the source, build and preview a candidate, then confirm activation. |
| `nixman generation list` | List upstream generation numbers; mark running and profile-selected configurations separately. |
| `nixman generation info ID` | Show creation time, store path, version and recorded provenance. |
| `nixman generation diff A B` | Compare two existing generations without activating either. |
| `nixman generation switch ID` | Preview and activate an existing generation. |
| `nixman rollback` | Preview and activate the available generation immediately before the running one. |
| `nixman generation gc [--oldest N] [--keep N] [--older-than AGE]` | Preview generation-link cleanup; `--oldest` cannot combine with retention policies. |
| `nixman gc` | Preview unreachable store paths, then invoke Nix garbage collection. |
| `nixman completion bash\|zsh\|fish` | Print a packaged shell completion script. |

Updates infer their backend from the selected flake output collection:
`nixosConfigurations`, `darwinConfigurations` or `homeConfigurations`.
Existing-generation commands identify the backend from the current generation's
provenance record or upstream version markers. NixOS-WSL uses the NixOS backend.
System commands manage the default `/nix/var/nix/profiles/system` profile. Home
Manager profile discovery follows upstream's XDG/per-user profile precedence.
Profile validation uses upstream's link layout, independently of manifest or
version files. A missing profile or an empty profile directory is uninitialized
only when no numbered generation entries exist. An initialized profile must be
a symbolic link to one of its own numbered generation links. Generation
inspection, update preview and generation cleanup reject inconsistent layouts. Missing
store targets remain listed as unavailable generations. Validation only reads
the layout; Nix retains ownership of profile creation and generation changes.

Commands that activate or delete accept `--dry-run` and `--yes` (`-y`). The
default activation prompt is `[Y/n]`; the default deletion prompt is `[y/N]`.
EOF cancels, and noninteractive execution requires explicit `--yes` unless it
is a preview. `update --dry-run` may download and build store objects to produce
an accurate preview, but does not activate the configuration.

Human-readable output uses color on interactive terminals when `TERM` is set
and is neither `dumb` nor `unknown`. Headings use cyan, additions and success use
green, removals and errors use red, and changes and warnings use yellow. Text
labels and diff markers remain present when color is disabled.

Set a nonempty `NO_COLOR` value to disable color, for example
`NO_COLOR=1 nixman status`. Redirected output remains uncolored; stdout and stderr
are checked independently. Nixman also removes Nix closure-diff color codes
when its output should be plain. Build and activation logs retain the upstream
tools' formatting. `nixman info`, `--json` reports and completion output are
always plain, including on a terminal.

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
`darwinConfigurations` or `homeConfigurations`. It must identify a unique
configuration across these collections. If omitted, nixman selects the sole
configuration or a unique matching local name; ambiguous selections require
a unique `#HOST`. An explicit source can bootstrap a machine without an existing
generation. When reusing the saved source, a change of backend requires an
explicit source argument.

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

Generation cleanup supports these policies:

```sh
nixman generation gc --oldest 3 --dry-run
nixman generation gc --keep 5 --dry-run
nixman generation gc --older-than 30d --dry-run
nixman generation gc --keep 5 --older-than 30d --dry-run
```

- `--oldest N` selects the oldest N eligible generations, ordered by generation
  number. N is a positive count, not a generation-number threshold.
- `--keep N` retains the newest N generations overall, plus any older active or
  selected generations. N can be zero. The actual retained count can exceed N.
- `--older-than AGE` selects generations created strictly before the preview's
  cutoff. AGE is a positive whole number followed by `h`, `d` or `w`; days are
  24 hours and weeks are seven days. Creation time comes from the upstream
  generation link; generations with unknown creation times are excluded.
- `--keep` and `--older-than` combine by intersection: a generation must be
  outside the retained set and old enough. `--oldest` cannot combine with either.
- Without a policy, all unprotected historical generations are eligible.

The cutoff is fixed before confirmation, so reviewing cannot expand the plan.
The running and profile-selected generations are always excluded, including
the parent generation of a running NixOS specialisation. Both are protected
when a boot-only or failed activation leaves their values different. If the
running configuration cannot be identified, generation deletion is refused.

Generation cleanup delegates explicit, previewed IDs to `nix-env`; it does not
collect store objects. `nixman gc` uses Nix's reachability analysis and garbage
collector, including its handling of stale build remnants. It does not expire
generation links. Changes to the previewed state cause an abort before
execution; Nix remains responsible for liveness checks while collecting.

Store cleanup previews include an estimated size, summing each unique planned
path's `narSize` from `nix path-info --json --json-format 1 --stdin`. The batch query reads Nix
metadata without traversing dependency closures or scanning file contents.
This is a NAR-based estimate, not a measurement of physical disk blocks: hard
links, compression and filesystem overhead affect actual space reclaimed.
Unregistered build remnants and stale lock files may have no size metadata.
The preview explicitly counts paths excluded from the estimate. If no size can
be queried, the estimate is unavailable rather than zero. Nix reports the
collection result after deletion.

Candidate builds are temporarily rooted until the transaction finishes. A
declined update leaves no new profile generation, and an unsuccessful activation
does not become the remembered default merely because it was built. Upstream
activation is not a filesystem transaction: an error can occur after some
effects or a profile change. Use `status` and `generation list` to distinguish
the running configuration from the selected profile before retrying.

## Structured output

`nixman info` prints the running generation's complete `nixman.json`, indented
with two spaces, without headings or a report envelope. It does not require
`--json`. If the record is absent or invalid, it leaves stdout empty, reports
the error on stderr and exits with a nonzero status. It reads the running
generation even when the profile selects a different generation.

These commands emit a single JSON object on stdout:

```sh
nixman status --json
nixman generation list --json
nixman generation info 12 --json
nixman generation gc --keep 5 --dry-run --json
nixman gc --dry-run --json
```

Reports include `schema: 1` and a `command` field. Status distinguishes active
and selected generations and uses `null` for unavailable provenance. Generation
entries contain `id`, `createdAt` (UTC ISO timestamp or `null`), `path`, `active`,
`selected` and `available`. Cleanup reports contain the exact previewed IDs or
store paths; generation cleanup also records the policy and fixed cutoff.
Store cleanup adds `sizeEstimate: { "bytes": N, "basis": "nar", "unmeasuredPaths": M }`.
`bytes` is the total for measured paths, `null` when unavailable, and zero for an
empty plan. `unmeasuredPaths` counts planned paths excluded from that total.
Runtime errors produce an `error.message` JSON object within the report, a
diagnostic on stderr and a nonzero exit status. Argument parsing errors use
normal CLI diagnostics.

Cleanup `--json` requires `--dry-run`, even with `--yes`; structured output does
not approve deletion. Update, switch, rollback and generation diff retain their
interactive text interface.

## Shell completion

The nixman package installs all three completion scripts through Nixpkgs'
`installShellCompletion` helper:

- Bash: `share/bash-completion/completions/nixman.bash`
- Zsh: `share/zsh/site-functions/_nixman`
- Fish: `share/fish/vendor_completions.d/nixman.fish`

Shells with their standard completion system enabled discover these files from
the installed package. Hosts and shell features do not carry copies of the
scripts. `nixman completion SHELL` prints the corresponding packaged script;
the Zsh script is an autoload function intended for `fpath`.

Command, option and choice completions derive from the CLI parser. Generation
arguments query the available upstream generations without activating or
deleting anything. File-path completion is delegated to the shell.
