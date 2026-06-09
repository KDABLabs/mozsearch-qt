# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Builds a mozsearch index of Qt.
#
# This (currently) builds each Qt module separately then merges the indexes
# together using mergeAnalyses and makeSubfolders below. The main downside is
# that #include directives between modules don't get linked.
#
{
  runCommandLocal,
  qt6,
  stdenvNoCC,
  buildMozsearchIndex,
  mozsearchStdenv,
}: let
  mergeAnalyses = trees:
    runCommandLocal "merged-analyses" {
      trees = map ({
        name,
        path,
        ...
      }: "${name}:${path}")
      trees;
    } ''
      mkdir -p $out
      mkdir -p $out/__GENERATED__
      for tree in $trees; do
        IFS=':' read -ra TREE <<< "$tree"
        name=''${TREE[0]}
        path=''${TREE[1]}
        mkdir -p $out/$name
        ln -s $path/* $out/$name
        if [ -e $out/$name/__GENERATED__ ]; then
          unlink $out/$name/__GENERATED__
          ln -s $path/__GENERATED__ $out/__GENERATED__/$name
        fi
        rmdir $out/__GENERATED__ 2> /dev/null || true
      done
    '';

  makeSubfolders = trees:
    runCommandLocal "merged-trees" {
      trees = map ({
        name,
        path,
        ...
      }: "${name}:${path}")
      trees;
    } ''
      mkdir -p $out
      for tree in $trees; do
        IFS=':' read -ra TREE <<< "$tree"
        name=''${TREE[0]}
        path=''${TREE[1]}
        ln -s $path $out/$name
      done
    '';

  qt-analyzed = qt6.overrideScope (qtfinal: qtprev: {
    qtbase = qtprev.qtbase.override {stdenv = mozsearchStdenv;};
    qtModule = qtprev.qtModule.override {stdenv = mozsearchStdenv;};
  });

  qt-module-analysis = name: {
    inherit name;
    path = qt-analyzed.${name}.analysis;
  };
  qt-module-generated = name: {
    inherit name;
    path = qt-analyzed.${name}.generated;
  };
  qt-module-sources = name: {
    inherit name;
    path = stdenvNoCC.mkDerivation {
      name = "${name}-source";
      src = qt-analyzed.${name}.src;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        cp -r . $out
      '';
    };
  };

  qt-modules = [
    "qtbase"

    "qt3d"
    "qt5compat"
    "qtcharts"
    "qtconnectivity"
    "qtdatavis3d"
    "qtdeclarative"
    "qtdoc"
    "qtgraphs"
    "qtgrpc"
    "qthttpserver"
    "qtimageformats"
    "qtlanguageserver"
    "qtlocation"
    "qtlottie"
    "qtmultimedia"
    "qtmqtt"
    "qtnetworkauth"
    "qtpositioning"
    "qtsensors"
    "qtserialbus"
    "qtserialport"
    "qtshadertools"
    "qtspeech"
    "qtquick3d"
    "qtquick3dphysics"
    "qtquickeffectmaker"
    "qtquicktimeline"
    "qtremoteobjects"
    "qtsvg"
    "qtscxml"
    "qttools"
    "qttranslations"
    "qtvirtualkeyboard"
    "qtwayland"
    "qtwebchannel"
    "qtwebsockets"
    # "qtwebengine"
    # "qtwebview"
  ];

  qt-src = makeSubfolders (map qt-module-sources qt-modules);
  qt-generated = makeSubfolders (map qt-module-generated qt-modules);
  qt-analysis = mergeAnalyses (map qt-module-analysis qt-modules);
in
  buildMozsearchIndex {
    index-name = "qt";
    src = qt-src;
    generated = qt-generated;
    analysis = qt-analysis;
    codesearch-port = 8090;
  }
