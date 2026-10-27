# Session shells share one selection policy; greeters remain separate.
{
  dms = {
    systemProgram = "dux-shell";
    greeter = "dux-greeter";
    greeterContract = "system.dms";
    homeProgram = "dank-material-shell";
  };
  noctalia = {
    systemProgram = "noctalia";
    greeter = "noctalia-greeter";
    greeterContract = "system.noctalia-greeter";
    homeProgram = "noctalia";
  };
}
