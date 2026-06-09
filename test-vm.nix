# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Builds a test VM to expose the Qt index.
#
{
  nixpkgs,
  system,
  mozsearch-module,
  mozsearch-tools,
  mozsearch-router,
  mozsearch-static,
  docroot,
  config,
}: let
  virtualHost = "localhost";
in
  nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      mozsearch-module
      {
        services.mozsearch = {
          enable = true;
          inherit mozsearch-tools mozsearch-router mozsearch-static docroot config virtualHost;
        };
      }

      {
        imports = ["${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"];
        system.stateVersion = "26.11";

        services.nginx = {
          recommendedTlsSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;

          virtualHosts.${virtualHost}.default = true;
        };

        networking.firewall.allowedTCPPorts = [80];
      }
    ];
  }
