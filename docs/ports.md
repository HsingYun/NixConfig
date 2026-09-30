# Platform contracts and ports

Hosts select features, a deployment platform and a default package manager.
Features contribute capabilities and software requirements. A port implements
public interfaces for a platform; it is not an Arch-only compatibility folder.
NixOS and Darwin may also add ports when upstream modules do not supply a needed
capability. Reuse upstream implementations whenever available.

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
| Privileged platform effects | `nix/ports/<platform>/activation/` | Platform tools and shared ownership helpers |

A contract states supported option names, types and scopes. Ports do not silently
ignore unsupported options. NixOS keeps its full upstream interface; a native
port implements a declared subset and rejects options it has not implemented.
The contract checker submits the portable input examples in
[`probes.nix`](../nix/contracts/probes.nix) to actual option types through upstream
`lib.evalModules`. Every public contract option must have a probe. Probes cover
both boolean values, nonempty structured settings and Nix package values. They
are interface requirements, not platform defaults: a native adapter can use
`package = null` for native delegation while an upstream module requires a Nix
package. Checks also validate defined host values without forcing undefined
upstream options. These are sample-based interface checks, not a proof of behavioral equivalence.
The separate contract behavior suite configures public options directly, with
all features disabled, and checks generated services, files or package plans on
every registered implementation. Each contract is tested in isolation, including
its disabled configuration. Cases cannot enable a feature to supply missing port
behavior; feature presets and combinations have a separate suite.
Cases can also declare named `scenarios`, each with direct `configure` inputs
and a `verify` predicate, to check semantics beyond an enable/disable pair on
every implementing port. Fcitx scenarios cover empty profile/global settings
remaining unmanaged, explicitly named addons, and disabling the user service for desktop autostart. Lifecycle helper
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

```text
nix/lib/hosts/profiles.nix      Shared feature presets supplied to hosts
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
      capabilities/            Always-loaded option implementations
    activation/                Privileged effects and their lifecycle
  nixos/
    default.nix
    system/                    Upstream capabilities, package bindings and presets
    home/                      Upstream Home Manager integrations
    integrations/              System/home coordination
  nixos-wsl/                   NixOS-WSL specialization
  darwin/                      nix-darwin specialization
nix/assets/helpers/
  common/                      Shared file safety, ownership, dconf and greeter helpers
  arch/                        Arch package, service and desktop activation helpers
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
nodes, invoking sudo only where needed. AUR builds still run as the user.

NixOS and Darwin continue to use their upstream builders and activation engines;
Arch reconciliation is never installed on them. The software coordinator accepts
both scopes' contributions and returns the same resolved plan to each consumer.
Upstream modules retain ownership of customized Nix wrappers and their internal
dependencies.

Helpers follow the same platform boundary as ports. Place a platform-specific
helper in `nix/assets/helpers/<platform>/`; put reusable code in `helpers/common/`.
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

- Host `features` selects and customizes capabilities; the loader supplies shared presets as `profile`.
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
- Host `systemConfig` and `homeConfig` use ordinary public upstream-style options.
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
   default manager, hardware-configuration requirement and contract list. Platform families and feature availability
   derive from those declarations; only claim implemented capabilities.
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
No cross-resource atomic rollback is claimed for native package managers or
systemd; failed activations must be inspectable and retryable.

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
