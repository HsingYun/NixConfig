{ lib }:
let
  plan = import ./plan.nix { inherit lib; };
  # Planning must remain cheap even when a check fails or is expensive to force.
  checks = {
    x86_64-linux.a = throw "CI planning evaluated a check";
    aarch64-darwin.b = throw "CI planning evaluated a foreign-platform check";
  };
  groups = {
    linux = {
      system = "x86_64-linux";
      runner = "ubuntu-24.04";
      checks = [ "a" ];
    };
    darwin = {
      system = "aarch64-darwin";
      runner = "macos-15";
      checks = [ "b" ];
    };
  };
  accepts =
    groups: (builtins.tryEval (builtins.deepSeq (plan { inherit checks groups; }) true)).success;
  valid = plan { inherit checks groups; };
in
assert accepts groups;
assert !(accepts (builtins.removeAttrs groups [ "linux" ]));
assert !(accepts (groups // { duplicate = groups.linux; }));
assert
  !(accepts (
    groups
    // {
      linux = groups.linux // {
        checks = [ "renamed" ];
      };
    }
  ));
assert
  !(accepts (
    groups
    // {
      linux = groups.linux // {
        checks = [
          "a"
          "extra"
        ];
      };
    }
  ));
assert
  !(accepts (
    groups
    // {
      linux = groups.linux // {
        checks = [
          "a"
          "a"
        ];
      };
    }
  ));
assert
  !(accepts (
    groups
    // {
      linux = groups.linux // {
        system = "aarch64-linux";
      };
    }
  ));
assert (builtins.elemAt valid.include 0).installables == [ ".#checks.aarch64-darwin.b" ];
assert (builtins.elemAt valid.include 1).installables == [ ".#checks.x86_64-linux.a" ];
true
