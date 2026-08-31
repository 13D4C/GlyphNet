# vendor/

`lib/libssh2.so` is a **build-time-only** symlink to the system libssh2, created
by `./vendor/setup.sh`. It is not committed (see `.gitignore`).

## Why

Linking with `-lssh2` requires an unversioned `libssh2.so`, which only ships in
the `-dev` package. Most systems have only the runtime `libssh2.so.1`. Creating a
repo-local symlink avoids needing root to install `libssh2-dev`.

At runtime nothing here is used: the dynamic linker resolves `libssh2.so.1`
through the normal `ldconfig` cache.

## cjpm wiring

`cjpm.toml` points at this directory:

```toml
[ffi.c]
  ssh2 = { path = "vendor/lib" }
```

Two things about that block that are easy to get wrong:

1. **The key is the real C library name.** `ssh2` means `-lssh2` -> `libssh2.so`.
   Naming it something descriptive like `ssh2_vendor` makes cjpm look for
   `libssh2_vendor.so` and fail with
   `can not find the library 'ssh2_vendor' which is listed in 'ffi.c' field`.
2. **It must be a top-level `[ffi.c]` table.** A `[target.<triple>.ffi.c]` table
   is only consulted when cross-compiling with `cjpm build --target <triple>`;
   for a native build it is silently ignored and the link fails with
   `/usr/bin/ld: cannot find -lssh2`.
