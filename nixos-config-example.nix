# Add to your NixOS flake.nix

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ddbm.url = "path:/etc/nixos/ddbm";
  };

  outputs = { nixpkgs, ddbm, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        ddbm.nixosModules.default
        {
          services.ddbm = {
            enable = true;
            host = "0.0.0.0";
            port = 4000;
            openFirewall = true;
            environmentFile = "/etc/ddbm/secrets.env";
          };
        }
      ];
    };
  };
}
