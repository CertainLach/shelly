{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkOption isString id mkIf literalExpression;
  inherit (lib.stringsWithDeps) fullDepEntry noDepEntry textClosureMap;
  inherit (lib.strings) toShellVars escapeShellArg concatLines;
  inherit (lib.attrsets) mapAttrs attrNames mapAttrsToList;

  # Activation script logic is borrowed from NixOS activation script, logic like this is much
  # more intended for extensibility than the default shellHook, as it is already proven by
  # NixOS module system, where everything is ruled by activation script.
  addAttributeName = mapAttrs (a: v:
    v
    // {
      text = ''
        #### Activation script snippet ${a}:
        _localstatus=0
        ${v.text}

        if (( _localstatus > 0 )); then
          printf "Activation script snippet '%s' failed (%s)\n" "${a}" "$_localstatus"
        fi
      '';
    });
  activationScript = set: let
    set' = mapAttrs (_: v:
      if isString v
      # FIXME
      # Dependency ordering should be implemented better, defineEnvironment, while being core option, is totally implementable by using activationScript, it should be moved to other module (But still included in shelly), together with ability to call other environment-loading scripts.
      # Instead of having it as implicit dependency for everything, what about implementing phase-based approach? beforeSecrets/afterSecrets/beforeEnvironment/afterEnvironment/beforeUser/afterUser/IDK
      then (fullDepEntry v ["defineEnvironment"])
      else v)
    set;
    withHeadlines = addAttributeName set';
  in ''
    #!${pkgs.runtimeShell}

    _status=0
    trap "_status=1 _localstatus=\$?" ERR

    ${textClosureMap id withHeadlines (attrNames withHeadlines)}

    exit $_status
  '';
  scriptType = with lib.types; let
    scriptOptions = {
      deps =
        mkOption
        {
          type = types.listOf types.str;
          default = [];
          description = "List of dependencies. The script will run after these.";
        };
      text =
        mkOption
        {
          type = types.lines;
          description = "The content of the script.";
        };
    };
  in
    either str (submodule {options = scriptOptions;});
in {
  options = with lib.types; {
    shelly.shells = mkOption {
      default = {};
      type = lazyAttrsOf (
        submodule ({config, ...}: {
          # TODO: inputsFrom, support for "legacy" buildInputs/nativeBuildInputs?
          options = {
            packages = mkOption {
              default = [];
              type = listOf package;
              description = ''
                Packages to use in shell, passed directly to mkShell.
              '';
            };
            environment = mkOption {
              default = {};
              type = attrsOf (oneOf [
                str
                # Bash and other shells support arrays, toShellVars is able to process them,
                # but direnv can't reexport them. https://github.com/direnv/direnv/issues/1000
                # They still might be useful inside of activation scripts.
                (listOf str)
                # ttoShellVars also supports sets, but it is far less useful in shell,
                # also direnv doesn't support that.
                # (attrsOf str)
                package
              ]);
              description = ''
                Environment variables to define in shell.
              '';
            };
            activationScripts = mkOption {
              default = {};
              type = attrsOf scriptType;
              apply = set:
                set
                // {
                  script = activationScript set;
                };
              description = ''
                Dependency-ordered list of dep-strings to execute upon entering the shell.
              '';
            };
            factory = mkOption {
              default = pkgs.mkShell;
              defaultText = literalExpression "pkgs.mkShell";
              example = literalExpression "craneLib.devShell";
              type = unspecified;
              description = ''
                Which function to use to construct shell.
              '';
            };
            overrides = mkOption {
              default = null;
              example = literalExpression "{ stdenv = pkgs.stdenvNoCC; }";
              type = nullOr (attrsOf unspecified);
              description = ''
                Override in factory, can also be implemented using `factory = pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; }`,
                but having it as option making it possible to have overrides, which is sad, as stdenv override for example is pretty common operation.
              '';
            };

            shellHook = mkOption {
              default = "";
              type = lines;
              description = ''
                `pkgs.mkShell` compatibility, implemented using `activationScripts`
              '';
            };
          };
          config = {
            # Dep list is explicit, as defineEnvironment
            # dependency is implicitly added to everything
            activationScripts.defineEnvironment = (
              noDepEntry ''
                # Define vars
                ${toShellVars config.environment}
                # Export them
                ${concatLines (
                  mapAttrsToList (key: _: "export ${escapeShellArg key}")
                  config.environment
                )}
              ''
            );
            activationScripts.shellHook = mkIf (config.shellHook != "") config.shellHook;
          };
        })
      );
    };
  };
  config.devShells = lib.attrsets.mapAttrs (key: value:
    (
      if value.overrides != null
      then (value.factory.override value.overrides)
      else value.factory
    ) {
      inherit (value) packages;
      shellHook = value.activationScripts.script;
    })
  config.shelly.shells;
}
