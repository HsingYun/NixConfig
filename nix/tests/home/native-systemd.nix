{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  evaluate =
    modules:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../../modules/home/native/systemd.nix
        {
          native.systemd.user.vendorDirectory = "/vendor/systemd/user";
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "26.05";
          };
        }
      ]
      ++ modules;
    }).config;
  declaration.native.systemd.user.units."example.service" = {
    wantedBy = [ "default.target" ];
    aliases = [ "alias.service" ];
    dropIns."config.conf" = {
      Unit.Description = lib.mkDefault "Default description";
      Service.ExecStart = [
        ""
        "/usr/bin/example --configured"
      ];
    };
  };
  cfg = evaluate [
    declaration
    {
      native.systemd.user.units."example.service" = {
        requiredBy = [ "session.target" ];
        dropIns."config.conf".Unit.Description = "Host description";
      };
    }
  ];
  disabled = evaluate [
    declaration
    {
      native.systemd.user.units."example.service".enable = false;
    }
  ];
  empty = evaluate [ ];
  competing = evaluate [
    declaration
    {
      native.systemd.user.units."other.service".aliases = [ "alias.service" ];
    }
  ];
  replaced = evaluate [
    declaration
    {
      systemd.user.services.example.Service.ExecStart = "/usr/bin/another";
    }
  ];
  invalid = evaluate [
    {
      native.systemd.user.units."../example.service" = { };
    }
  ];
  invalidDropIn = evaluate [
    {
      native.systemd.user.units."example.service".dropIns."../outside.conf".Unit.Description =
        "Invalid path";
    }
  ];
  files = cfg.xdg.configFile;
  source = files."systemd/user/example.service".source;
  conflicts =
    cfg: path: !(builtins.tryEval (builtins.deepSeq cfg.xdg.configFile.${path}.source true)).success;
in
assert cfg.systemd.user.startServices;
assert !(cfg.systemd.user.services ? example);
assert lib.all (name: files."systemd/user/${name}".source == source) [
  "alias.service"
  "default.target.wants/example.service"
  "session.target.requires/example.service"
];
assert lib.attrNames disabled.xdg.configFile == lib.attrNames empty.xdg.configFile;
assert !(disabled.xdg.configFile ? "systemd/user/example.service");
assert conflicts competing "systemd/user/alias.service";
assert conflicts replaced "systemd/user/example.service";
assert !(builtins.tryEval (builtins.deepSeq invalid.native.systemd.user.units true)).success;
assert !(builtins.tryEval (builtins.deepSeq invalidDropIn.native.systemd.user.units true)).success;
pkgs.runCommand "native-user-units-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  test "$(readlink ${source})" = /vendor/systemd/user/example.service
  python3 - ${files."systemd/user/example.service.d/config.conf".source} <<'PY'
  import sys
  from pathlib import Path

  lines = [line.strip() for line in Path(sys.argv[1]).read_text().splitlines()]
  # Reset the vendor command before adding its replacement, retaining order.
  commands = [line.split("=", 1)[1].strip() for line in lines if line.startswith("ExecStart")]
  assert commands == ["", "/usr/bin/example --configured"], commands
  assert "Description = Host description" in lines
  assert "Default description" not in "\n".join(lines)
  PY
  touch "$out"
''
