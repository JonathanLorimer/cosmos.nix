{ packages, inputs, system }:
{
  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
      nixpkgs-fmt.enable = true;
      nix-linter.enable = true;
    };
  };
  hermes-module = (import ./modules/relayer/hermes-test.nix) {
    inherit (packages) hermes system pkgs;
  };
} // packages # adding packages here ensures that every attr gets built on check
