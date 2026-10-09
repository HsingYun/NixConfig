# Platform contracts and ports

Hosts select features, a deployment platform and a default package manager.
Features contribute capabilities and software requirements. A port implements
public interfaces for a platform; it is not an Arch-only compatibility folder.
NixOS and Darwin may also add ports when upstream modules do not supply a needed
capability. Reuse upstream implementations whenever available.

Host-wide feature input is resolved once and supplied independently to both
module scopes as read-only `config.features`. System features must not reach
through `home-manager.users` for these inputs. The explicit software coordinator
still collects user and system requirements into one installation plan.
Cross-feature desktop policy belongs to the integration registry; generic
renderers consume resolved inputs without selecting features.

## Source of truth

| Concern | Declaration | Implementation |
| --- | --- | --- |
| Public system/home options | `nix/contracts/{system,home}/*.nix` | Native ports import the schema; upstream ports retain upstream declarations |
| Contract inventory | `nix/contracts/default.nix` | Each port's `contracts` list names its supported interfaces |
| Feature adaptation | Catalog `portScopes` and `contracts` | Port registration maps feature IDs to home/system modules |
| Feature composition | Feature catalog and ordinary Nix modules | Upstream `lib.evalModules` |
| Feature-local provider selection | Catalog choice `source` references a feature option | Module defaults enable the selected providers; resolver validates final availability |
| Default desktop selection | `nix/lib/features/desktop-stacks.nix` and catalog priority | `nix/modules/system/shared/desktop-policy.nix` |
| Software identities | Software catalog and profile recipes | Shared resolver and runtime planner |
| Package installation | Port system/activation modules consume the shared plan | Upstream Nix profiles, nix-darwin Homebrew, pacman/yay |
| Native system plan and lifecycle | `nix/modules/system/native/` and the native HM bridge | Shared plan, stage journal, Nix profiles and systemd reconciliation |
| Distribution-specific effects | `nix/ports/<platform>/activation/` | Native package tools, platform policies and shared ownership helpers |

A contract states supported option names, types and scopes. Ports do not silently
ignore unsupported options. NixOS keeps its full upstream interface; a native
port implements a declared subset and rejects options it has not implemented.
Normal configuration evaluation checks only contracts required by the selected
features: required options must exist and configured values must satisfy the
portable schema. It does not evaluate synthetic input samples.

The `platform-contract-types` test checks every contract declared by every port,
including dormant features, using [`type-probes.nix`](../nix/tests/contracts/type-probes.nix)
and upstream `lib.evalModules`. Every public contract option must have a probe.
Probes cover both boolean values, nonempty structured settings and Nix package
values. They are interface requirements, not platform defaults: a native adapter
can use `package = null` for native delegation while an upstream module requires
a Nix package. These sample-based checks do not prove behavioral equivalence.
The separate contract behavior suite configures public options directly, with
all features disabled, and checks generated services, files or package plans on
every registered implementation. Each contract is tested in isolation, including
its disabled configuration. Cases cannot enable a feature to supply missing port
behavior; feature presets and combinations have a separate suite.
Cases can also declare named `scenarios`, each with direct `configure` inputs
and a `verify` predicate, to check semantics beyond an enable/disable pair on
every implementing port. Fcitx scenarios cover empty profile/global settings
remaining unmanaged, absence of unrequested Chinese preset dependencies, explicitly
named addons, and disabling the user service for desktop autostart. Lifecycle helper
tests verify repeated application, transitions, interruption and ownership rules.

Contracts describe public capabilities, not individual implementation files.
The home contracts cover GPG/agent, Niri, DMS, Noctalia and Fcitx5. They declare the subset
that needs platform adaptation, not a second copy of the Home Manager option
catalog. Shared upstream Home Manager modules remain their own authoritative
interfaces. Internal service renderers, activation steps and helpers implement
these capabilities and do not require a separate contract per file.

System contracts separately cover desktop stacks and shared services, printing, Avahi, firmware,
PC/SC/Polkit and Chromium policies. Arch does not implement Avahi NSS rewriting;
`services.avahi.nssmdns4 = true` fails explicitly. The existence of a schema is
not a claim that every upstream option or operating-system behavior is supported.

## Platform layout

Home port files are grouped by responsibility, not by when they were added.
`capabilities/` implements an interface, `features/` supplies feature presets,
and `integrations/` connects existing interfaces. Integrations needed for direct
upstream configuration are loaded unconditionally and use final option values;
feature composition integrations are registered with the matching catalog rule.
Directory entry points use `default.nix`; leaf names identify the capability.


