{ lib, software, ... }:
{
  desktop.applications.browser = lib.mkDefault {
    command = [ (software.chrome.command "google-chrome-stable") ];
    desktopId = "google-chrome.desktop";
  };
}
