{
  contracts = [
    "system.mihomo"
    "home.gpg"
  ];
  managesSystem = true;
  requiresHardwareConfig = false;
  family = "darwin";
  upstreamNixos = false;
  output = "darwinConfigurations";
  builder = "darwin";
  packageManager = "homebrew";
  defaultSystem = "aarch64-darwin";
  systemModules = [ ./system/default.nix ];
  homeModules = [ ];
  features = {
    chrome.homeModules = [ ./home/chrome.nix ];
    smartcard.homeModules = [ ./home/smartcard.nix ];
  };
}
