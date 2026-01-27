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

        mixNixDeps = pkgs.callPackages ./deps.nix {
          overrides = (final: prev: {
            nostrum = prev.nostrum.overrideAttrs (old: {
              postPatch = ''
                substituteInPlace mix.exs \
                  --replace-quiet 'compilers: Mix.compilers() ++ [:appup],' 'compilers: Mix.compilers(),'
              '';
            });

            # Provide Nix-managed tailwindcss and esbuild binary to avoid downloads
            tailwind = prev.tailwind.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                mkdir -p $out/bin
                ln -sf ${pkgs.tailwindcss_4}/bin/tailwindcss $out/bin/tailwindcss
              '';
            });
            esbuild = prev.esbuild.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                mkdir -p $out/bin
                ln -sf ${pkgs.esbuild}/bin/esbuild $out/bin/esbuild
              '';
            });
          });
        };
      in
      {
        packages.default = pkgs.beamPackages.mixRelease {
          inherit mixNixDeps;
          pname = "ddbm";
          version = "0.1.0";
          src = ./.;

          postBuild = ''
            # Link dependencies with overridden binaries for the build
            # Use -n flag to treat symlink destinations as normal files
            ln -sfnv ${mixNixDeps.heroicons} deps/heroicons
            ln -sfnv ${mixNixDeps.tailwind} deps/tailwind
            ln -sfnv ${mixNixDeps.esbuild} deps/esbuild

            # Build assets using Nix-provided tailwind and esbuild
            mix do \
              app.config --no-deps-check --no-compile, \
              assets.deploy --no-deps-check
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
