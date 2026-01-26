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

        mixNixDeps = pkgs.callPackages ./deps.nix { };

        # commonInputs = with pkgs; [
        #   nodejs_20
        #   sqlite
        # ];
      in
      {
        packages.default = pkgs.beamPackages.mixRelease {
          inherit mixNixDeps;
          pname = "ddbm";
          version = "0.1.0";
          src = ./.;

          postBuild = ''
            tailwind_path="$(mix do \
              app.config --no-deps-check --no-compile, \
              eval 'Tailwind.bin_path() |> IO.puts()')"
            esbuild_path="$(mix do \
              app.config --no-deps-check --no-compile, \
              eval 'Esbuild.bin_path() |> IO.puts()')"

            ln -sfv ${mixNixDeps.tailwind}/bin/tailwindcss "$tailwind_path"
            ln -sfv ${mixNixDeps.esbuild}/bin/esbuild "$esbuild_path"
            ln -sfv ${mixNixDeps.heroicons} deps/heroicons

            mix do \
              app.config --no-deps-check --no-compile, \
              assets.deploy --no-deps-check
          '';

          #buildInputs = commonInputs;
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
