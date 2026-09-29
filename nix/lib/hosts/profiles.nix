# Shared experience; hosts select hardware and their default desktop.
rec {
  cli = {
    commonTools.enable = true;
    devel.enable = true;
    codex.enable = true;
    smartcard.enable = true;
  };
  graphical = cli // {
    chrome.enable = true;
    vscode.enable = true;
    ghostty.enable = true;
    mapleMono.enable = true;
    mpv.enable = true;
  };
  linuxDesktop = graphical // {
    chinese.enable = true;
    desktop = {
      gnome.enable = true;
      niri.enable = true;
      dms.enable = true;
    };
  };
}
