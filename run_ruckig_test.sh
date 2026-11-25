#!/bin/bash
# Mac one-shot: fetch + patch Ruckig, cross-compile for QNX 8.0 in the qnx-build container,
# then run its test suite, benchmark and an example on the QNX x86_64 VM (QEMU emulation).
# Run:  bash ~/Downloads/JobAgent/qnx-ruckig/run_ruckig_test.sh
set -u
P="$(cd "$(dirname "$0")" && pwd)"; Q="${QNX_VM_PROJECT:-$HOME/Downloads/JobAgent/qnx}"; cd "$P" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH:/Applications/Docker.app/Contents/Resources/bin"
mkdir -p logs; exec > >(tee "logs/run-$(date +%H%M%S).log") 2>&1
bash scripts/fetch_ruckig.sh || exit 1
echo "== container + cmake"
docker start qnx-build >/dev/null || { echo "qnx-build container missing"; exit 1; }
docker exec -u root qnx-build bash -c 'command -v cmake >/dev/null || (apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq cmake >/dev/null)'
docker exec qnx-build bash "${P/#$HOME//home/$(id -un)}/scripts/build_in_container.sh"
B=build-A; [ -f $B/test-target ] || B=build-B
[ -f $B/test-target ] || { echo "NO test binary built"; exit 1; }
echo "== QNX VM (using $B)"
KEY="$Q/keys/qnx_vm_key"
SSH=(ssh -i "$KEY" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR root@127.0.0.1)
SCP=(scp -i "$KEY" -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
if ! "${SSH[@]}" true 2>/dev/null; then
  ( cd "$Q"; [ -f vm/qemu.pid ] && kill "$(cat vm/qemu.pid)" 2>/dev/null; sleep 1
    qemu-system-x86_64 -machine pc -accel tcg,thread=multi -cpu max -smp 2 -m 1G \
      -drive file=vm/output/disk-qemu.vmdk,if=ide,id=drv0 -kernel vm/output/ifs.bin \
      -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=net0 \
      -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
      -display none -serial file:logs/qemu_serial.log -pidfile vm/qemu.pid -daemonize ) || exit 1
  for i in $(seq 1 100); do "${SSH[@]}" true 2>/dev/null && break; sleep 3; done
fi
"${SSH[@]}" 'rm -rf /tmp/rk; mkdir -p /tmp/rk'
"${SCP[@]}" $B/libruckig.so* $B/test-target $B/benchmark-target $B/example-01_position root@127.0.0.1:/tmp/rk/
echo "== tests on QNX"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./test-target 2>&1 | tail -6'
echo "== benchmark, default priority"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./benchmark-target 2>&1 | tail -4'
echo "== benchmark, SCHED_FIFO 63"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk on -p 63f ./benchmark-target 2>&1 | tail -4'
echo "== example-01_position"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./example-01_position 2>&1 | tail -3'
echo RUCKIG_TEST_DONE