```text
nix/lib/hosts/profiles.nix      Shared feature presets supplied to hosts
nix/lib/helpers.nix            Configuration tools supplied as the helpers argument
nix/lib/config/                Pure configuration construction, layering and file selection
nix/contracts/
  system/                      Stable contract entry points
    services/                  Individual service declarations
  home/                        Public home capability schemas
  default.nix                  Contract inventory
  check.nix                    Conformance checks
nix/ports/
  arch/
    default.nix                Registration, supported contracts, feature adapters
    system/
      services/                Individual service implementations
    home/                      User configuration adaptations
      capabilities/            Implementations of configurable interfaces
      features/                Presets loaded with a selected feature
      integrations/            Coordination between capabilities/scopes
    activation/                Privileged effects and their lifecycle
  nixos/
    default.nix
    system/                    Upstream capabilities, package bindings and presets
    home/                      Same capabilities/features/integrations layout
    integrations/              System/home coordination
  nixos-wsl/                   NixOS-WSL specialization
  darwin/                      nix-darwin specialization
  common/home/capabilities/     Shared native implementations, explicitly imported
nix/assets/helpers/
  common/                      System backend, systemd, file ownership, dconf and greeter helpers
  arch/                        Arch package, service and desktop activation helpers
nix/modules/system/native/    Distribution-independent native system capabilities
nix/modules/home/native/      HM activation, inspection bridge and vendor user units
nix/modules/system/shared/desktop-policy.nix  Shared desktop defaults and arbitration
nix/modules/software/          Shared requirements and host/home planning
nix/lib/platforms/             Platform registry and registration validation
nix/tests/                     Check registration and suites grouped by responsibility
nix/lib/builders/native.nix     Reusable native-host system/home evaluation
```

System and home remain separate Nix module scopes. Arch has a real system
configuration exposed at `homeConfigurations.<host>.systemConfiguration.config`.
Home modules receive that final system configuration through the standard
`osConfig` argument. Host construction also supplies internal `views.system`
and `views.home` for output assembly and cross-platform checks. Test bootstrap
uses deployment-builder metadata rather than distribution-name branches.
Its system scope owns services, root files, software planning and the system
Nix profile. Its home scope owns application settings and user units. The shared
Home Manager activation entry point executes the system port's declared DAG
nodes, invoking the port's `native.privilegeCommand` argument vector only where
root execution is needed. Execution as a specific account uses the separate
`native.userCommand username` argument vector; shared helpers never construct
sudo-specific flags. Arch supplies both command prefixes. Protected resource
verification uses the same root prefix as activation.

AUR builds still run as the user. The pacman adapter invokes yay directly and
passes a generated command wrapper through yay's `--sudo` option, with empty
`--sudoflags` to preserve the declared argument vector. Yay itself invokes that
wrapper when elevation is needed. Arch's root prefix must support yay's sudo
invocations; yay is never launched through the root prefix.

Ports can extend an upstream package interface where native delegation is missing.
The shared Vim adapter lives in `nix/ports/common/home/capabilities/`; Arch's
keyring adapter is `nix/ports/arch/home/capabilities/gnome-keyring.nix`. Both reuse upstream option declarations and execute the
upstream configuration when a Nix package is selected. Their native branches add
only configuration/service integration. The module switch uses Home Manager's
`disabledModules`, and option declarations are replaced as whole declarations,
not merged into the internals of Nix option types. NixOS retains its original
modules. Shape probes in `upstream-assumptions.nix` and behavioral conformance
tests detect incompatible upstream changes.

On Arch, `wayland.windowManager.niri.systemd.enable` exposes the native vendor
units through Home Manager's XDG data files. As in upstream Home Manager, this
installs units for `niri-session`; it does not enable, start or restart the
compositor. The native system port owns the runtime and vendor units. NixOS
continues to use the original upstream implementation.

Noctalia has one owner for each user's service. An enabled Home Manager service
uses the upstream unit and its `wayland.systemd.target`; its runtime demand
selects Nix because the upstream service requires a store package. On Arch,
the system port supplies a unit only when no Home Manager service is requested,
using the system interface's target and the selected native or Nix executable.
When both scopes request the service, the Home Manager unit takes precedence,
matching user-unit precedence over system-wide user units. Configuration-only
Home Manager use does not require Nix and preserves the native package preference.

