{
  description = "Minimal modular shell flake part";
  outputs = {self}: {
    flakeModule = ./shelly.nix;
  };
}
