# SPDX-FileCopyrightText: 2026 KDAB
# SPDX-FileContributor: Nicolas Qiu Guichard <nicolas.guichard@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Builds a mozsearch blame Git repository.
#
# For Git blame support, Mozsearch builds a derivative repository which
# replaces each line of each file of each revision with its blame data.
#
{
  lib,
  stdenvNoCC,
  runCommand,
  mozsearch-tools,
  git,
  git-cinnabar,
}:

{index-name, git-dir, default-branch, branches ? [],}: runCommand "${index-name}-blame" {} ''
  PATH=${git}/bin:${git-cinnabar}/bin:$PATH

  HOME=$(mktemp -d)
  git config --global --add safe.directory '*'

  mkdir -p $out
  pushd $out
  git init . --initial-branch=${default-branch}
  popd
  ${mozsearch-tools}/bin/build-blame ${git-dir} $out

  LASTBRANCH="HEAD"
  for BRANCH in ${builtins.concatStringsSep " " branches}; do
      # Start the new branch in the blame repo, using the last done
      # branch as the starting point so as to maximally reuse previous
      # results.
      pushd "$out"
      git branch "$BRANCH" "$LASTBRANCH"
      popd

      echo "Generating blame information for $BRANCH..."
      ${mozsearch-tools}/bin/build-blame "${git-dir}" "$out" --blame-ref "refs/heads/$BRANCH"

      LASTBRANCH="$BRANCH"
  done
''
