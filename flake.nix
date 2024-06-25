{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

      in
      {
        devShells.default = with pkgs; mkShell {
          name = "nix-bazel-infra";
          packages = [
            terraform
            ansible
            kubectl
            awscli2
            kubernetes-helm
            helmfile
            just
          ];
        };
      });
}