The shared native MPV port extends `programs.mpv.scripts` to native players.
It uses HM's original option schema and user-configuration generators. When `package = null`,
the port passes an empty scripts list only to HM's wrapper implementation, while
its public scripts option retains the user's declarations. The port contributes
only the additional script-loading directives, using MPV's length-prefixed path
syntax, before HM's output so they remain outside named profile sections.
User configuration reaches HM unchanged, including its conditions for rendering
default profiles when configuration or profiles are nonempty. Generated paths
never become definitions of the public configuration option.
Scalar values, list ordering and override priorities keep HM's merge semantics.
Clearing `config.script` does not clear `scripts`, and clearing `scripts` does
not clear user-defined script paths. Native configuration
loads every `scriptName` and `extraScriptsToLoad` from the original package path,
preserving sibling resources. Font directories are flattened into HM-managed
`mpv/fonts` links, the upstream player's [default OSD/subtitle font directory](https://mpv.io/manual/stable/#options-osd-fonts-dir)
on both Linux and macOS. Fonts do not require a Nix player or a fontconfig override.

`programs.mpv.nativeScriptAdapters` is an explicit extension on native ports.
Each named adapter declares the exact script `package`, the exact `wrapperArgs`
it implements, and the equivalent `scriptOpts`. The built-in thumbfast adapter
replaces its known player PATH requirement with an explicit `mpv_path` pointing
to the selected player. Matching uses package identity and wrapper arguments,
never just a script filename. All matching declarations contribute settings;
ordinary module merging reports conflicting defaults instead of silently selecting
one adapter. Hosts may add or override these declarations through
`homeConfig`; an adapter must account for every declared wrapper argument.
Changed or unknown wrapper requirements fall back to Nix. An explicit native
provider override with unmet requirements fails during software selection.
Adapter declarations live beside the native MPV implementation in `mpv-script-adapters/`;
the shared software adapter collects their demand before provider selection.

Nix-selected players receive the unchanged upstream scripts and wrapper arguments.
NixOS does not import the native port. The same public-input scenarios run against
original HM, delegated Nix and native implementations on Arch and Darwin. They
compare merged inputs, generated configuration and Nix wrappers, including scalar
and list script paths, ordering, forced empty values, disabled programs, and all
empty/nonempty combinations of configuration, profiles and default profiles.
Native file-tree tests build real ModernX fonts, verify every resource
is exposed, and cover additional scripts, duplicate basenames and cleanup.

The common native Ghostty adapter declares optional integration demands and their
input defaults without replacing HM's implementation. It is loaded only by Arch
and Darwin. NixOS and NixOS-WSL retain the upstream defaults, package and service
modules. Demand conditions must not read provider selection: collect intent first,
resolve software second, and delegate implementation last.

Managing native system configuration is an intentional responsibility of this
project. Arch's system layer reconciles explicitly owned files, services and
profiles while preserving unmanaged state and native package ownership. Reuse
Nix and Home Manager primitives within that boundary.

The native backend is shared by distributions. A future Ubuntu port supplies its
package-manager adapter, service requests, policy paths and privilege command;
it reuses the same native builder, Nix profile, systemd reconciler, resource
ownership helpers and activation journal. The common layers do not import Arch
modules or select tools by distribution name. NixOS and Darwin use their upstream
builders instead of this native backend.

Ports contribute three interfaces:

- `native.preflight`: read-only DAG stages before HM's write boundary.
- `native.activation`: effectful DAG stages; the coordinator records their start,
  successful completion and failures without changing their HM dependencies.
- `native.resources.<name>`: the JSON-serializable `desired` state and an optional
  read-only `check` script. Ports own the resource semantics; the coordinator owns
  plan comparison and the execution/reporting protocol.

`native.plan` is an immutable Nix-generated artifact containing the host, owner,
resources and stage definitions. The installed `nixconfig-system` command exposes:

```console
nixconfig-system plan    # Selected configuration, stages and resource requests
nixconfig-system diff    # Desired resource changes since the last successful run
nixconfig-system status  # Latest native attempt, completed stages and exit code
nixconfig-system verify  # Inspect live resources; nonzero on drift/query failure
```

Diff compares declarations; verify checks the live machine. Resources without a
check are explicitly reported as `unchecked`. Verification may use the port's
privilege command for protected files. The coordinator verifies after the HM DAG
stages and records success only after those checks pass. Package installation,
file updates and service changes are separate operations, not one atomic
transaction. A failed run preserves its completed-stage list and the previous
successful desired state. Retry reruns idempotent stages so actual drift is not
hidden by a stale "completed" flag. An exited process with an unfinished attempt
is reported as interrupted, including failure in an intervening HM stage.

