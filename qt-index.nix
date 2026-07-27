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
  git,
  runCommand,
  buildMozsearchIndex,
  buildBlameRepo,
  mozsearchStdenv,
  libsysprof-capture,
  libdeflate,
  python3,
  lerc,
  wayland-scanner,
  livegrep,
  writeText,
}: let
  rev = "34e6afee8836e067a717359232b9569788a31722";
  hash = "sha256-5jjcd7J4WGznYoPiTNzOwxfuIJYGkO5RHW0FuRFHfHg=";

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

  qt-git-unified = runCommand "qt-git-unified" {} ''
    PATH=${git}/bin:$PATH
    HOME=$(mktemp -d)
    git config --global --add safe.directory '*'
    git config --global user.email "mozsearch-qt@localhost"
    git config --global user.name "mozsearch-qt index builder"

    cp -r ${qt-git} $out
    cd $out
    chmod -R u+w $out

    git reset --hard
    SUBMODULES=$(git submodule status | cut -c '2-' | cut -d ' ' -f 2)
    for SUBMODULE in $SUBMODULES; do
      git fetch $SUBMODULE HEAD
      git merge --strategy=ours --no-commit --allow-unrelated-histories FETCH_HEAD
      rm -rf $SUBMODULE
      git read-tree --prefix=$SUBMODULE -u FETCH_HEAD
      git commit -m "Absorb $SUBMODULE submodule"
    done
  '';

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

  index-name = "qt";
  git-branch = "dev";

  qt-blame = buildBlameRepo {
    inherit index-name;
    git-dir = qt-git-unified;
    default-branch = git-branch;
  };

  generated-in-subdir =
    runCommandLocal "generated-in-subdir" {} ''
      mkdir -p $out
      cp -R ${qt-analyzed.generated} $out/__GENERATED__
    '';

  livegrep-index = let
    config = writeText "livegrep.json" (builtins.toJSON {
      name = "Searchfox";
      repositories = {
        name = index-name;
        path = qt-git;
        revisions = [ "HEAD" ];
        walk_submodules = true;
      };

      fs_paths = [
        {
          name = "${index-name}-__GENERATED__";
          path = generated-in-subdir;
        }
      ];
    });
  in
    runCommand "${index-name}-livegrep.idx" {} ''
      HOME=$(mktemp -d)
      ${git}/bin/git config --global --add safe.directory '*'
      ${livegrep}/bin/codesearch '${config}' -dump_index $out -index_only
    '';
in
  buildMozsearchIndex {
    inherit index-name git-branch livegrep-index;
    src = qt-src;
    git-dir = qt-git-unified;
    git-blame = qt-blame;
    inherit (qt-analyzed) analysis;
    generated = generated-in-subdir;
    codesearch-port = 8090;
    help-template = ./help-template.html;
  }
