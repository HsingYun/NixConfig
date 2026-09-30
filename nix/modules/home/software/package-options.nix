# Managed single-package consumers of the upstream Home Manager interface.
# Consumers connect defaults, validate ownership and report upstream installation scopes.
{
  chrome = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "google-chrome"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "google-chrome"
      "package"
    ];
    runtimePackageOption = [
      "programs"
      "google-chrome"
      "finalPackage"
    ];
  };
  ghostty = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "ghostty"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "ghostty"
      "package"
    ];
  };
  git-lfs = {
    requestWhenEnabled = true;
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
  };
  git = {
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
  };
  gnome-keyring = {
    enableOptions = [
      [
        "services"
        "gnome-keyring"
        "enable"
      ]
    ];
    packageOption = [
      "services"
      "gnome-keyring"
      "package"
    ];
  };
  gnupg = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "gpg"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "gpg"
      "package"
    ];
  };
  mpv = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "mpv"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "mpv"
      "package"
    ];
    runtimePackageOption = [
      "programs"
      "mpv"
      "finalPackage"
    ];
  };
  nh = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "nh"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "nh"
      "package"
    ];
  };
  pinentry = {
    enableOptions = [
      [
        "services"
        "gpg-agent"
        "enable"
      ]
    ];
    packageOption = [
      "services"
      "gpg-agent"
      "pinentry"
      "package"
    ];
  };
  tela = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "gtk"
        "enable"
      ]
    ];
    packageOption = [
      "gtk"
      "iconTheme"
      "package"
    ];
  };
  vim = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "vim"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "vim"
      "packageConfigurable"
    ];
    runtimePackageOption = [
      "programs"
      "vim"
      "package"
    ];
  };
  vscode = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "vscode"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "vscode"
      "package"
    ];
  };
  xdg-terminal-exec = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "xdg"
        "terminal-exec"
        "enable"
      ]
    ];
    packageOption = [
      "xdg"
      "terminal-exec"
      "package"
    ];
  };
  zsh = {
    installedScopes = [ "home" ];
    enableOptions = [
      [
        "programs"
        "zsh"
        "enable"
      ]
    ];
    packageOption = [
      "programs"
      "zsh"
      "package"
    ];
  };
}
