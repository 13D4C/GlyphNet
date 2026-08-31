#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p lib

if [ -n "${LIBSSH2_SO:-}" ]; then
  candidates=("$LIBSSH2_SO")
else
  candidates=(
    /usr/lib/x86_64-linux-gnu/libssh2.so.1
    /usr/lib/aarch64-linux-gnu/libssh2.so.1
    /usr/lib64/libssh2.so.1
    /usr/lib/libssh2.so.1
    /usr/local/lib/libssh2.so.1
    /usr/lib/x86_64-linux-gnu/libssh2.so
    /usr/lib/aarch64-linux-gnu/libssh2.so
  )
fi

for so in "${candidates[@]}"; do
  if [ -e "$so" ]; then
    ln -sf "$so" lib/libssh2.so
    echo "vendor/lib/libssh2.so -> $so"
    exit 0
  fi
done

echo "error: could not find libssh2 shared library." >&2
echo "Install it (e.g. 'apt-get install libssh2-1' / 'dnf install libssh2')" >&2
echo "or set LIBSSH2_SO=/path/to/libssh2.so.1 and re-run." >&2
exit 1
