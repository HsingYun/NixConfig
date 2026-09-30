{
  contracts = [
    "home.gpg"
  ];
  managesSystem = true;
  family = "darwin";
  desktop = false;
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
