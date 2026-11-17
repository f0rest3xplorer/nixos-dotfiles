{
   description = "My NixOS Config";

   inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      home-manager.url = "github:nix-community/home-manager";
   };

   outputs = { self, nixpkgs, home-manager, ... }: {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
               home-manager.useGlobalPkgs = true;
               home-manager.useUserPackages = true;
               home-manager.users.f0rest3xplorer = import ./home.nix;
            }
         ];
      };
   };
}
