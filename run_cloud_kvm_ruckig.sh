#!/bin/bash
# Runs Ruckig's tests + benchmark on QNX 8.0 under KVM on a temporary Google Cloud VM, brings results back, deletes the VM.
# Needs: run_ruckig_test.sh run once (build-A), the QNX VM image from the vibguard project, gcloud signed in.
# Run:  PROJECT=<gcp-project> bash ~/Downloads/JobAgent/qnx-ruckig/run_cloud_kvm_ruckig.sh
set -u
P="$(cd "$(dirname "$0")" && pwd)"; Q="${QNX_VM_PROJECT:-$HOME/Downloads/JobAgent/qnx}"; cd "$P" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/share/google-cloud-sdk/bin:$PATH"
mkdir -p logs results; exec > >(tee "logs/cloudkvm-$(date +%Y%m%d-%H%M%S).log") 2>&1
fail() { echo "FAILED: $*"; exit 1; }
VM=ruckig-qnx-kvm; ZONE=us-central1-a
[ -n "${PROJECT:-}" ] || fail "set PROJECT=<gcp-project>"
gcloud config set project "$PROJECT" -q
echo "COST CHECK: one n2-standard-4 VM (about \$0.20/hour) for ~10-15 min, then deleted. Expect roughly \$0.05-0.20."
read -r -p "Type yes to continue: " OK; [ "$OK" = "yes" ] || fail cancelled
[ -f build-A/test-target ] || fail "run run_ruckig_test.sh first"
rm -rf /tmp/rkkvm && mkdir -p /tmp/rkkvm/bin /tmp/rkkvm/vm/output /tmp/rkkvm/keys /tmp/rkkvm/scripts
cp build-A/libruckig.so* build-A/test-target build-A/benchmark-target build-A/example-01_position /tmp/rkkvm/bin/
cp "$Q"/vm/output/ifs.bin "$Q"/vm/output/disk-qemu "$Q"/vm/output/disk-qemu.vmdk /tmp/rkkvm/vm/output/
cp "$Q"/keys/qnx_vm_key "$Q"/keys/qnx_vm_key.pub /tmp/rkkvm/keys/; cp scripts/remote_kvm_ruckig.sh /tmp/rkkvm/scripts/
tar czf /tmp/rkkvm.tgz -C /tmp rkkvm || fail tar
cleanup() { echo "######## deleting VM $VM"; gcloud compute instances delete "$VM" --zone "$ZONE" -q; }
trap cleanup EXIT
gcloud compute instances create "$VM" --zone "$ZONE" --machine-type n2-standard-4 --enable-nested-virtualization \
  --image-family ubuntu-2204-lts --image-project ubuntu-os-cloud --boot-disk-size 20GB -q || fail "create VM"
for i in $(seq 1 30); do gcloud compute ssh "$VM" --zone "$ZONE" -q --command true 2>/dev/null && break; sleep 5; done
gcloud compute scp /tmp/rkkvm.tgz "$VM":~ --zone "$ZONE" -q || fail scp
gcloud compute ssh "$VM" --zone "$ZONE" -q --command 'tar xzf rkkvm.tgz && bash rkkvm/scripts/remote_kvm_ruckig.sh' || fail "remote run"
gcloud compute ssh "$VM" --zone "$ZONE" -q --command 'tar czf kvm_results.tgz kvm_results' || fail "tar results"
gcloud compute scp "$VM":~/kvm_results.tgz /tmp/ --zone "$ZONE" -q || fail "scp results"
rm -rf results/kvm && mkdir -p results/kvm && tar xzf /tmp/kvm_results.tgz -C results/kvm --strip-components 1 && ls -la results/kvm
echo "STATUS=OK (VM is deleted next)"
