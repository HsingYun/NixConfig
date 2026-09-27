{ selected, enabled }:

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
  services.displayManager = {
    defaultSession = lib.mkIf (selected.desktop != null) selected.desktop;
    gdm.enable = lib.mkIf enabled.gnome (lib.mkDefault (selected.loginManager == "gdm"));
    dms-greeter = {
      enable = lib.mkIf enabled.dms (lib.mkDefault (selected.loginManager == "dms"));
      compositor.name = lib.mkIf (selected.loginManager == "dms") (lib.mkDefault "niri");
    };
  };

  services.gnome.gcr-ssh-agent.enable = lib.mkIf (managesSsh && (gpgSsh || otherSsh)) false;

  assertions =
    lib.optionals (enabled.gnome || enabled.dms) [
      {
        assertion = !(config.services.displayManager.gdm.enable && config.services.greetd.enable);
        message = "GDM and greetd (including DMS greeter) cannot both own the login screen. Select preferences.loginManager and remove conflicting system overrides.";
      }
    ]
    ++ lib.optionals managesSsh [
      {
        assertion = lib.count (enabled: enabled) sshAgents <= 1;
        message = "Multiple SSH agents are configured for the managed user. Select one of GPG SSH support, the Home Manager SSH agent, the system SSH agent, or GNOME GCR.";
      }
    ];
}
