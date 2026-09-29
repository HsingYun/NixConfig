{ config, lib, ... }:

{
  xdg.mimeApps =
    lib.mkIf
      (builtins.elem config.software.platform [
        "arch"
        "nixos"
      ])
      {
        enable = lib.mkDefault true;
        defaultApplications = lib.genAttrs [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ] (_: lib.mkDefault [ "google-chrome.desktop" ]);
      };
}
