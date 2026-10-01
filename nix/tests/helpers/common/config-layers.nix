{ lib }:
let
  order = [
    10
    20
    30
  ];
  layer =
    args:
    (import ../../../assets/helpers/common/config-layers.nix { inherit lib; }) (
      { inherit order; } // args
    );
  render =
    strategy:
    (lib.evalModules {
      modules = [
        { options.text = lib.mkOption { type = lib.types.lines; }; }
        {
          text = layer {
            inherit strategy;
            layer = "runtime";
          } "runtime";
        }
        {
          text = layer {
            inherit strategy;
            layer = "explicit";
          } "explicit";
        }
        {
          text = layer {
            inherit strategy;
            layer = "defaults";
          } "defaults";
        }
      ];
    }).config.text;
  succeeds = args: (builtins.tryEval (builtins.deepSeq (layer args "test") true)).success;
in
assert render "last-wins" == "defaults\nruntime\nexplicit";
assert render "first-wins" == "explicit\nruntime\ndefaults";
assert
  !(succeeds {
    strategy = "guess";
    layer = "runtime";
  });
assert
  !(succeeds {
    strategy = "last-wins";
    layer = "unknown";
  });
assert lib.all
  (
    order:
    !(succeeds {
      inherit order;
      strategy = "last-wins";
      layer = "runtime";
    })
  )
  [
    [
      10
      10
      30
    ]
    [
      30
      20
      10
    ]
    [
      10
      20
    ]
    [
      10
      "20"
      30
    ]
  ];
true
