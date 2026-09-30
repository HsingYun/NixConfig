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
  };
  # One default stack: Niri with DMS and the inferred greetd login manager.
  # Hosts selecting GNOME disable Niri/DMS and enable GNOME explicitly.
  linuxDesktop = graphical // {
    mpv.enable = true;
    chinese.enable = true;
    desktop = {
      niri.enable = true;
      dms.enable = true;
    };
  };
}
