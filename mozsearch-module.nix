# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Provides a NixOS module to serve a mozsearch index.
#
# Ideally ports should be configurable and codesearch should have its own
# systemd unit instead of being started by the router.
#
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.mozsearch;

  router = "${getBin cfg.mozsearch-router}/bin/router";
  served-by-router = [
    "search"
    "sorch"
    "define"
  ];

  web-server = "${getBin cfg.mozsearch-tools}/bin/web-server";
  served-by-rust-server = [
    "diagnostics"
    "diff"
    "olddiff"
    "commit"
    "oldcommit"
    "rev"
    "hgrev"
    "oldrev"
    "complete"
    "commit-info"
  ];

  pipeline-server = "${getBin cfg.mozsearch-tools}/bin/pipeline-server";
  served-by-pipeline-server = [
    "query"
  ];
in {
  options.services.mozsearch = {
    enable = mkEnableOption "Mozsearch Instance";

    virtualHost = mkOption {
      type = types.str;
      example = "mozsearch.example.org";
    };

    docroot = mkOption {
      type = types.package;
    };

    config = mkOption {
      type = types.package;
    };

    mozsearch-tools = mkOption {
      type = types.package;
    };

    mozsearch-router = mkOption {
      type = types.package;
    };

    mozsearch-static = mkOption {
      type = types.path;
    };
  };

  config = mkIf cfg.enable {
    systemd.services = {
      mozsearch-router = {
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${router} ${cfg.config} %T/status.txt";
          DynamicUser = true;
        };
      };

      mozsearch-rust-server = {
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${web-server} ${cfg.config} %T/status.txt";
          DynamicUser = true;
        };
      };

      mozsearch-pipeline-server = {
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          Type = "exec";
          ExecStart = "${pipeline-server} ${cfg.config}";
          DynamicUser = true;
        };
      };
    };

    services.nginx = {
      enable = true;

      virtualHosts.${cfg.virtualHost} = {
        extraConfig = ''
          error_page 404 /static/html/404.html;
        '';
        locations =
          {
            "= /" = {
              alias = "${cfg.docroot}/help.html";
              extraConfig = ''
                add_header Cache-Control "must-revalidate";
              '';
            };

            "= /index.html" = {
              alias = "${cfg.docroot}/help.html";
              extraConfig = ''
                add_header Cache-Control "must-revalidate";
              '';
            };

            "= /robots.txt" = {
              root = cfg.mozsearch-static;
              extraConfig = ''
                add_header Cache-Control "public";
                expires 1d;
              '';
            };

            "= /tree-list.js" = {
              root = cfg.docroot;
              tryFiles = "$uri =404";
              extraConfig = ''
                add_header Cache-Control "must-revalidate";
              '';
            };

            "/static/".alias = "${cfg.mozsearch-static}/";
            "~ ^/[^/]+/static/(?<filename>.*)$".alias = "${cfg.mozsearch-static}/$filename";
            "~ ^/[^/]+/source" = {
              root = cfg.docroot;
              tryFiles = "/file/$uri /dir/$uri/index.html =404";
              extraConfig = ''
                types { }
                default_type text/html;
                add_header Cache-Control "must-revalidate";
                gzip_static always;
                gunzip on;
              '';
            };
            "~ ^/[^/]+/raw-analysis/" = {
              root = cfg.docroot;
              tryFiles = "/raw-analysis/$uri =404";
              extraConfig = ''
                types { }
                default_type text/plain;
                add_header Cache-Control "must-revalidate";
                gzip_static always;
                gunzip on;
              '';
            };
            "~ ^/[^/]+/raw/" = {
              root = cfg.docroot;
              tryFiles = "/raw/$uri =404";
              extraConfig = ''
                types { }
                default_type text/plain;
                add_header Cache-Control "must-revalidate";
                gzip_static always;
                gunzip on;
              '';
            };
          }
          // pkgs.lib.mergeAttrsList (map (route: {"~ ^/[^/]+/${route}".proxyPass = "http://127.0.0.1:8000";}) served-by-router)
          // pkgs.lib.mergeAttrsList (map (route: {"~ ^/[^/]+/${route}".proxyPass = "http://127.0.0.1:8001";}) served-by-rust-server)
          // pkgs.lib.mergeAttrsList (map (route: {"~ ^/[^/]+/${route}".proxyPass = "http://127.0.0.1:8002";}) served-by-pipeline-server);
      };
    };
  };
}
