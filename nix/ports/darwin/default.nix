{
  contracts = [
    "system.mihomo"
    "home.gpg"
  ];
  packageProviders = [
    "nix"
    "homebrew"
  ];
  capabilities = [ ];
  managesSystem = true;
  requiresHardwareConfig = false;
  family = "darwin";
  upstreamNixos = false;
  output = "darwinConfigurations";
  builder = "darwin";
  packageManager = "homebrew";
  defaultSystem = "aarch64-darwin";
  systemModules = [ ./system/default.nix ];
  homeModules = [
    ../common/home/capabilities/ghostty.nix
    ../common/home/capabilities/mpv.nix
    ../common/home/capabilities/vim.nix
  ];
  features = {
    macos.systemModules = [ ./system/macos.nix ];
    chrome.homeModules = [ ./home/features/chrome.nix ];
    smartcard.homeModules = [ ./home/features/smartcard.nix ];
  };
}