The journal starts after HM's write boundary. Earlier preflight/file-conflict
errors remain ordinary HM errors and do not update the native attempt. Its
user-owned files under `$XDG_STATE_HOME/nixconfig/system` are diagnostic only;
privileged file/service reconcilers continue using their separate root-owned
ownership records. Altering or removing a journal cannot authorize cleanup.
Dry runs do not write the journal. No automatic backups or forced file adoption
are introduced.

System Nix profiles are owner-scoped at
`/nix/var/nix/profiles/nixconfig-system-<username>` and use upstream Nix generation
management. The auxiliary system profile retains only its selected generation;
activation uses `nix-env --delete-generations old` after selecting the package set.
Reapplying the same output does not create another generation, but still retires
auxiliary history. Retained Home Manager generations reference their system
package sets through their activation scripts and keep them reachable to Nix GC.
Consequently, deployment history belongs to HM alone: deleting an HM generation
allows its otherwise-unused system packages to be collected. No generation-number
mapping or separate retention database is maintained.
Reapplying an older HM generation restores its declared managed configuration;
native packages remain installed unless explicitly selected for guarded migration.
There is no automatic rollback of pacman or a claim of whole-machine atomicity.

`native.systemd.definitions` adds structured, owned concrete system unit files alongside
vendor unit requests. The shared backend renders them with the Nixpkgs systemd
format, records file ownership, reloads systemd, and restarts active requested
units only when their definition content changes. Failed restarts remain pending
and retry on the next application. Retirement removes owned enablement and stops
eligible units before removing their definitions; active external consumers and
foreign file edits prevent unsafe removal. Private runtime configuration files
are not watched or managed by this interface.
Template definitions are rejected; vendor templates remain supported by the
existing unit-request interface. Removing a definition still required by another
owner, including an enable-only request, is an explicit conflict.

Native home adapters declare vendor user units through
`native.systemd.user.units.<unit-name>`, with `wantedBy`, `requiredBy`, `aliases`
and structured `dropIns`. The shared home systemd adapter links the installed unit from
the port's `native.systemd.user.vendorDirectory` (`/usr/lib/systemd/user` on Arch),
renders drop-ins with `pkgs.formats.systemd`, and lets
Home Manager own the links and activation. It does not copy vendor unit contents
or synthesize incomplete replacement services. Setting `enable = false` removes
that declaration's managed links and drop-ins through the normal HM lifecycle.
This interface declares the requested links explicitly; it does not interpret
the vendor unit's `[Install]` section. System-level enablement continues to use
the native systemd reconciler and `systemctl`.

NixOS and Darwin continue to use their upstream builders and activation engines;
Arch reconciliation is never installed on them. The software coordinator accepts
both scopes' contributions and returns the same resolved plan to each consumer.
Upstream modules retain ownership of customized Nix wrappers and their internal
dependencies.

Runtime and activation helpers follow the same platform boundary as ports.
Place a platform-specific helper in `nix/assets/helpers/<platform>/`; put reusable
runtime code in `helpers/common/`. Pure configuration constructors and serializers
belong in `nix/lib/config/`, exposed through `nix/lib/helpers.nix`. The host loader
and shared module arguments supply the same `helpers` entry point; these tools
do not define feature options or port contracts.
Do not create empty platform directories. Shared Python dependencies must remain
available in the Nix store closure; tests execute the packaged helpers as well as
checking their source behavior.

Common feature metadata references shared modules and capability requirements.
Platform-specific modules are bound only in port registrations. Shared modules
must not import platform implementations. Feature availability derives from the
platform family and the contracts implemented by the port. GNOME/GDM, Niri/greetd
and DMS declare separate capabilities. A port may support GNOME without Niri or
DMS; unsupported feature selections fail explicitly. Desktop classification is
derived from the implemented stack contracts.

Desktop defaults have one shared owner. Ports consume final session/service
options and implement their service dependencies. Optional services receive
positive enablement requests; an unselected service keeps its upstream/schema
default instead of receiving a competing negative preset. Mutual exclusion of
login managers is checked separately. Arch's DMS greeter requires the Niri
compositor capability, matching the upstream dependency rather than installing
only a standalone compositor binary.

