{
  description = "DDBM Unified - Umbrella Project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay to add our package to nixpkgs
      overlay = final: prev: {
        ddbm = self.packages.${final.system}.default;
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Fetch Mix dependencies first
        mixDeps = pkgs.beamPackages.fetchMixDeps {
          pname = "ddbm-mix-deps";
          version = "0.1.0";
          src = ./.;
          # This hash will need to be updated when mix.lock changes
          hash = sha256-wVzH1vpx28QZIhZAgj4Bkq9VOU+gWbuQvzwOG5lAq1U=;
        };

        # Build the Elixir release using mixRelease
        ddbm = pkgs.beamPackages.mixRelease {
          pname = "ddbm";
          version = "0.1.0";

          src = ./.;

          # Use the fetched dependencies
          mixFodDeps = mixDeps;

          # Build assets as part of the release
          preBuild = ''
            mix do --app ddbm_web assets.deploy
          '';

          # Environment needed for build
          buildInputs = with pkgs; [
            nodejs_20
            sqlite
          ];

          # Pass through for runtime
          passthru = {
            # Expose the module for NixOS configuration
            nixosModule = import ./nixos-module.nix;
          };
        };
      in
      {
        packages = {
          default = ddbm;
          ddbm = ddbm;
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
            erlang
            nodejs_20
            sqlite
          ];

          shellHook = ''
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex

            echo "DDBM development environment"
            echo "Run 'mix setup' to get started"
          '';
        };
      }
    ) // {
      # Make overlay and NixOS module available at top-level
      overlays.default = overlay;

      # NixOS module that automatically provides the package
      nixosModules.default = { config, lib, pkgs, ... }: {
        imports = [ ./nixos-module.nix ];

        # Automatically set the package to the one from this flake
        config = lib.mkIf config.services.ddbm.enable {
          services.ddbm.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      };
    };
}
