# Extend HM's interface with native package delegation. Nix packages execute
# the original module; only the package=null branch is implemented here.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  upstream = import "${inputs.home-manager}/modules/programs/vim.nix" { inherit config lib pkgs; };
  cfg = config.programs.vim;
  native = cfg.packageConfigurable == null;
  nullable = option: option // { type = lib.types.nullOr option.type; };
  # HM validates the setting names/types. This branch only renders their Vim
  # syntax; vimUtils owns plugin loading and the generated vimrc.
  setting =
    name: value:
    lib.optionalString (value != null) (
      "set "
      + (
        if builtins.isBool value then
          (if value then "" else "no") + name
        else
          "${name}=${if builtins.isList value then lib.concatStringsSep "," value else toString value}"
      )
    );
  missingPlugins = lib.filter (p: builtins.isString p && !(pkgs.vimPlugins ? ${p})) cfg.plugins;
  plugins = map (p: if builtins.isString p then pkgs.vimPlugins.${p} else p) cfg.plugins;
in
{
  disabledModules = [ "programs/vim.nix" ];
  options =
    lib.recursiveUpdateUntil
      (
        _: left: right:
        lib.isOption left || lib.isOption right
      )
      upstream.options
      {
        programs.vim = {
          packageConfigurable = nullable upstream.options.programs.vim.packageConfigurable;
          package = nullable upstream.options.programs.vim.package;
        };
      };
  config = lib.mkMerge [
    (lib.mkIf (!native) upstream.config)
    (lib.mkIf (cfg.enable && native) {
      programs.vim = {
        plugins = upstream.options.programs.vim.plugins.default;
      };
      assertions = [
        {
          assertion = missingPlugins == [ ];
          message = "Native Vim: unknown plugins: ${lib.concatStringsSep ", " missingPlugins}.";
        }
      ];
      warnings = lib.optional (lib.any builtins.isString cfg.plugins) "Specifying Vim plugins using strings is deprecated; use pkgs.vimPlugins packages.";
      home = {
        file.".vimrc".source = lib.mkDefault (
          pkgs.vimUtils.vimrcFile {
            customRC =
              lib.concatStringsSep "\n" (lib.mapAttrsToList setting cfg.settings) + "\n" + cfg.extraConfig;
            packages.home-manager.start = plugins;
          }
        );
        sessionVariables = lib.mkIf cfg.defaultEditor {
          EDITOR = "vim";
          VISUAL = "vim";
        };
      };
    })
  ];
}
