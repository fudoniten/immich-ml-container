{
  description = "Immich Machine Learning running in a container";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    arion.url = "github:hercules-ci/arion";
  };

  outputs = { self, nixpkgs, arion, ... }: {
    nixosModules = rec {
      default = immichMlContainer;
      immichMlContainer = { ... }: {
        imports = [ arion.nixosModules.arion ./immich-ml-container.nix ];
      };
    };
  };
}
