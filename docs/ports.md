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
| Exclusive desktop selection | `nix/lib/features/desktop-stacks.nix` and catalog priority | Port login-manager integration |
| Software identities | Software catalog and profile recipes | Shared resolver and runtime planner |
| Package installation | `nix/modules/software/backends/` | Nix profiles, nix-darwin Homebrew, pacman/yay |
| Privileged platform effects | `nix/ports/<platform>/activation/` | Platform tools and shared ownership helpers |

A contract states supported option names, types and scopes. Ports do not silently
ignore unsupported options. NixOS keeps its full upstream interface; a native
port implements a declared subset and rejects options it has not implemented.
The contract checker verifies actual host declarations and defined values,
without forcing upstream options which intentionally have no value while their
service is disabled. Behavior tests complement these schema checks.

Contracts describe public capabilities, not individual implementation files.
The home contracts cover GPG/agent, Niri, DMS and Fcitx5. They declare the subset
that needs platform adaptation, not a second copy of the Home Manager option
catalog. Shared upstream Home Manager modules remain their own authoritative
interfaces. Internal service renderers, activation steps and helpers implement
these capabilities and do not require a separate contract per file.

The initial system contracts cover desktop services, printing/Avahi/firmware,
PC/SC/Polkit and Chromium policies. Arch does not implement Avahi NSS rewriting;
`services.avahi.nssmdns4 = true` fails explicitly. The existence of a schema is
not a claim that every upstream option or operating-system behavior is supported.

## Platform layout

```text
nix/contracts/
  system/                      Public system capability schemas
  home/                        Public home capability schemas
  default.nix                  Contract inventory
  check.nix                    Conformance checks
nix/ports/
  arch/
    default.nix                Registration, supported contracts, feature adapters
    system/                    Service implementations and desktop policy
    home/                      User configuration adaptations
    activation/                Privileged effects and their lifecycle
  nixos/
    default.nix
    system/                    Upstream module presets
    home/                      Upstream Home Manager integrations
    integrations/              System/home coordination
  nixos-wsl/                   NixOS-WSL specialization
  darwin/                      nix-darwin specialization
nix/assets/helpers/
  common/                      Shared file safety, ownership, dconf and greeter helpers
  arch/                        Arch package, service and desktop activation helpers
nix/modules/software/          Shared requirements, one plan, installation backends
nix/lib/builders/native.nix     Reusable native-host system/home evaluation
```

System and home remain separate Nix module scopes. Arch has a real system
configuration exposed at `homeConfigurations.<host>.systemConfiguration.config`.
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

## Supported customization

- Host `features` and `featureModules` compose capabilities.
- Host `preferences.desktop` chooses the default enabled GUI stack. Other stacks
  remain installed. Direct service overrides are checked for conflicts.
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
   `nix/lib/hosts/platforms.nix`. Declare its family, desktop support, builder,
   default manager and contract list. Linux/desktop feature families derive from
   those declarations.
2. Implement or reuse the named contracts under that port. Register every
   required `portScopes` implementation by feature/integration ID. Missing
   feature adapters or required contracts fail catalog validation.
3. Reuse the native builder for a distribution whose system effects run through
   privileged activation. Keep system implementation out of Home Manager feature
   modules. Ports may import shared implementations; do not copy them by default.
4. Add a package-manager provider and activation backend if needed, then add
   recipes for known identities. An Ubuntu port does not automatically imply an
   implemented apt backend: apt remains an error until that backend exists.
5. Add contract behavior cases, per-feature evaluation, mixed-provider tests and
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

`nix/tests/platform-contracts.nix` checks direct service configuration, explicit
overrides, shared consumers and every supported independent Arch/Darwin feature.
The existing NixOS matrix covers feature independence, disabled contributions,
upstream customizations and desktop combinations. `software-sources.nix` checks
mixed native/Nix/AUR requests. Helper tests exercise ownership, retirement,
conflicts and interrupted execution without mutating the real machine.

Evaluation, building a profile and testing an isolated helper do not constitute
a successful Arch login or hardware deployment. Live platform verification is
still required for those claims.
