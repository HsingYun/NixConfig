{ desktopSession, enabled }:
{
  imports = [
    (import ./login-manager.nix { inherit desktopSession enabled; })
    (import ./keyring.nix { inherit enabled; })
    (import ./ssh-agent.nix { inherit enabled; })
    ./dconf.nix
  ];
}
