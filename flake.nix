{
  description = "HsingYun NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ft9362-driver = {
      url = "github:HsingYun/ft9362-driver/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    import ./nix/lib/outputs.nix {
      inherit inputs;

      features.desktop.wallpaper = {
        image = ./nix/assets/desktop.png;
        lockImage = ./nix/assets/background.png;
      };

      user = {
        username = "hsingyun";
        avatar = ./nix/assets/avatar.png;
        git = {
          name = "HsingYun";
          email = "iakext@gmail.com";
        };
      };
    };
}
