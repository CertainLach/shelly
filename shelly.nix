{flake-parts-lib, ...}: {
  options.perSystem = flake-parts-lib.mkPerSystemOption (import ./perSystem.nix);
}
