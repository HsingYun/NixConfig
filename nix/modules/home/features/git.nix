{
  lib,
  user,
  ...
}:

{
  software = {
    requirements.git = { };
  };
  programs.git = {
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
