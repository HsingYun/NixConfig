{ lib, ... }:

{
  software = {
    requirements = {
      nh.capabilities = [ "store-package" ];
      git = { };
      nixfmt = { };
    };
  };
  programs = {
    nh = {
      enable = lib.mkDefault true;
    };
  };
}
