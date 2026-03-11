# velvet

**V Enhanced Language and Tooling** — a maintained fork of [vlang/v-analyzer](https://github.com/vlang/v-analyzer), renamed to reflect the scope of changes diverged from upstream. Created to power the [V Enhanced](https://github.com/DaZhi-the-Revelator/zed-v-enhanced) Zed extension.

**version 0.1.0**

---

## Table of Contents

- [What's Different from Upstream](#whats-different-from-upstream)
  - [Richer Hover Documentation](#richer-hover-documentation)
- [Features](#features)
- [Building from Source](#building-from-source)
- [Installation](#installation)
- [Staying Up to Date](#staying-up-to-date)
- [Configuration](#configuration)
- [Editor Support](#editor-support)
  - [Zed](#zed)
  - [Neovim](#neovim)
- [Relationship to Upstream](#relationship-to-upstream)
- [Authors](#authors)
- [License](#license)

---

## What's Different from Upstream

### Feature Enhancements

#### Richer Hover Documentation

**Struct hover** now renders the full struct body, not just the name. Fields are grouped by access modifier and displayed with their types:

```txt
Module: **main**
```v
struct Rectangle {
    pub:
        origin Point
    pub mut:
        width  f64
        height f64
}
```

Previously, hovering a struct showed only:

```txt
Module: **main**
```v
struct Rectangle
```

**Enum hover** now renders all fields with their computed numeric values. Implicit auto-increment values, explicit values, and `[flag]` bitfield binary representations are all shown:

```txt
Module: **main**
```v
enum Direction {
    north = 0
    south = 1
    east = 2
    west = 3
}
```

For `[flag]` enums, each field shows its binary representation alongside its decimal value:

```txt
Module: **main**
```v
enum Permission {
    read    = 0b001 (1)
    write   = 0b010 (2)
    execute = 0b100 (4)
}
```

---

## Features

All features from the upstream v-analyzer are preserved. The full capability set is:

- **Code completion / IntelliSense** — 19 context-aware providers covering struct fields, methods, module members, keywords, attributes, compile-time constants, import paths, and more
- **Go-to-definition, type definition, implementation** — navigate to any symbol's declaration, the type of a variable, or all concrete implementations of an interface
- **Find all references** — PSI-based cross-file search; not text search, uses the program structure index
- **Symbol rename** — safe rename across all occurrences in the workspace, using the live parse tree for the open file to guarantee correct positions
- **Hover documentation** — rich markdown for every symbol kind: functions, methods, structs (with full field listing), enums (with computed values), type aliases, constants, variables, parameters, enum fields, import paths, generic parameters
- **Inlay hints** — type hints after `:=`, parameter name hints at call sites, range operator hints, implicit `err →` hints in `or {}` blocks, enum field value hints, constant type hints
- **Semantic syntax highlighting** — two-pass system (resolve-based for accurate colouring on smaller files, syntax-based fast pass for large files); distinguishes user-defined vs built-in functions, read vs write variable access
- **Formatting** — via `v fmt`; always idiomatic, handles generics, attributes, and C interop
- **Signature help** — active parameter highlighted as you type; retriggered on `,` and ` `
- **Folding ranges** — function bodies, struct/interface/enum bodies, `if`/`else`, `for`, `match`, all `{}` blocks
- **Selection range** — structural selection expansion (Alt+Shift+→ in Zed); each press expands the selection one syntactic level outward: identifier → expression → statement → block → function body → file
- **Document symbols** — full nested outline: functions, structs with fields, interfaces with methods, enums with values, constants, type aliases
- **Workspace symbols** — global search backed by the persistent stub index; fast, not a live file scan
- **Document highlights** — read vs write access highlighted differently; updates on cursor move
- **Code actions** — Make Mutable, Make Public, Add `[heap]`, Add `[flag]`, Import Module, Remove Unused Import
- **Diagnostics** — real V compiler errors, warnings, and notices; unused symbols tagged with `DiagnosticTag.unnecessary`, deprecated symbols with `DiagnosticTag.deprecated`

---

## Building from Source

> **This repository uses nested Git submodules.** Clone with:
>
> ```sh
> git clone --recurse-submodules https://github.com/DaZhi-the-Revelator/velvet
> ```
>
> Or, if you already cloned without `--recurse-submodules`:
>
> ```sh
> git submodule update --init --recursive
> ```
>
> This initialises both `tree_sitter_v` (the V grammar) and the nested `tree_sitter_v/bindings/core` submodule (the tree-sitter C runtime). **Omitting `--recursive` is the most common cause of build failures** (`tree_sitter/api.h` not found).
>
> **On Windows, use GCC.** TCC can run into issues with some generated C code.

Update V to the latest version first:

```sh
v up
```

Build a release binary (recommended):

```sh
v run build.vsh release
```

Build a debug binary (faster to compile, slower to run):

```sh
v run build.vsh debug
```

The compiled binary is placed in `./bin/velvet` (or `./bin/velvet.exe` on Windows).

---

## Installation

Copy the binary to a directory on your `PATH`:

```sh
# Linux / macOS
cp bin/velvet ~/.local/bin/velvet

# Windows (PowerShell — run from the velvet directory)
Copy-Item .\bin\velvet.exe "$env:USERPROFILE\.config\velvet\bin\velvet.exe"
# Add that directory to your PATH if it isn't already
```

Verify the installation:

```sh
velvet --version
# velvet version 0.1.0
```

---

## Staying Up to Date

Pull the latest fixes and rebuild:

```sh
git pull
v run build.vsh release
# copy the new binary to PATH as above
```

---

## Configuration

velvet is configured via a global or per-project TOML file.

**Global config** — applies to all projects:

```txt
~/.config/velvet/config.toml
```

**Per-project config** — create a `.v-analyzer/config.toml` file at your project root (velvet looks for this path automatically). Key settings:

```toml
# Path to your V installation (set this if velvet can't find V automatically)
custom_vroot = "/path/to/v"

# Cache directory
custom_cache_dir = ".velvet/cache"

# Semantic tokens mode: "full", "syntax", or "none"
enable_semantic_tokens = "full"

[inlay_hints]
enable = true
enable_type_hints = true
enable_parameter_name_hints = true
enable_range_hints = true
enable_implicit_err_hints = true
enable_constant_type_hints = true
enable_enum_field_value_hints = true

```

---

## Editor Support

### Zed

Use the [V Enhanced](https://github.com/DaZhi-the-Revelator/zed-v-enhanced) extension. It is purpose-built for velvet and includes Zed-native syntax highlighting, snippets, folding, outline, and a Jupyter kernel for REPL execution.

Configure Zed's `settings.json` to point at the velvet binary:

```json
{
    "lsp": {
        "velvet": {
            "binary": {
                "path": "/path/to/velvet"
            }
        }
    }
}
```

### Neovim

velvet works with both **Neovim 0.11+** (native `vim.lsp` API) and older setups using **nvim-lspconfig**.

#### Neovim 0.11+ (native `vim.lsp.config`)

Neovim 0.11 introduced a built-in LSP configuration API that does not require nvim-lspconfig. Add the following to your `init.lua`:

```lua
-- Step 1: register the V filetype.
-- Neovim does not ship a built-in filetype for .v files (the extension is
-- ambiguous — Verilog also uses .v). Without this, vim.lsp.enable() silently
-- never attaches because no buffer ever receives the 'v' filetype.
vim.filetype.add({
  extension = {
    v   = 'v',
    vsh = 'v',
    vv  = 'v',
  },
})

-- Step 2: configure and enable velvet.
vim.lsp.config('velvet', {
  cmd = { vim.fn.expand('~/.local/bin/velvet'), '--stdio' },
  filetypes = { 'v', 'vsh', 'vv' },
  root_markers = { 'v.mod', '.git' },
})
vim.lsp.enable('velvet')
```

> **Important:** Always pass `--stdio` explicitly in `cmd`. Neovim's native LSP client starts the server process and pipes stdio without passing any command-line flags of its own — velvet defaults to stdio internally, but some environments require the flag to be explicit for the handshake to complete.

> **`root_markers` is a flat list**, not a nested table. Wrapping entries in an inner table (e.g. `{ { 'v.mod' }, '.git' }`) causes Neovim to treat each marker group as a conjunction — if your project has no `v.mod`, the group fails and the server never attaches. Use a flat list so velvet attaches in any V project, with or without a module file.

> **`vim.lsp.enable()` only attaches to buffers whose filetype matches.** `:checkhealth vim.lsp` reports "No active clients" if you run it without a V file open. Open a `.v` file first, then run `:checkhealth vim.lsp` — velvet should appear under **Active Clients**.

Verify the server is attached:

1. Open a `.v` file.
2. Run `:checkhealth vim.lsp` — velvet should appear under **Active Clients**.
3. Alternatively, run `:lua vim.print(vim.lsp.get_clients())` — you should see a table entry for velvet.

If velvet still does not appear, confirm the filetype was detected: run `:set ft?` while a `.v` file is open. It should print `filetype=v`. If it prints `filetype=verilog` or is blank, the `vim.filetype.add` block above is missing or loaded too late.

On Windows, expand the path to `velvet.exe`:

```lua
vim.filetype.add({
  extension = {
    v   = 'v',
    vsh = 'v',
    vv  = 'v',
  },
})

vim.lsp.config('velvet', {
  cmd = { vim.fn.expand('$USERPROFILE/.config/velvet/bin/velvet.exe'), '--stdio' },
  filetypes = { 'v', 'vsh', 'vv' },
  root_markers = { 'v.mod', '.git' },
})
vim.lsp.enable('velvet')
```

#### Older Neovim (nvim-lspconfig)

`nvim-lspconfig`'s built-in `v_analyzer` config hardcodes the binary name `v-analyzer`, so pointing it at `velvet` will silently fail — the server never attaches, and none of the default LSP keymaps (`gra`, `grr`, `grn`, `gri`, `grt`, `gO`) activate.

Instead, register velvet as a **new** server config before calling `setup`:

```lua
local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

if not configs.velvet then
  configs.velvet = {
    default_config = {
      cmd = { vim.fn.expand('~/.local/bin/velvet'), '--stdio' },
      filetypes = { 'v', 'vsh', 'vv' },
      root_dir = lspconfig.util.root_pattern('v.mod', '.git'),
      single_file_support = true,
    },
  }
end

lspconfig.velvet.setup({})
```

On Windows, replace the `cmd` path with the actual location of `velvet.exe`, for example:

```lua
cmd = { vim.fn.expand('$USERPROFILE/.config/velvet/bin/velvet.exe'), '--stdio' },
```

Verify the server attached with `:checkhealth lsp` or `:LspInfo` — you should see `velvet` listed as attached to the current buffer. Once attached, all default Neovim LSP keymaps work without any additional configuration.

Any editor that supports the Language Server Protocol can use velvet by pointing its LSP client at the binary.

---

## Relationship to Upstream

velvet diverges from [vlang/v-analyzer](https://github.com/vlang/v-analyzer) with bug fixes and feature additions that have not been merged upstream. No changes have been made to the `jsonrpc` or `lsp` modules. The Jupyter kernel lives in the V Enhanced Zed extension repository and is not part of this project.

---

## Authors

- Maintained by [DaZhi-the-Revelator](https://github.com/DaZhi-the-Revelator)
- Original v-analyzer by [VOSCA](https://github.com/vlang-association), based on [VLS](https://github.com/vlang/vls)

---

## License

MIT — see [LICENSE](LICENSE).
