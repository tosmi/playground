{
  description = "Playground Tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.bashInteractive
            pkgs.yamllint

            pkgs.kustomize
            pkgs.argocd
            pkgs.kubernetes-helm

            pkgs.ansible
            pkgs.ansible-lint
            # required for kubernetes collection
            pkgs.python312Packages.kubernetes
          ];
        };
      });
}
