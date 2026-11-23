{
  description = "defyjoy's NixOS: Niri + Noctalia desktop from defyjoy/.dotfiles, installed with disko";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nixpkgs 26.05 ships Noctalia 5.0.1; pin current upstream to match the CachyOS install.
    # Not following our nixpkgs: upstream builds against nixos-unstable libs.
    noctalia.url = "github:noctalia-dev/noctalia/v5.6.0";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Desktop config source of truth; `nix flake update dotfiles` pulls new commits.
    dotfiles = {
      url = "github:defyjoy/.dotfiles";
      flake = false;
    };
    cachyos-fish-config = {
      url = "github:CachyOS/cachyos-fish-config";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, disko, noctalia, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        noctalia.nixosModules.default
        ./disko.nix
        ./hardware-configuration.nix
        ./configuration.nix
        ./desktop.nix
        ./gpu.nix # imports ./nvidia.nix only on machines install.sh found an NVIDIA GPU in
      ];
    };
  };
}
