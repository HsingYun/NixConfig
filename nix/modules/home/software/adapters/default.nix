# Built-in HM interfaces are registered independently of feature selection.
# Optional upstream interfaces are imported by the port that supplies them.
{
  imports = [
    ./google-chrome.nix
    ./ghostty.nix
    ./git.nix
    ./gnome-keyring.nix
    ./gpg.nix
    ./mpv.nix
    ./nh.nix
    ./tela.nix
    ./vim.nix
    ./vscode.nix
    ./xdg-terminal-exec.nix
    ./zsh.nix
  ];
}
