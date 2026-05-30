{
  description = "Pi Coding Agent packaged for Nix, with a home-manager module for declarative npm modules.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (system: rec {
        pi-coding-agent = (pkgsFor system).callPackage ./default.nix { };
        default = pi-coding-agent;
      });

      overlays.default = final: _prev: {
        pi-coding-agent = final.callPackage ./default.nix { };
      };

      homeManagerModules = {
        pi-coding-agent = ./home-manager.nix;
        default = ./home-manager.nix;
      };

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
