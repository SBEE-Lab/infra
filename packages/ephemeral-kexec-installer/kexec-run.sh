#!/bin/sh

# Set pipefail if the shell supports it.
if set -o | grep -q pipefail; then
  # shellcheck disable=SC3040
  set -o pipefail
fi
set -eu
umask 077

kexec_extra_flags=""
while [ "$#" -gt 0 ]; do
  case "$1" in
  --kexec-extra-flags)
    kexec_extra_flags="$2"
    shift
    ;;
  esac
  shift
done

init="@init@"
kernelParams="@kernelParams@"
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
RUNTIME_DIR=/run/ephemeral-kexec

fail() {
  echo "ephemeral-kexec: $*" >&2
  exit 1
}

[ "$(id -u)" -eq 0 ] || fail "must run as root"
[ -d "$RUNTIME_DIR" ] || fail "missing $RUNTIME_DIR"
[ ! -L "$RUNTIME_DIR" ] || fail "$RUNTIME_DIR must not be a symlink"
[ "$(stat -c %u "$RUNTIME_DIR")" -eq 0 ] || fail "$RUNTIME_DIR must be owned by root"
[ "$(stat -c %a "$RUNTIME_DIR")" = 700 ] || fail "$RUNTIME_DIR must have mode 0700"

expected_files='private-key
wg-install.netdev
wg-install.network'
actual_files=$(find -P "$RUNTIME_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
[ "$actual_files" = "$expected_files" ] || fail "$RUNTIME_DIR contains unexpected files"

for name in private-key wg-install.netdev wg-install.network; do
  path="$RUNTIME_DIR/$name"
  [ -f "$path" ] || fail "$path is not a regular file"
  [ ! -L "$path" ] || fail "$path must not be a symlink"
  [ "$(stat -c %u "$path")" -eq 0 ] || fail "$path must be owned by root"
done

key_mode=$(stat -c %a "$RUNTIME_DIR/private-key")
case "$key_mode" in
400 | 600) ;;
*) fail "$RUNTIME_DIR/private-key must have mode 0400 or 0600" ;;
esac
[ "$(stat -c %s "$RUNTIME_DIR/private-key")" -le 128 ] || fail "private key is too large"
[ "$(stat -c %s "$RUNTIME_DIR/wg-install.netdev")" -le 16384 ] || fail "netdev is too large"
[ "$(stat -c %s "$RUNTIME_DIR/wg-install.network")" -le 16384 ] || fail "network unit is too large"

grep -Fqx 'PrivateKeyFile=/run/systemd/network/wg-install.key' \
  "$RUNTIME_DIR/wg-install.netdev" || fail "netdev has an unexpected PrivateKeyFile"
if grep -Eq '^[[:space:]]*PrivateKey[[:space:]]*=' "$RUNTIME_DIR/wg-install.netdev"; then
  fail "inline WireGuard private keys are forbidden"
fi

WORK_DIR=$(mktemp -d /run/ephemeral-kexec-work.XXXXXX)
ARCHIVE_DIR="$WORK_DIR/archive"
FINAL_INITRD="$WORK_DIR/initrd"
cleanup() {
  rm -rf "$WORK_DIR"
}
on_signal() {
  trap - EXIT
  cleanup
  exit 1
}
trap cleanup EXIT
trap on_signal HUP INT TERM

mkdir -p "$ARCHIVE_DIR/ssh" "$ARCHIVE_DIR/ephemeral-kexec"
cp "$SCRIPT_DIR/initrd" "$FINAL_INITRD"
chmod 0600 "$FINAL_INITRD"

install -m 0400 "$RUNTIME_DIR/private-key" "$ARCHIVE_DIR/ephemeral-kexec/private-key"
install -m 0600 "$RUNTIME_DIR/wg-install.netdev" "$ARCHIVE_DIR/ephemeral-kexec/wg-install.netdev"
install -m 0600 "$RUNTIME_DIR/wg-install.network" "$ARCHIVE_DIR/ephemeral-kexec/wg-install.network"
touch "$ARCHIVE_DIR/ephemeral-kexec/marker"

extractPubKeys() {
  home="$1"
  for file in .ssh/authorized_keys .ssh/authorized_keys2; do
    key="$home/$file"
    if test -e "$key"; then
      grep -o '\(\(ssh\|ecdsa\|sk\)-[^ ]* .*\)' "$key" >>"$ARCHIVE_DIR/ssh/authorized_keys" || true
    fi
  done
}
extractPubKeys /root

if test -n "${DOAS_USER-}"; then
  SUDO_USER="$DOAS_USER"
fi
if test -n "${SUDO_USER-}"; then
  sudo_home=$(sh -c "echo ~$SUDO_USER")
  extractPubKeys "$sudo_home"
fi
if test -e /etc/ssh/authorized_keys.d/root; then
  cat /etc/ssh/authorized_keys.d/root >>"$ARCHIVE_DIR/ssh/authorized_keys"
fi
if test -n "${SUDO_USER-}" && test -e "/etc/ssh/authorized_keys.d/$SUDO_USER"; then
  cat "/etc/ssh/authorized_keys.d/$SUDO_USER" >>"$ARCHIVE_DIR/ssh/authorized_keys"
fi
for path in /etc/ssh/ssh_host_*; do
  test -e "$path" || continue
  cp -a "$path" "$ARCHIVE_DIR/ssh"
done

"$SCRIPT_DIR/ip" --json addr >"$ARCHIVE_DIR/addrs.json"
"$SCRIPT_DIR/ip" -4 --json route >"$ARCHIVE_DIR/routes-v4.json"
"$SCRIPT_DIR/ip" -6 --json route >"$ARCHIVE_DIR/routes-v6.json"
[ -f /etc/machine-id ] && cp /etc/machine-id "$ARCHIVE_DIR/machine-id"

(
  cd "$ARCHIVE_DIR"
  find . | cpio -o -H newc | gzip -9 >>"$FINAL_INITRD"
)

kexecSyscallFlags=""
if printf "%s\n" "6.1" "$(uname -r)" | sort -c -V 2>&1; then
  kexecSyscallFlags="--kexec-syscall-auto"
fi

if ! sh -c "'$SCRIPT_DIR/kexec' --load '$SCRIPT_DIR/bzImage' \
  $kexecSyscallFlags \
  $kexec_extra_flags \
  --initrd='$FINAL_INITRD' --no-checks \
  --command-line 'init=$init $kernelParams'"; then
  echo "kexec failed, dumping dmesg"
  dmesg | tail -n 100
  exit 1
fi

# kexec --load copied the initrd into kernel memory. Remove its only filesystem
# copy, including the ephemeral private key, before scheduling execution.
cleanup
trap - EXIT HUP INT TERM

echo "machine will boot into nixos in 6s..."
if test -e /dev/kmsg; then
  exec >/dev/kmsg 2>&1
else
  exec >/dev/null 2>&1
fi
nohup sh -c "sleep 6 && cd / && '$SCRIPT_DIR/kexec' -e ${kexec_extra_flags}" &
