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
  - [VS Code](#vs-code)
  - [Neovim](#neovim)
- [Project Structure](#project-structure)
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
# velvet version 0.0.6
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

**Per-project config** — create with:

```sh
velvet init
```

This writes `.velvet/config.toml` at your project root. Key settings:

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

### VS Code

Point `velvet.serverPath` at the binary:

```json
{
    "velvet.serverPath": "/path/to/velvet"
}
```

### Neovim

Configure `nvim-lspconfig` to use the velvet binary:

```lua
require('lspconfig').v_analyzer.setup({
    cmd = { '/path/to/velvet' },
})
```

Any editor that supports the Language Server Protocol can use velvet by pointing its LSP client at the binary.

---

## Project Structure

```txt
velvet/
├── src/
│   ├── analyzer/
│   │   └── psi/                  # PSI (Program Structure Interface) layer
│   │       ├── EnumDeclaration.v
│   │       ├── EnumFieldDeclaration.v  # ← bug fixes: smartcasts, value resolution
│   │       ├── FieldDeclaration.v
│   │       ├── StructDeclaration.v
│   │       ├── search/
│   │       │   └── ReferencesSearch.v  # ← bug fix: live-file rename search
│   │       └── ...
│   └── server/
│       ├── documentation/
│       │   └── provider.v        # ← enhancements: struct/enum hover rendering
│       ├── features_rename.v
│       ├── features_selection_range.v  # ← addition: structural selection range
│       └── ...
│   lsp/
│       ├── selection_range.v     # ← addition: SelectionRangeParams / SelectionRange types
│       └── ...
├── tree_sitter_v/                # Git submodule — https://github.com/DaZhi-the-Revelator/tree-sitter-v
├── build.vsh                     # Build script
└── install.vsh                   # Install script
```

---

## Relationship to Upstream

velvet diverges from [vlang/v-analyzer](https://github.com/vlang/v-analyzer) with bug fixes and feature additions that have not been merged upstream. No changes have been made to the `jsonrpc`, `lsp`, or `tree_sitter_v` modules. The Jupyter kernel lives in the V Enhanced Zed extension repository and is not part of this project.

---

## Authors

- Maintained by [DaZhi-the-Revelator](https://github.com/DaZhi-the-Revelator)
- Original v-analyzer by [VOSCA](https://github.com/vlang-association), based on [VLS](https://github.com/vlang/vls)

---

## License

MIT — see [LICENSE](LICENSE).
