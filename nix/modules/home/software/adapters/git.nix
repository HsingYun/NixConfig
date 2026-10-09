{
  imports = [
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-git";
      software = "git";
      installedScopes = [ "home" ];
      enableOptions = [
        [
          "programs"
          "git"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "git"
        "package"
      ];
    })
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-git-lfs";
      software = "git-lfs";
      installedScopes = [ "home" ];
      enableOptions = [
        [
          "programs"
          "git"
          "enable"
        ]
        [
          "programs"
          "git"
          "lfs"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "git"
        "lfs"
        "package"
      ];
    })
  ];
}
