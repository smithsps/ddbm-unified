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

          # Ensure all Nix-built dependencies are available in deps/
          postConfigure = ''
            # Create deps directory and populate with all Nix-built dependencies
            echo "Setting up Nix-built dependencies..."
            rm -rf deps
            mkdir -p deps
            ${pkgs.lib.concatMapStringsSep "\n" (dep: ''
              depName="${dep}"
              # Nix BEAM packages are structured as /nix/store/.../lib/erlang/lib/<name>-<version>
              # We need to find the actual versioned directory
              storePath="${mixNixDeps.${dep}}"
              if [ -d "$storePath/lib/erlang/lib" ]; then
                # This is a properly structured BEAM package
                depPath=$(find "$storePath/lib/erlang/lib" -maxdepth 1 -name "${dep}-*" -type d | head -1)
                if [ -n "$depPath" ] && [ -d "$depPath" ]; then
                  echo "Linking $depName from $depPath"
                  ln -sfn "$depPath" "deps/$depName"
                else
                  echo "Warning: Could not find versioned dir for dependency: $depName in $storePath/lib/erlang/lib"
                fi
              elif [ -d "$storePath" ]; then
                # Direct store path (like heroicons from git)
                echo "Linking $depName directly from $storePath"
                ln -sfn "$storePath" "deps/$depName"
              else
                echo "Warning: Could not find dependency: $depName at $storePath"
              fi
            '') (builtins.attrNames mixNixDeps)}
          '';

          postBuild = ''
            # Link dependencies with overridden binaries for the build
            # Use -n flag to treat symlink destinations as normal files
            ln -sfnv ${mixNixDeps.heroicons} deps/heroicons
            ln -sfnv ${mixNixDeps.tailwind} deps/tailwind
            ln -sfnv ${mixNixDeps.esbuild} deps/esbuild

            # Create node_modules in assets directory for esbuild to find Phoenix JS packages
            echo "Setting up node_modules for esbuild..."
            mkdir -p apps/ddbm_web/assets/node_modules

            # Symlink Phoenix JavaScript packages from Nix store src directories
            # Nix BEAM packages have package.json in the src/ subdirectory
            ln -sfn ${mixNixDeps.phoenix}/src apps/ddbm_web/assets/node_modules/phoenix
            ln -sfn ${mixNixDeps.phoenix_html}/src apps/ddbm_web/assets/node_modules/phoenix_html
            ln -sfn ${mixNixDeps.phoenix_live_view}/src apps/ddbm_web/assets/node_modules/phoenix_live_view

            # Also need morphdom dependency for phoenix_live_view
            # Extract it from the phoenix_live_view source assets if it exists
            if [ -d "${mixNixDeps.phoenix_live_view}/src/assets/node_modules/morphdom" ]; then
              ln -sfn ${mixNixDeps.phoenix_live_view}/src/assets/node_modules/morphdom apps/ddbm_web/assets/node_modules/morphdom
            fi


            # Build assets using Nix-provided tailwind and esbuild
            mix do \
              app.config --no-deps-check --no-compile, \
              assets.deploy --no-deps-check
          '';

          # Override installPhase to work around Mix dependency validation
          installPhase = ''
            runHook preInstall

            echo "Building release with Nix-provided dependencies..."

            # Force Mix to load dependency paths without validation
            # then build the release
            mix do deps.loadpaths --no-deps-check, release --path "$out" --overwrite

            runHook postInstall
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
