{
  description = "DDBM Unified - Umbrella Project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

        # Build the Elixir release using mixRelease
        # mixRelease handles fetching dependencies from mix.lock automatically
        ddbm = pkgs.beamPackages.mixRelease {
          pname = "ddbm";
          version = "0.1.0";

          src = ./.;

          # mixRelease will fetch dependencies from mix.lock automatically
          # No need for mixNixDeps or mix2nix

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

        # NixOS module
        nixosModules.default = import ./nixos-module.nix;
      }
    ) // {
      # Make overlay available
      overlays.default = overlay;
    };
}
