# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Provides a build env with the mozsearch clang plugin.
#
# Ideally MOZSEARCH_SOURCE_DIR and MOZSEARCH_BUILD_DIR should be configurable
# because their location depends on the build system and build script.
#
{
  lib,
  mozsearch-clang-plugin,
  overrideMkDerivationArgs,
}: let
  flags = [
    "-load"
    "${mozsearch-clang-plugin}/lib/libclang-index-plugin.so"
    "-add-plugin"
    "mozsearch-index"
    "-plugin-arg-mozsearch-index"
    "$MOZSEARCH_SOURCE_DIR"
    "-plugin-arg-mozsearch-index"
    "$MOZSEARCH_ANALYSIS_DIR"
    "-plugin-arg-mozsearch-index"
    "$MOZSEARCH_BUILD_DIR"
    "-fparse-all-comments"
  ];
  clangFlags = ["-Xclang"] ++ lib.intersperse "-Xclang" flags;
in
  overrideMkDerivationArgs (oldAttrs: {
    preBuild =
      (oldAttrs.preBuild or "")
      + ''
        export MOZSEARCH_SOURCE_DIR="$NIX_BUILD_TOP/$sourceRoot"
        export MOZSEARCH_ANALYSIS_DIR="$NIX_BUILD_TOP/analysis"
        export MOZSEARCH_BUILD_DIR="$NIX_BUILD_TOP/$sourceRoot/build"
        export NIX_CFLAGS_COMPILE+=" ${toString clangFlags}"
      '';

    outputs = (oldAttrs.outputs or ["out"]) ++ ["analysis" "generated"];

    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        if [ -d $MOZSEARCH_ANALYSIS_DIR ]; then
          cp -r $MOZSEARCH_ANALYSIS_DIR $analysis
        else
          mkdir -p $analysis
        fi

        mkdir -p $generated
        if [ -d $MOZSEARCH_ANALYSIS_DIR/__GENERATED__ ]; then
          pushd $MOZSEARCH_ANALYSIS_DIR/__GENERATED__
          for dir in $(find -type d); do
            mkdir -p $generated/$dir
          done
          for file in $(find -type f); do
            cp $MOZSEARCH_BUILD_DIR/$file $generated/$file
          done
          popd
        fi
      '';
  })
  mozsearch-clang-plugin.stdenv
