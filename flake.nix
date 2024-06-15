{
  description = "Minimal modular shell flake part";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      # TODO: lib for easier extension of shelly.shell.<NAME> submodule with other options.
      flake.flakeModule = import ./shelly.nix;
      # Systems to develop this flake itself on, no need to provide user
      # with the ability to override it (as with nix-systems input), because
      # it should not be observable from outside.
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin"];
      # Dogfeed itself
      imports = [./shelly.nix];

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
        shelly.shells.default = {
          overrides.stdenv = pkgs.stdenvNoCC;
        };
      };
    };
}
