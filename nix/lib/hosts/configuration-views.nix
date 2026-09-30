# Normalize deployment outputs for shared planning, diagnostics and tests.
{
  output,
  username,
  configuration,
}:
if output == "homeConfigurations" then
  {
    home = configuration.config;
    system = configuration.systemConfiguration.config;
  }
else
  {
    system = configuration.config;
    home = configuration.config.home-manager.users.${username};
  }
