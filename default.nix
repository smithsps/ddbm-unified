# Traditional Nix build file
# For use with nix-build or importing into NixOS configuration
#
# Usage:
#   nix-build
#   nix-build --arg pkgs 'import <nixpkgs> { system = "aarch64-linux"; }'

{ pkgs ? import <nixpkgs> {} }:

pkgs.beamPackages.mixRelease {
  pname = "ddbm";
  version = "0.1.0";

  src = ./.;

  # mixRelease automatically fetches dependencies from mix.lock
  # No need for manual dependency management

  # Build assets before release
  preBuild = ''
    mix do --app ddbm_web assets.deploy
  '';

  # Dependencies needed for build
  buildInputs = with pkgs; [
    nodejs_20
    sqlite
  ];
}
