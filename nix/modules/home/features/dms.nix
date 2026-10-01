{
  config,
  lib,
  ...
}:

{
  imports = [
    ../shared/desktop.nix
  ];

  software.requirements.maple-mono = { };

  programs.dank-material-shell = {
    enable = lib.mkDefault true;
    systemd.enable = lib.mkDefault false;

    inherit (config.features.desktop.dms) session;
    settings = lib.mkMerge [
      config.features.desktop.dms.settings
      (lib.mapAttrs (_: lib.mkDefault) {
        currentThemeName = "dynamic";
        currentThemeCategory = "dynamic";
        blurEnabled = true;
        blurWallpaperOnOverview = true;
        clockDateFormat = "M 月 dd 日";
        appDrawerSectionViewModes.apps = "list";
        monoFontFamily = "Maple Mono NF CN";
        launcherLogoMode = "os";
        showDock = true;
        dockGroupByApp = true;
        dockIndicatorStyle = "line";
        dockIsolateDisplays = true;
        dockLauncherEnabled = true;
        dockLauncherLogoMode = "os";
        dockLauncherLogoColorOverride = "primary";
        appsDockColorizeActive = true;
        appsDockActiveColorMode = "success";
        showOnLastDisplay.dock = true;
        # Keep the standard bar widgets and add network throughput. Specific
        # monitor names and other hardware preferences belong to each host.
        barConfigs = [
          {
            id = "default";
            name = "Main Bar";
            enabled = true;
            position = 0;
            screenPreferences = [ "all" ];
            showOnLastDisplay = true;
            leftWidgets = [
              "launcherButton"
              "workspaceSwitcher"
              "focusedWindow"
            ];
            centerWidgets = [
              "music"
              "clock"
              "weather"
            ];
            rightWidgets = [
              "network_speed_monitor"
              "systemTray"
              "clipboard"
              "cpuUsage"
              "memUsage"
              "notificationButton"
              "battery"
              "controlCenterButton"
            ];
          }
        ];
      })
    ];
    enableCalendarEvents = lib.mkDefault false;
  };
}
