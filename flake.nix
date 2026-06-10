{
  description = "hyprexpo - Hyprland workspace overview plugin";

  inputs = {
    hyprland.url = "github:hyprwm/Hyprland";
    nixpkgs.follows = "hyprland/nixpkgs";
    systems.follows = "hyprland/systems";
  };

  outputs = { self, hyprland, nixpkgs, systems, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (import systems);
    in {
      packages = forAllSystems (system: {
        hyprexpo = nixpkgs.legacyPackages.${system}.callPackage ./default.nix {
          inherit (hyprland.packages.${system}) hyprland;
          hyprlandPlugins = hyprland.packages.${system};
        };
        default = self.packages.${system}.hyprexpo;
      });
    };
}