Always-loaded capability modules declare and implement options even when their
feature is off, supporting direct configuration and lifecycle cleanup. Feature
adapters supply presets; they do not re-register a permanent implementation to
satisfy a metadata check. For example, Arch's Niri, DMS and input-method capabilities
are loaded once under `home/capabilities/`.

Service schemas live under `contracts/system/services/`. Printing, Avahi and
firmware are independently registered. Desktop features compose their stack
contract with shared network, audio, Bluetooth, power, storage and session
contracts. The NixOS option names and feature settings remain authoritative;
capability registration determines which implementations a platform supplies.

## Supported customization

- Host `profiles` selects shared presets and `features` customizes capabilities
  from the same entry point. Features own the
  translation of public settings into system and Home Manager modules.
- Session shells are registered in `nix/lib/features/desktop-shells.nix`.
  `features.desktop.niri.shell` enables and selects a shell and its greeter while enabled shell
  packages and settings coexist. System and Home Manager startup requests are
  checked together. Greeters have a separate lifecycle and are not session shells.
- Host `preferences.desktop` chooses the default enabled GUI stack. Other stacks
  remain installed. Feature priority supplies defaults only. Execution reads the final merged
  options: changing `services.displayManager.defaultSession` updates generated
  greeter commands. A known default session must remain enabled when a login
  manager is active; explicit custom greeter commands are preserved. Direct
  service overrides are checked for conflicts.
  Arch GDM applies its default session at the next GDM start through the same
  AccountsService utility used by NixOS. Activation validates that the native
  session is installed before changing the login-manager configuration; it does
  not restart a running login manager or terminate desktop sessions. Setting
  the default to `null` removes the managed GDM startup override.
- Optional host `systemConfig` and `homeConfig` extension modules expose
  upstream-style options when a feature interface does not cover a requirement.
  Shipped hosts express their ordinary configuration through features instead.
  On a native port, unsupported options fail instead of becoming inert settings.
- Host `packageManager.type` sets the default software source.
- `packageManager.extraPkg.<provider>.<group>` declares packages outside the
  feature catalog, using that provider's names. Nix, native and AUR extras can
  coexist. Unsupported provider/platform combinations fail during evaluation.
- `software.providerOverrides.<identity>` explicitly selects an existing source.
- `software.packageOverrides.<identity>` supplies a custom Nix derivation and
  selects Nix. Overrides from either scope pass through the host coordinator.
- `software.migration.removeReplaced` separately authorizes native package removal.

A package override never disables platform ABI or system-service requirements.
For example, a Nix-only Niri binary cannot substitute for the native session and
portal integration required by the Arch port. The configuration fails with a
specific diagnostic when a selected source cannot satisfy that requirement.

Do not introduce host activation scripts, PATH shadowing or direct package
installation as hidden substitutes for these interfaces. If a necessary
customization cannot be expressed, extend the public contract and implement it
in the relevant port with tests. Ordinary explicit upstream options remain
supported customization; the framework does not replace the Nix module system
or attempt to sandbox trusted Nix modules.

## Adding Ubuntu or another platform

1. Create `nix/ports/<platform>/default.nix` and register it in
   `nix/lib/platforms/default.nix`. Declare its family, builder,
   default manager, `packageProviders`, hardware-configuration requirement and
   contract list. The default manager must be in the supported provider list,
   which must include Nix. `capabilities` declares environment properties such
   as `efi` for firmware tooling; service interfaces belong in `contracts`.
   Platform families and feature availability derive from those declarations;
   only claim implemented capabilities.
2. Implement or reuse the named contracts under that port. Register every
   required `portScopes` implementation by feature/integration ID. Missing
   feature adapters or required contracts fail catalog validation.
3. Reuse the native builder for a distribution whose system effects run through
   privileged activation. Keep system implementation out of Home Manager feature
   modules. Ports may import shared implementations; do not copy them by default.
4. Add a package-manager provider and activation backend if needed, then add
   recipes for known identities. An Ubuntu port does not automatically imply an
   implemented apt backend: apt remains an error until that backend exists.
5. Every public contract must have a shared case in `nix/tests/contracts/cases.nix`.
   The runner discovers all registered ports and exercises their enabled/disabled
   effects through direct public-interface configuration. Missing cases fail CI. Register its evidence adapter under `nix/tests/contracts/observations/`
   when introducing a port; missing observers also fail CI. Shared scenarios
   do not need platform branches. Add per-feature evaluation, mixed-provider tests and
   native lifecycle tests. Test the resulting configuration on the actual OS
   before claiming deployment support.

