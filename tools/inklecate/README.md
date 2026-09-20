# inklecate (Ink compiler)

This directory holds the Ink compiler toolchain used by the narrative
platform (`core/addons/inkgd`) to compile `.ink` source files into
`.ink.json`. The binaries themselves are **not tracked in git** —
`inklecate.exe` alone is ~59 MB, which is too large to keep in the repo's
history.

## Files expected here

- `inklecate.exe` — the Ink compiler executable (Windows).
- `ink-engine-runtime.dll`
- `ink_compiler.dll`

## How to restore them

1. Download the latest Ink release for your platform from the official
   inkle/ink releases page: https://github.com/inkle/ink/releases
2. Extract `inklecate.exe`, `ink-engine-runtime.dll`, and `ink_compiler.dll`
   into this directory (`tools/inklecate/`).
3. Re-run any narrative build/compile tooling in `core/tools/narrative/` —
   it expects the compiler at this path.

These files are listed in `.gitignore` (`tools/inklecate/*.exe`,
`tools/inklecate/*.dll`) so they will stay untracked once restored.
