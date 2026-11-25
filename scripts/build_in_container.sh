#!/bin/bash
# Runs INSIDE the qnx-build container (QNX SDP 8.0 Linux host tools). Cross-compiles Ruckig for QNX 8.0:
#  A) x86_64, cloud client ON   B) x86_64, cloud client OFF   C) aarch64le, cloud client ON (compile only)
set -u
P="$(cd "$(dirname "$0")/.." && pwd)"; cd "$P" || exit 1
source "$HOME/qnx800/qnxsdp-env.sh" >/dev/null
mkdir -p logs
for cfg in A:x86_64:ON B:x86_64:OFF C:aarch64le:ON; do
  IFS=: read -r n arch cloud <<< "$cfg"
  rm -rf build-$n
  echo "===== config $n: $arch, BUILD_CLOUD_CLIENT=$cloud"
  cmake -S ruckig -B build-$n -DCMAKE_TOOLCHAIN_FILE="$P/cmake/qnx-$arch.cmake" -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_CLOUD_CLIENT=$cloud -DBUILD_TESTS=ON -DBUILD_EXAMPLES=ON -DBUILD_BENCHMARK=ON > logs/cmake-$n.log 2>&1
  echo "cmake exit: $?"
  cmake --build build-$n -j4 > logs/build-$n.log 2>&1
  echo "build exit: $?  errors: $(grep -c 'error:' logs/build-$n.log)"
  ls build-$n | grep -E "^(test-|benchmark|example-|libruckig)" | tr '\n' ' '; echo
  file build-$n/test-target 2>/dev/null | cut -c1-120
done
echo RUCKIG_BUILD_DONE
