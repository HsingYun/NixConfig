{ enabled }:
{
  imports = [
    ./login-manager.nix
    (import ./keyring.nix { inherit enabled; })
    (import ./ssh-agent.nix { inherit enabled; })
    ./dconf.nix
  ];
}
