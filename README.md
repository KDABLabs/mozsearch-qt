<!--
SPDX-FileCopyrightText: 2026 KDAB
SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>

SPDX-License-Identifier: MIT
-->

# Qt index based on Mozsearch

Mozsearch is the name of the software behind Searchfox. It consists of:

- a set of analyzers, in our case we're interested in its Clang plugin
- a number of Rust programs which ingest the source and its analysis to build
  the index
- a set of 5 server components to serve the index:
  - Nginx serves the static content and proxies the other components
  - a Python router handles searching, and proxies to codesearch for full-text
    search
  - codesearch (from livegrep.com) handle full-text search
  - a Rust web-server handles a number of endpoints related to history
  - a Rust pipeline-server handles more complex queries like graphs

See upstream docs at https://firefox-source-docs.mozilla.org/contributing/searchfox.html.

TL;DR, with nothing more than Nix installed:
```sh
RESULT=$(nix build github:KDABLabs/mozsearch-qt#nixosConfigurations.test-vm.config.system.build.vm --print-out-paths --no-link)
QEMU_NET_OPTS=hostfwd=tcp:127.0.0.1:8080-:80 $RESULT/bin/run-nixos-vm &
nix shell nixpkgs#xdg-utils --command xdg-open http://127.0.0.1:8080/qt/source
```

For more details, see each .nix file, the entry point is flake.nix.
