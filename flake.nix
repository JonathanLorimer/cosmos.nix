{
  description = "A reproducible Cosmos";

  inputs = {
    # Nix Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    flake-utils.url = "github:numtide/flake-utils";

    # Rust Inputs
    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix = {
      url = "github:yusdacra/crate2nix/feat/builtinfetchgit";
      flake = false;
    };

    # Go Inputs
    gomod2nix.url = "github:tweag/gomod2nix";

    # Freshautomations inputs
    stoml-src = {
      url = github:freshautomations/stoml;
      flake = false;
    };

    sconfig-src = {
      url = github:freshautomations/sconfig;
      flake = false;
    };

    # Cosmos Sources
    ibc-rs-src = {
      url = github:informalsystems/ibc-rs;
      flake = false;
    };

    gaia5-src = {
      flake = false;
      url = github:cosmos/gaia/v5.0.5;
    };

    gaia4-src = {
      flake = false;
      url = github:cosmos/gaia/v4.2.1;
    };

    cosmos-sdk-src = {
      flake = false;
      url = github:cosmos/cosmos-sdk;
    };

  };

  outputs =
    { self
    , nixpkgs
    , pre-commit-hooks
    , flake-utils
    , rust-overlay
    , crate2nix
    , gomod2nix
    , stoml-src
    , sconfig-src
    , ibc-rs-src
    , gaia4-src
    , gaia5-src
    , cosmos-sdk-src
    }:
    let
      overlays = [
        rust-overlay.overlay
        (final: _: {
          # Because rust-overlay bundles multiple rust packages into one
          # derivation, specify that mega-bundle here, so that crate2nix
          # will use them automatically.
          rustc = final.rust-bin.stable.latest.default;
          cargo = final.rust-bin.stable.latest.default;
        })
        gomod2nix.overlay
      ];
    in
    with flake-utils.lib;
    eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system overlays; };
      evalPkgs = import nixpkgs { system = "x86_64-linux"; inherit overlays; };
      # Note: below is the only use of eval pkgs. This is due to an issue with import from
      # derivation (IFD), which requires nix derivations to be built at evaluation time.
      # Since we can't build on all system types (`utils.eachDefaultSystem` requires us
      # to evaluate all possible systems) we need to pick a system for building during
      # evaluation. With proper caching this flake should still work for running on all
      # system types.
      #
      # Github Issue: https://github.com/NixOS/nix/issues/4265
      generateCargoNix = (import "${crate2nix}/tools.nix" { pkgs = evalPkgs; }).generatedCargoNix;
      goProjectSrcs = {
        gaia5 = { inputName = "gaia5-src"; storePath = "${gaia5-src}"; };
        gaia4 = { inputName = "gaia4-src"; storePath = "${gaia4-src}"; };
        stoml = {
          inputName = "stoml-src";
          storePath = "${stoml-src}";
        };
        sconfig = {
          inputName = "sconfig-src";
          storePath = "${sconfig-src}";
        };
        cosmovisor = {
          inputName = "cosmos-sdk-src";
          storePath = "${cosmos-sdk-src}/cosmovisor";
        };
        cosmos-sdk = { inputName = "cosmos-sdk-src"; storePath = "${cosmos-sdk-src}"; };
      };
    in
    rec {
      # nix build .#<app>
      packages = flattenTree
        {
          stoml = (import ./stoml) { inherit pkgs stoml-src; };
          sconfig = (import ./sconfig) { inherit pkgs sconfig-src; };
          gm = (import ./gm) { inherit pkgs ibc-rs-src; };
          stoml = (import ./stoml) { inherit pkgs stoml-src; };
          sconfig = (import ./sconfig) { inherit pkgs sconfig-src; };
          hermes = (import ./hermes) { inherit pkgs ibc-rs-src generateCargoNix; };
          cosmovisor = (import ./cosmovisor) {
            inherit pkgs;
            cosmovisor-src = goProjectSrcs.cosmovisor.storePath;
          };
          cosmos-sdk = (import ./cosmos-sdk) {
            inherit pkgs;
            cosmos-sdk-src =
              # We need a version of cosmos-sdk with no cosmovisor
              # since buildGoApplication doesn't know how to handle
              # sub-applications
              pkgs.stdenv.mkDerivation {
                name = "cosmos-sdk-no-cosmovisor";
                unpackPhase = "true";
                buildPhase = "true";
                installPhase = ''
                  mkdir -p $out

                  for x in ${cosmos-sdk-src}/*; do
                    if [ $x = "${cosmos-sdk-src}/cosmovisor" ]
                      then continue
                      else cp -r $x $out
                    fi
                  done
                '';
              };
          };
          gaia5 = (import ./gaia5) { inherit gaia5-src pkgs; };
          gaia4 = (import ./gaia4) { inherit gaia4-src pkgs; };
        };

      # nix flake check
      checks = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            nix-linter.enable = true;
          };
        };
      } // packages; # adding packages here ensures that every attr gets built on check

      # nix develop
      devShell =
        let
          syncGoModulesInputs = with builtins; concatStringsSep " "
            (attrValues (builtins.mapAttrs (name: value: "${name}:${value.inputName}${value.storePath}") goProjectSrcs));
          syncGoModulesScript = pkgs.writeShellScriptBin "syncGoModules" ''
            echo "${syncGoModulesInputs}" | ./syncGoModules.hs
          '';
        in
        pkgs.mkShell {
          shellHook = self.checks.${system}.pre-commit-check.shellHook;
          nativeBuildInputs = with pkgs; [
            rustc
            cargo
            pkg-config
          ];
          buildInputs = with pkgs; [
            # need to prefix with pkgs because of they shadow the name of inputs
            pkgs.crate2nix
            pkgs.gomod2nix

            openssl
            syncGoModulesScript
            shellcheck

            # gaia manager dependencies
            packages.stoml
            packages.sconfig
            gnused
          ] ++ builtins.attrValues packages;
        };

      # nix run .#<app>
      apps = {
        hermes = mkApp { name = "hermes"; drv = packages.hermes; };
        gaia = mkApp { name = "gaia"; drv = packages.gaia5; exePath = "/bin/gaiad"; };
        gaia4 = mkApp { name = "gaia"; drv = packages.gaia4; exePath = "/bin/gaiad"; };
        gaia5 = mkApp { name = "gaia"; drv = packages.gaia5; exePath = "/bin/gaiad"; };
        cosmovisor = mkApp { name = "cosmovisor"; drv = packages.cosmovisor; };
        simd = mkApp { name = "simd"; drv = packages.cosmos-sdk; };
        stoml = mkApp { name = "stoml"; drv = packages.stoml; };
        sconfig = mkApp { name = "sconfig"; drv = packages.sconfig; };
        gm = mkApp { name = "gm"; drv = packages.gm; };
      };
    });
}
