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
          overlays = [(final: prev: {
            # https://github.com/NixOS/nixpkgs/issues/267864
            awscli2 = prev.awscli2.overrideAttrs (oldAttrs: {
              nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.makeWrapper ];
              doCheck = false;
              postInstall = ''
                ${oldAttrs.postInstall}
                wrapProgram $out/bin/aws --set PYTHONPATH=
              '';
            });
          })];
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
            (kubernetes-helm-wrapped.override { plugins = with kubernetes-helmPlugins; [ helm-diff ]; })
            helmfile-wrapped
            just
          ];
        };
      });
}

