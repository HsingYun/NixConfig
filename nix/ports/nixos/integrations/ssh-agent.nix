{ enabled }:
{
  config,
  lib,
  user,
  ...
}:
let
  home = config.home-manager.users.${user.username};
  gpgSsh = home.services.gpg-agent.enable && home.services.gpg-agent.enableSshSupport;
  otherSsh = home.services.ssh-agent.enable || config.programs.ssh.startAgent;
  sshAgents = [
    gpgSsh
    home.services.ssh-agent.enable
    config.programs.ssh.startAgent
    config.services.gnome.gcr-ssh-agent.enable
  ];
  managesSsh = enabled.gpg || enabled.gpgSshSupport || enabled.gnome;
in
{
  services.gnome.gcr-ssh-agent.enable = lib.mkIf (managesSsh && (gpgSsh || otherSsh)) false;
  assertions = lib.optionals managesSsh [
    {
      assertion = lib.count (active: active) sshAgents <= 1;
      message = "Multiple SSH agents are configured for the managed user. Select one of GPG SSH support, the Home Manager SSH agent, the system SSH agent, or GNOME GCR.";
    }
  ];
}
