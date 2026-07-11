# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Builds a mozsearch index of Qt.
#
{
  lib,
  runCommandLocal,
  qt6,
  fetchgit,
  runCommand,
  buildMozsearchIndex,
  mozsearchStdenv,
  libsysprof-capture,
  libdeflate,
  python3,
  lerc,
  wayland-scanner,
}: let
  rev = "34e6afee8836e067a717359232b9569788a31722";
  hash = "sha256-PVHmNkAHNqHV8vAordRRYesdvJKSjizJRuhfh/bgL9w=";

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
#     "qtwebengine"
#     "qtwebview"
  ];

  qt-git = fetchgit {
    inherit rev hash;
    url = "git://code.qt.io/qt/qt5.git";
    fetchSubmodules = true;
    deepClone = true;
    leaveDotGit = true;
  };

  qt-src = runCommand "qt-src" {} ''
    mkdir -p $out
    cp -r ${qt-git}/* $out
  '';

  mergeDeps = kind: builtins.filter (dep: !((builtins.isAttrs dep) && (lib.hasPrefix "qt" dep.name))) (lib.flatten (map (name: qt6.${name}.${kind}) qt-modules));

  qt-analyzed = mozsearchStdenv.mkDerivation {
    pname = "qt";
    version = rev;

    src = qt-src;

    buildInputs = mergeDeps "buildInputs" ++ [
      libdeflate
      libsysprof-capture
      lerc
    ];
    nativeBuildInputs = mergeDeps "nativeBuildInputs" ++ [
      python3
      wayland-scanner
    ];
    propagatedBuildInputs = mergeDeps "propagatedBuildInputs";

    cmakeFlags = [
      "-DFEATURE_developer_build=ON"
      "-DBUILD_qtwebengine=OFF"
      "-DBUILD_qtwebview=OFF"
      "-DQT_BUILD_TESTS=ON"
      "-DQT_BUILD_EXAMPLES=ON"
      "-DWARNINGS_ARE_ERRORS=OFF"
    ];

    doCheck = false;

    __structuredAttrs = true;
    strictDeps = true;
  };
in
  buildMozsearchIndex {
    index-name = "qt";
    src = qt-src;
    inherit (qt-analyzed) generated analysis;
    codesearch-port = 8090;
  }
