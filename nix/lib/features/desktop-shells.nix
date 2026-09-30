# Session shells share one selection policy; greeters remain separate.
{
  dms = {
    systemProgram = "dms-shell";
    greeter = "dms-greeter";
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
