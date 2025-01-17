{
	description = "Shelly dogfeed test flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    shelly.url = "../";
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [inputs.shelly.flakeModule];

      perSystem = {pkgs, ...}: {
        formatter = pkgs.alejandra;
        shelly.shells.default = {
          overrides.stdenv = pkgs.stdenvNoCC;
          environment.SHELLY_DEV = "1";
        };
      };
    };
}
