# Nix Build Solution for Phoenix Umbrella with deps_nix

## Problem Summary

When building a Phoenix umbrella project with Nix using `deps_nix` and `beamPackages.mixRelease`, two main issues occurred:

1. **Dependency lock mismatches**: Nix-built BEAM packages have different checksums than Hex packages
2. **JavaScript bundling failures**: esbuild couldn't resolve Phoenix JavaScript modules (phoenix, phoenix_html, phoenix_live_view)

## Root Causes

### Issue 1: Dependency Checksum Mismatches

Nix's `beamPackages.buildMix` builds dependencies from source and installs them in a structured format:
```
/nix/store/<hash>-<package>-<version>/
├── lib/erlang/lib/<package>-<version>/  # Compiled BEAM code
│   ├── ebin/                             # Compiled .beam files
│   └── priv/                             # Resources
└── src/                                   # Original source code
    ├── package.json                       # For JS packages
    └── ...
```

Mix's `mix release` task validates dependencies against `mix.lock` checksums, which don't match Nix-built packages.

### Issue 2: esbuild Module Resolution

Phoenix packages include JavaScript code in their source directories. When building with Nix:
- Dependencies are symlinked to `deps/<package>` → `/nix/store/.../lib/erlang/lib/<package>-<version>/`
- This directory only contains compiled code (`ebin/`, `priv/`)
- The `package.json` and JavaScript source files are in `/nix/store/.../src/`
- esbuild couldn't find the JavaScript modules

## Solution

### 1. Symlink All Dependencies in postConfigure

Create symlinks for all Nix-built dependencies, handling both standard BEAM packages and git dependencies:

```nix
postConfigure = ''
  echo "Setting up Nix-built dependencies..."
  rm -rf deps
  mkdir -p deps
  ${pkgs.lib.concatMapStringsSep "\n" (dep: ''
    depName="${dep}"
    storePath="${mixNixDeps.${dep}}"
    if [ -d "$storePath/lib/erlang/lib" ]; then
      # Standard BEAM package
      depPath=$(find "$storePath/lib/erlang/lib" -maxdepth 1 -name "${dep}-*" -type d | head -1)
      if [ -n "$depPath" ] && [ -d "$depPath" ]; then
        ln -sfn "$depPath" "deps/$depName"
      fi
    elif [ -d "$storePath" ]; then
      # Direct dependency (e.g., heroicons from git)
      ln -sfn "$storePath" "deps/$depName"
    fi
  '') (builtins.attrNames mixNixDeps)}
'';
```

### 2. Create node_modules with Source Symlinks for esbuild

In `postBuild`, create a `node_modules` directory that symlinks to the Phoenix package source directories where `package.json` files are located:

```nix
postBuild = ''
  # Re-link overridden dependencies (tailwind, esbuild, heroicons)
  ln -sfnv ${mixNixDeps.heroicons} deps/heroicons
  ln -sfnv ${mixNixDeps.tailwind} deps/tailwind
  ln -sfnv ${mixNixDeps.esbuild} deps/esbuild

  # Create node_modules for esbuild module resolution
  # Symlink to src/ directories where package.json files are located
  mkdir -p apps/ddbm_web/assets/node_modules
  ln -sfn ${mixNixDeps.phoenix}/src apps/ddbm_web/assets/node_modules/phoenix
  ln -sfn ${mixNixDeps.phoenix_html}/src apps/ddbm_web/assets/node_modules/phoenix_html
  ln -sfn ${mixNixDeps.phoenix_live_view}/src apps/ddbm_web/assets/node_modules/phoenix_live_view

  # Include morphdom dependency for phoenix_live_view
  if [ -d "${mixNixDeps.phoenix_live_view}/src/assets/node_modules/morphdom" ]; then
    ln -sfn ${mixNixDeps.phoenix_live_view}/src/assets/node_modules/morphdom apps/ddbm_web/assets/node_modules/morphdom
  fi

  # Build assets
  mix do \
    app.config --no-deps-check --no-compile, \
    assets.deploy --no-deps-check
'';
```

### 3. Override installPhase to Skip Dependency Validation

Use `mix do deps.loadpaths --no-deps-check, release` to load dependency paths without validation, then build the release:

```nix
installPhase = ''
  runHook preInstall

  # Load dependency paths without validation, then build release
  mix do deps.loadpaths --no-deps-check, release --path "$out" --overwrite

  runHook postInstall
'';
```

## Key Insights

1. **Nix BEAM package structure**: Compiled code is in `lib/erlang/lib/<name>-<version>/`, source is in `src/`
2. **esbuild resolution**: esbuild uses standard Node.js module resolution (node_modules), not NODE_PATH
3. **Mix dependency validation**: `--no-deps-check` flag only works for some Mix tasks; use `deps.loadpaths --no-deps-check` before `mix release`

## Result

The build now successfully:
- ✅ Compiles all Elixir/Erlang code
- ✅ Builds assets with Tailwind CSS and esbuild
- ✅ Bundles Phoenix JavaScript modules
- ✅ Creates a production release with tarball
- ✅ Includes all static assets with cache-busting hashes

The release is available at `result/` and includes a complete OTP release with ERTS runtime.
