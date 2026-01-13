{
  description = "I'm sure that this isn't a game engine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-overlay.url = "github:zigtools/zls";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, zls-overlay } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        zig = zig-overlay.packages.${system}.master;
        zls = zls-overlay.packages.${system}.zls;

      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zig
            zls
          ];

          shellHook = ''
            echo "NEngine Environment Loaded"
            echo "zig version: $(zig version)"
            echo "zls version: $(zls --version)"
          '';
        };
      }
    );
}
