{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  systemd.services.user-avatar =
    lib.mkIf (config.services.accounts-daemon.enable && (user.avatar or null) != null)
      {
        description = "Set the user avatar through AccountsService";
        wantedBy = [ "accounts-daemon.service" ];
        requires = [ "accounts-daemon.service" ];
        after = [ "accounts-daemon.service" ];
        partOf = [ "accounts-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -o pipefail
          account_path=$(${pkgs.systemd}/bin/busctl --system --json=short call \
            org.freedesktop.Accounts /org/freedesktop/Accounts \
            org.freedesktop.Accounts FindUserByName s ${lib.escapeShellArg user.username} \
            | ${lib.getExe pkgs.jq} -er '.data[0]')
          ${pkgs.systemd}/bin/busctl --system --allow-interactive-authorization=no call \
            org.freedesktop.Accounts "$account_path" \
            org.freedesktop.Accounts.User SetIconFile s ${lib.escapeShellArg "${user.avatar}"}
        '';
      };
}
