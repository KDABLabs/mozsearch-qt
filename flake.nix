# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# This uses github.com/mozsearch/mozsearch to index Qt.
#
{
  description = "A Flake for https://github.com/mozsearch/mozsearch";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    mozsearch = {
      url = "git+https://github.com/mozsearch/mozsearch";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.guichard.eu?priority=42"
      "https://searchfox-binary-cache.s3.amazonaws.com?priority=42"
    ];
    extra-trusted-public-keys = [
      "cache.guichard.eu:zcopFhaVCRUtdfkAb7Dlkq9Y2/89nZkL7I0JIoVEoOk="
      "searchfox-binary-cache-1:X2B8qJE4uQJpf42POhKaKf23nlXj+SjifH4OjK7Kgh0="
    ];
  };

  outputs = {
    self,
    nixpkgs,
    mozsearch,
  }: (
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };

      mozsearchPkgs = mozsearch.packages.${system};

      mozsearchStdenv = pkgs.callPackage ./mozsearch-stdenv.nix {
        inherit (mozsearchPkgs) mozsearch-clang-plugin;
      };

      buildMozsearchIndex = pkgs.callPackage ./build-mozsearch-index.nix {
        inherit (mozsearchPkgs) mozsearch-tools;
        mozsearch-src = mozsearch;
      };

      qt-index = pkgs.callPackage ./qt-index.nix {
        inherit mozsearchStdenv buildMozsearchIndex;
      };
    in {
      packages.${system} = {
        qt-docroot = qt-index.docroot;
        qt-config = qt-index.config;
      };

      nixosConfigurations = {
        test-vm = import ./test-vm.nix {
          inherit nixpkgs system;

          inherit (mozsearchPkgs) mozsearch-tools mozsearch-router;
          mozsearch-static = "${mozsearch}/static";
          inherit (qt-index) docroot config;
          mozsearch-module = self.nixosModules.mozsearch;
        };
      };

      nixosModules = {
        mozsearch = import ./mozsearch-module.nix;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          reuse
        ];
      };

      checks.${system} = {
        reuse = pkgs.runCommand "check-reuse" {} ''
          cd ${self}
          ${pkgs.lib.getBin pkgs.reuse}/bin/reuse lint
          touch $out
        '';

        nix-fmt = pkgs.runCommand "check-nix-fmt" {} ''
          ${pkgs.lib.getBin self.formatter.${system}}/bin/${self.formatter.${system}.NIX_MAIN_PROGRAM} -c ${self}/flake.nix
          touch $out
        '';
      };

      formatter.${system} = pkgs.alejandra;
    }
  );
}
