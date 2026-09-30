{ osConfig, ... }: {
  home.sessionPath = [ "${osConfig.native.profileDirectory}/bin" ];
}
