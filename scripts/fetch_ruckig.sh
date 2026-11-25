#!/bin/bash
# Fetches upstream Ruckig at the tested commit and applies the QNX patch. Run on the host (needs git).
set -eu
cd "$(dirname "$0")/.."
UPSTREAM=https://github.com/pantor/ruckig.git
COMMIT=14c9814ff00e683daa3877028b422411d2264653
if [ -d ruckig ]; then echo "ruckig/ already present, skipping fetch"; exit 0; fi
git clone -q "$UPSTREAM" ruckig
git -C ruckig checkout -q "$COMMIT"
git -C ruckig apply ../patches/0001-Fix-build-and-tests-on-QNX-8.0.patch
echo "ruckig @ ${COMMIT:0:7} with QNX patch applied"
