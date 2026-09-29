{ lib, software, ... }:

{
  software.bindings.nh = {
    enableOption = [
      "programs"
      "nh"
      "enable"
    ];
    packageOption = [
      "programs"
      "nh"
      "package"
    ];
  };
  programs.nh.package = lib.mkDefault software.nh.package;
  programs.nh.enable = lib.mkDefault true;

  software.requirements = {
    nh.capabilities = [ "store-package" ];
    git = { };
    nixfmt = { };
  };
}
