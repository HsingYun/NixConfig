{ lib, build }:

let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  usesResolved =
    cfg:
    cfg.services.resolved.enable
    && !cfg.networking.resolvconf.enable
    && cfg.environment.etc."resolv.conf".source == "/run/systemd/resolve/stub-resolv.conf";
  usesNetworkd =
    cfg:
    cfg.networking.useNetworkd
    && cfg.systemd.network.enable
    && !cfg.networking.networkmanager.enable
    && !(cfg.systemd.services.dhcpcd.enable or false)
    && cfg.systemd.network.networks."99-ethernet-default-dhcp".DHCP == "yes"
    && usesResolved cfg;
  usesNetworkManager =
    cfg:
    cfg.networking.networkmanager.enable
    && !cfg.networking.useNetworkd
    && !cfg.systemd.network.enable
    && !(cfg.systemd.services.dhcpcd.enable or false)
    && cfg.networking.networkmanager.dns == "systemd-resolved"
    && builtins.elem "networkmanager" cfg.users.users.test.extraGroups
    && usesResolved cfg;
  cases = [
    {
      name = "console-default";
      features = { };
      verify = usesNetworkd;
    }
    {
      name = "console-networkmanager";
      features = allOff // {
        network = true;
      };
      systemConfig.networking.networkmanager.enable = true;
      verify = usesNetworkManager;
    }
    {
      name = "network-disabled";
      features = allOff;
      verify =
        cfg:
        !cfg.services.resolved.enable
        && !cfg.networking.useNetworkd
        && !cfg.networking.networkmanager.enable
        && cfg.networking.networkmanager.dns == "default"
        && !(builtins.elem "networkmanager" cfg.users.users.test.extraGroups);
    }
    {
      name = "external-network";
      features = allOff;
      systemConfig = { lib, ... }: {
        networking.useNetworkd = lib.mkDefault true;
        services.resolved.enable = lib.mkDefault true;
      };
      verify = usesNetworkd;
    }
    {
      name = "networkd-static-address";
      features = allOff // {
        network = true;
      };
      systemConfig.networking = {
        useDHCP = false;
        interfaces.eth0.ipv4.addresses = [
          {
            address = "192.0.2.10";
            prefixLength = 24;
          }
        ];
      };
      verify =
        cfg:
        cfg.networking.useNetworkd
        && usesResolved cfg
        && !(cfg.systemd.network.networks ? "99-ethernet-default-dhcp")
        && builtins.elem "192.0.2.10/24" cfg.systemd.network.networks."40-eth0".address;
    }
  ]
  ++
    map
      (desktop: {
        name = "${desktop}-networkd";
        features = allOff // {
          ${desktop} = true;
        };
        systemConfig.networking.networkmanager.enable = false;
        verify = usesNetworkd;
      })
      [
        "gnome"
        "niri"
        "dms"
      ];
  verify =
    case:
    let
      cfg = build case;
      assertions = cfg.assertions ++ cfg.home-manager.users.test.assertions;
    in
    assert lib.assertMsg (lib.all (a: a.assertion) assertions) "Network assertion failed: ${case.name}";
    assert lib.assertMsg (case.verify cfg) "Network configuration failed: ${case.name}";
    case.name;
in
map verify cases
