{
  lib,
  user,
  software,
  ...
}:

{
  software.bindings.git = {
    enableOption = [
      "programs"
      "git"
      "enable"
    ];
    packageOption = [
      "programs"
      "git"
      "package"
    ];
  };
  software.requirements.git = { };
  programs.git = {
    package = lib.mkDefault software.git.package;

    enable = lib.mkDefault true;
    settings = {
      user = {
        name = lib.mkDefault user.git.name;
        email = lib.mkDefault user.git.email;
      };
      alias.lg = lib.mkDefault "log --graph --abbrev-commit --decorate --all --format=format:'%C(bold blue)%h%C(reset) %C(auto)%d%C(reset) %s %C(dim white)(%ar)%C(reset) %C(bold green)<%an>%C(reset)'";
    };
  };
}
