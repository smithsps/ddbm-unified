{
  description = "DDBM Unified - Umbrella Project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        mixDeps = pkgs.beamPackages.fetchMixDeps {
          pname = "ddbm-mix-deps";
          version = "0.1.0";
          src = ./.;
          hash = "sha256-wVzH1vpx28QZIhZAgj4Bkq9VOU+gWbuQvzwOG5lAq1U=";
        };

        npmDeps = pkgs.fetchNpmDeps {
          src = ./apps/ddbm_web/assets;
          hash = "sha256-HW6o8pzFwJ85sOaDEbNk+eoNhHJmpteAnbdTVEuyREs=";
        };

        commonInputs = with pkgs; [
          nodejs_20
          sqlite
        ];
      in
      {
        packages.default = pkgs.beamPackages.mixRelease {
          pname = "ddbm";
          version = "0.1.0";
          src = ./.;
          mixFodDeps = mixDeps;

          preBuild = ''
            export npm_config_cache=${npmDeps}
            cd apps/ddbm_web/assets
            npm ci --offline
            cd ../../..
            patchShebangs apps/ddbm_web/assets/node_modules
            mix do --app ddbm_web assets.deploy.nix
          '';

          buildInputs = commonInputs;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
            erlang
          ] ++ commonInputs;

          shellHook = ''
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            echo "DDBM development environment"
            echo "Run 'mix setup' to get started"
          '';
        };
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }: {
        imports = [ ./nixos-module.nix ];

        config = lib.mkIf config.services.ddbm.enable {
          services.ddbm.package = lib.mkDefault self.packages.${pkgs.system}.default;
        };
      };
    };
}
