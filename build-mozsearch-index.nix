# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# This transforms analysis data into an actual index, with crossref data, and
# generates static pages.
#
# Eventually this should support indexing a Git repository, with blame and test
# coverage data. But I haven't yet figured out how to incrementally build the
# blame and coverage data, we don't want to start from scratch on each run.
#
{
  runCommand,
  runCommandLocal,
  symlinkJoin,
  writeText,
  livegrep,
  mozsearch-src,
  mozsearch-tools,
  parallel,
  envsubst,
}: {
  index-name,
  src,
  generated,
  analysis,
  codesearch-port,
}: let
  makeGeneratedSubdir = dir:
    runCommandLocal "with-generated-subdir" {} ''
      mkdir -p $out
      ln -s ${dir} $out/__GENERATED__
    '';

  listFiles = root:
    runCommandLocal "${root.name}-file-list" {} ''
      cd ${root}
      find -L -mindepth 1 -type f -printf '%P\n' > $out
    '';

  listDirs = root:
    runCommandLocal "${root.name}-dir-list" {} ''
      cd ${root}
      find -L -mindepth 1 -type d -printf '%P\n' > $out
    '';

  all-files-symlinks = symlinkJoin {
    name = "${index-name}-all-files";
    paths = [src (makeGeneratedSubdir generated)];
  };

  all-files = runCommandLocal "${index-name}-all-files-without-symlinks" {} ''
    cp -rL ${all-files-symlinks} $out
  '';

  src-files-list = listFiles src;
  obj-files-list = listFiles generated;
  all-files-list = listFiles all-files;
  analysis-files-list = listFiles analysis;
  all-dirs-list = listDirs all-files;

  livegrep-index = let
    config = writeText "livegrep.json" (builtins.toJSON {
      name = "Searchfox";
      fs_paths = [
        {
          name = index-name;
          path = all-files;
        }
      ];
    });
  in
    runCommandLocal "${index-name}-livegrep.idx" {} ''
      ${livegrep}/bin/codesearch '${config}' -dump_index $out -index_only
    '';

  mkConfig = {
    index,
    codesearch-port,
  }: let
    config = {
      trees = {
        ${index-name} = {
          priority = 1;
          on_error = "halt";
          cache = "nothing";
          files_path = all-files;
          objdir_path = "${all-files}/__GENERATED__";
          index_path = index;
          codesearch_path = livegrep-index;
          codesearch_port = codesearch-port;
        };
      };
      mozsearch_path = mozsearch-src;
      config_repo = "";
    };
  in
    writeText "config.json" (builtins.toJSON config);

  pwd-config = mkConfig {
    index = ".";
    codesearch-port = 8081;
  };

  crossref-cmd = "${mozsearch-tools}/bin/crossref";
  searchfox-tool-cmd = "SEARCHFOX_SERVER=${pwd-config} SEARCHFOX_TREE=${index-name} ${mozsearch-tools}/bin/searchfox-tool";
  output-file-cmd = "${mozsearch-tools}/bin/output-file";
  parallel-cmd = "${parallel}/bin/parallel --will-cite";
  envsubst-cmd = "${envsubst}/bin/envsubst";

  empty-dir-tree = runCommandLocal "${index-name}-empty-dir-tree" {} ''
    mkdir -p $out
    cd $out
    ${parallel-cmd} --halt now,fail=1 "mkdir -p {}" < ${all-dirs-list}
  '';

  mkDirTree = subdir: "cp --no-preserve=mode -r ${empty-dir-tree} ${subdir}";

  crossref = runCommand "${index-name}-crossref" {} ''
    ln -s ${analysis} analysis
    ln -s ${all-files-list} all-files
    ln -s ${all-dirs-list} all-dirs

    ${mkDirTree "description"}

    ${crossref-cmd} '${pwd-config}' '${index-name}' '${analysis-files-list}' "$NIX_BUILD_CORES"

    mkdir -p $out
    cp -r concise-per-file-info.json crossref crossref-extra detailed-per-file-info detailed-per-dir-info jumpref jumpref-extra description $out
    LC_ALL=C sort -f identifiers > $out/identifiers
  '';

  url-map = writeText "url-map.json" (builtins.toJSON {});
  doc-trees = writeText "doc-trees.json" (builtins.toJSON {});

  file = runCommand "${index-name}-file" rec {} ''
    ln -s ${analysis} analysis
    ln -s ${all-files-list} all-files
    ln -s ${all-dirs-list} all-dirs
    ln -s ${crossref}/* .

    ${mkDirTree "file"}
    ${parallel-cmd} --jobs $NIX_BUILD_CORES --pipepart -a all-files --block -1 --halt now,fail=1 \
      "${output-file-cmd} '${pwd-config}' '${index-name}' '${url-map}' '${doc-trees}'"

    cp -r file $out
  '';

  dir = runCommand "${index-name}-dir" rec {} ''
    ln -s ${analysis} analysis
    ln -s ${all-files-list} all-files
    ln -s ${all-dirs-list} all-dirs
    ln -s ${crossref}/* .

    ${mkDirTree "dir"}
    ${searchfox-tool-cmd} "search-files --limit=0 --include-dirs --group-by=directory | batch-render dir"

    cp -r dir $out

  '';

  templates = runCommand "${index-name}-templates" rec {} ''
    ln -s ${analysis} analysis
    ln -s ${all-files-list} all-files
    ln -s ${all-dirs-list} all-dirs
    ln -s ${crossref}/* .

    ${searchfox-tool-cmd} "render search-template"

    cp -r templates $out
  '';

  pages = runCommand "${index-name}-pages" rec {} ''
    ln -s ${analysis} analysis
    ln -s ${all-files-list} all-files
    ln -s ${all-dirs-list} all-dirs
    ln -s ${crossref}/* .

    ${searchfox-tool-cmd} "render settings"

    cp -r pages $out
  '';

  index = runCommandLocal "${index-name}-index" {} ''
    mkdir -p $out

    ln -s ${analysis} $out/analysis
    ln -s ${all-files-list} $out/all-files
    ln -s ${all-dirs-list} $out/all-dirs
    ln -s ${crossref}/* $out/
    ln -s ${file} $out/file
    ln -s ${dir} $out/dir
    ln -s ${templates} $out/templates
    ln -s ${pages} $out/pages
  '';

  docroot = runCommandLocal "${index-name}-docroot" {} ''
    mkdir -p $out
    mkdir -p $out/file/${index-name}
    mkdir -p $out/dir/${index-name}
    mkdir -p $out/raw-analysis/${index-name}
    mkdir -p $out/raw/${index-name}

    ln -s ${index}/file $out/file/${index-name}/source
    ln -s ${index}/dir $out/dir/${index-name}/source
    ln -s ${analysis} $out/raw-analysis/${index-name}/raw-analysis
    ln -s ${all-files} $out/raw/${index-name}/raw
  '';

  config = mkConfig {inherit index codesearch-port;};
in {
  inherit livegrep-index docroot config;
}
