{ packages, system, pkgs }:
if pkgs.lib.strings.hasSuffix "darwin" system
then { }
else {
  hermes-module-test = (import ./modules/tests/hermes-test.nix) {
    inherit (packages) hermes;
    inherit system pkgs;
    gaia = packages.gaia5;
  };
}
