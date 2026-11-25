#!/bin/bash
# Creates the public repo github.com/veldig/ruckig-qnx and pushes this folder (ruckig/, build-*/, logs/ are git-ignored).
set -eu
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
gh auth status >/dev/null 2>&1 || gh auth login
gh auth setup-git
[ -d .git ] || git init -q -b main
git config user.name "Martin Vizcaino"
git config user.email "46332071+veldig@users.noreply.github.com"
git add -A
git commit -qm "Ruckig on QNX 8.0: build fixes, toolchains, scripts, test and KVM benchmark results" || true
git ls-files | head -40
if ! gh repo view veldig/ruckig-qnx >/dev/null 2>&1; then
  gh repo create veldig/ruckig-qnx --public --source . --push \
    --description "Ruckig (jerk-limited motion generation) ported to QNX 8.0: build fixes, toolchains, full test suite and KVM benchmark on QNX"
else
  git push -u origin main
fi
echo "PUSH_DONE: https://github.com/veldig/ruckig-qnx"
