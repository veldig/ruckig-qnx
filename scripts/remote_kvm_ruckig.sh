#!/bin/bash
# Runs ON a temporary Google Cloud VM (nested virtualization). Boots the QNX 8.0 x86_64 image under KVM
# and runs Ruckig's test suite, benchmark (default priority and SCHED_FIFO 63, 3 runs each) and an example.
set -u
cd ~/rkkvm || exit 1
log() { echo; echo "######## $* ($(date +%H:%M:%S))"; }
log "host"; uname -a; ls -la /dev/kvm || exit 2
log "install qemu"; sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qemu-system-x86 >/dev/null
sudo chmod 666 /dev/kvm; chmod 600 keys/qnx_vm_key
SSH=(ssh -i keys/qnx_vm_key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o ServerAliveInterval=15 -o LogLevel=ERROR root@127.0.0.1)
SCP=(scp -i keys/qnx_vm_key -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
log "boot QNX 8.0 under KVM"
qemu-system-x86_64 -machine pc -enable-kvm -cpu host -smp 2 -m 1G \
  -drive file=vm/output/disk-qemu.vmdk,if=ide,id=drv0 -kernel vm/output/ifs.bin \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=net0 \
  -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
  -display none -serial file:qemu_serial.log -pidfile qemu.pid -daemonize || exit 3
for i in $(seq 1 60); do "${SSH[@]}" true 2>/dev/null && break; sleep 2; done
"${SSH[@]}" 'uname -a; pidin info' || { tail -30 qemu_serial.log; exit 4; }
"${SSH[@]}" 'rm -rf /tmp/rk; mkdir -p /tmp/rk'
"${SCP[@]}" bin/* root@127.0.0.1:/tmp/rk/
R=~/kvm_results; rm -rf $R; mkdir -p $R
log "test suite"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./test-target 2>&1' > $R/tests.txt; tail -6 $R/tests.txt
for i in 1 2 3; do
  log "benchmark default priority run $i"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./benchmark-target 2>&1' | tee -a $R/benchmark_default.txt | tail -4
  log "benchmark SCHED_FIFO 63 run $i"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk on -p 63f ./benchmark-target 2>&1' | tee -a $R/benchmark_fifo63.txt | tail -4
done
log "example-01_position"; "${SSH[@]}" 'cd /tmp/rk && LD_LIBRARY_PATH=/tmp/rk ./example-01_position 2>&1' > $R/example01.txt; tail -3 $R/example01.txt
kill "$(cat qemu.pid)" 2>/dev/null
echo REMOTE_OK
