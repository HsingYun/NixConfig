{ lib, software, ... }:

{
  software = {
    bindings.nh = {
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
    requirements = {
      nh.capabilities = [ "store-package" ];
      git = { };
      nixfmt = { };
    };
  };
  programs = {
    nh = {
      package = lib.mkDefault software.nh.package;
      enable = lib.mkDefault true;
    };
  };
}