Features using only supported shared contracts should need no Ubuntu-specific
branches. New semantics belong in a reviewed contract extension; adding a port
must not weaken NixOS checks or reimplement an upstream activation engine.

## Lifecycle and verification

Feature settings merge through normal Nix option types and priorities. Shared
resource requests are combined before activation. Port backends remain imported
when a feature is disabled so their managed resources can be reconciled.
Unrequested native packages remain installed unless an explicit migration names
them. Systemd/files keep root-owned ownership records; missing prior state does
not authorize deleting existing host resources.

Login-manager selection affects the next boot. Switching or disabling the last
managed manager never stops the live GUI. Owned greetd files are retired when
no longer requested, and conflicting owners or foreign changes remain visible.
New login-manager records preserve the original manager and boot target. When
the final consumer releases management, the backend restores that baseline and
disables only its replacement. It preserves an externally changed manager or
boot target. Legacy records lacking a baseline can continue selecting a desktop,
but retiring their final manager fails explicitly until its ownership is manually
resolved; the backend never guesses which existing login service it may disable.
No cross-resource atomic rollback is claimed for native package managers or
systemd; failed activations must be inspectable and retryable.

`nix/tests/upstream-assumptions.nix` contains named, minimal probes for the pinned
upstream behavior used by the framework: DAG ordering, Home Manager helpers and
autostart options, nullable submodule defaults and overrides, and override priorities. Each probe has its
own error context. These probes use upstream modules directly, without evaluating
repository hosts, features or ports. Port-interface probes check consumed fields
and unhandled behavior directives, allowing unrelated metadata additions.
Both CI workflows run them before the full
configuration checks; the same report is also registered as `upstream-assumptions`
in the flake checks. Run the independent diagnostic entry point with:

```sh
nix eval --json --show-trace .#lib.upstreamAssumptions
```

This evaluates the Linux and Darwin probes without building or activating a
configuration. These compatibility probes complement the feature and lifecycle
tests; they do not replace them.

`nix/tests/contracts/` requires a behavior case for every public contract and runs
it for every port claiming that contract. Type probes and behavior cases have
separate CI checks. Each named observation is checked independently: enabling requires all expected
effects, and disabling requires every effect to disappear. Removing only a
service or only its packages therefore fails the oracle, even when option
declarations remain valid. The Chrome lifecycle check executes the production
policy adapter with sandboxed privileged paths and verifies the policy payload. These checks verify representative effects;
they do not prove every possible setting or live OS interaction.

`nix/tests/ports/platform-contracts.nix` checks direct service configuration, explicit
overrides, shared consumers and every supported independent Arch/Darwin feature.
The structure suite checks dependency boundaries, platform metadata, and desktop
selection for a synthetic additional port. Profile regression cases preserve the
existing hosts' feature sets and default desktops. The existing NixOS matrix covers feature independence, disabled contributions,
upstream customizations and desktop combinations. `software-sources.nix` checks
mixed native/Nix/AUR requests. Helper tests exercise ownership, retirement,
conflicts and interrupted execution without mutating the real machine.

Evaluation, building a profile and testing an isolated helper do not constitute
a successful Arch login or hardware deployment. Live platform verification is
still required for those claims.

Arch validates an enabled, managed Niri configuration with `/usr/bin/niri validate`
after native package installation and before linking the candidate file. The
existing `nixconfig-system verify` command validates the deployed file through
`native.resources.niri-config`. Both phases read the final `home.file` declaration,
after XDG generation and host overrides. Its final enable flag controls validation,
its final source is checked before linking, and its final target is checked after
activation, including custom XDG paths and renamed files.
Local source paths are snapshotted into the Nix store using Home Manager's source
copying semantics, so validation uses the candidate bytes even if the original
file later changes. Existing derivations and intentional out-of-store links keep
their source semantics. Native package and service checks remain owned by their
existing resources.

Noctalia's native pre-link validation uses the same final-file reader,
`helpers.managedHomeFile` (`nix/lib/config/managed-home-file.nix`). Final source overrides and
disabled files therefore have the same meaning in both validators. Noctalia's
`checkConfig` option controls whether its native validation runs.

Tests cover both XDG and final `home.file` overrides, including disabled files,
renamed targets, and valid/invalid replacement sources. An isolated command fixture
also checks rejection of missing or invalid deployed files.
The separate Niri parser tests exercise the pinned Nix implementation. These
checks do not prove DMS schema compatibility or a successful native desktop login;
those require validation with the installed applications in a real Arch session.
