{ selected, enabled }:

{
  config,
  lib,
  ...
}:

let
  gpgSsh = config.services.gpg-agent.enable && config.services.gpg-agent.enableSshSupport;
in
{
  assertions = lib.optionals (enabled.gpg || enabled.gpgSshSupport) [
    {
      assertion = !(gpgSsh && config.services.ssh-agent.enable);
      message = "GPG SSH support and services.ssh-agent.enable cannot own the same user's SSH socket. Disable one agent.";
    }
  ];
}
