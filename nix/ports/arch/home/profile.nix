{ hostSystem, ... }: {
  home.sessionPath = [ "${hostSystem.native.profileDirectory}/bin" ];
}
