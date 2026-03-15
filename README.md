# velvet

**V Enhanced Language and Tooling** — a maintained fork of [vlang/v-analyzer](https://github.com/vlang/v-analyzer), renamed to reflect the scope of changes diverged from upstream. Created to power the [V Enhanced](https://github.com/DaZhi-the-Revelator/zed-v-enhanced) Zed extension.

---

## Table of Contents

- [Features](#features)
- [Building from Source](#building-from-source)
- [Installation](#installation)
- [Staying Up to Date](#staying-up-to-date)
- [Configuration](#configuration)
- [Editor Support](#editor-support)
  - [Zed](#zed)
  - [Neovim](#neovim)
    - [Code Lens in Neovim](#code-lens-in-neovim)
  - [CLion](#clion)
    - [Code Lens in CLion](#code-lens-in-clion)
- [Troubleshooting](#troubleshooting)
  - [Default keymaps produce nothing (grt, grr, grn, gO)](#default-keymaps-produce-nothing-grt-grr-grn-go)
- [Relationship to Upstream](#relationship-to-upstream)
- [Authors](#authors)
- [License](#license)

---

## Features

### Code Completion / IntelliSense

19 context-aware providers covering struct fields, methods, module members, keywords, attributes, compile-time constants, import paths, and more.

**Generic-aware completions** — completion after `.` on a generic instantiation resolves field and method types correctly. For example:

```v
struct Container[T] {
    value T
}

c := Container[Point]{ value: Point{} }
c.  // 'value' now shows type Point, not T
```

This works for generic stdlib types too — `[]int`, `map[string]int`, and user-defined generics all resolve their type parameters through the instantiation.

**Struct literal field completions with default values** — when completing inside a struct literal, fields with declared default values prefill the default rather than the zero value:

```v
struct Config {
    timeout int = 5000
    retries int = 3
}

// Typing `Config{ ` and triggering completion suggests:
//   timeout: 5000
//   retries: 3
// instead of:
//   timeout: 0
//   retries: 0
```

### Go-to-Definition, Type Definition, Implementation

Navigate to any symbol's declaration, the type of a variable, or all concrete implementations of an interface.

**`$if` compile-time conditions** — pressing go-to-definition on the condition identifier inside a `$if` block navigates to the constant's definition in the stubs index:

```v
$if windows {    // go-to-def on 'windows' → jumps to its ConstantDefinition
    ...
}
```

`@FILE`, `@LINE`, `@MOD`, and the other compile-time built-in identifiers are compiler intrinsics with no source location — go-to-definition returns no links rather than crashing.

### Find All References

PSI-based cross-file search; not text search, uses the program structure index.

### Symbol Rename

Safe cross-file rename across all occurrences in the workspace; uses the live parse tree for the open file and batch-parses all other affected files to guarantee correct positions everywhere.

### Hover Documentation

Rich markdown for every symbol kind: functions, methods, structs, interfaces, enums, type aliases, constants, variables, parameters, enum fields, import paths, and generic parameters. Attributes such as `[deprecated]`, `[heap]`, and `[flag]` are shown above the declaration.

`@FILE`, `@LINE`, `@MOD`, and all other compile-time built-in identifiers show a description on hover instead of nothing.

**Struct hover** renders the full struct body, not just the name. Fields are grouped by access modifier and displayed with their types:

```
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

**Interface hover** renders the full interface body with methods and fields:

```
Module: **main**
```v
interface Animal {
    name string
    sound() string
    move()
}
```

**Enum hover** renders all fields with their computed numeric values. Implicit auto-increment values, explicit values, and `[flag]` bitfield binary representations are all shown:

```
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

```
Module: **main**
```v
enum Permission {
    read    = 0b001 (1)
    write   = 0b010 (2)
    execute = 0b100 (4)
}
```

### Inlay Hints

Type hints after `:=`, parameter name hints at call sites, range operator hints, implicit `err →` hints in `or {}` blocks, enum field value hints, and constant type hints.

**Anonymous function return type hints** — anonymous functions with no explicit return type show the inferred return type as an inlay hint on the closing `}`:

```v
f := fn(x int) { return x * 2 }  // shows: }  → int

arr.map(fn(it int) {              // shows: }  → bool
    return it > 0
})
```

The hint is suppressed when an explicit return type is already written. Configurable via `enable_anon_fn_return_type_hints` (see [Configuration](#configuration)).

### Semantic Syntax Highlighting

Two-pass system: resolve-based for accurate colouring on smaller files, syntax-based fast pass for large files. Distinguishes user-defined vs built-in functions, and read vs write variable access.

### Formatting

Via `v fmt`; always idiomatic, handles generics, attributes, and C interop.

### Signature Help

Active parameter highlighted as you type; retriggered on `,` and ` `.

### Folding Ranges

Function bodies, struct/interface/enum bodies, `if`/`else`, `for`, `match`, all `{}` blocks.

### Selection Range

Structural selection expansion (Alt+Shift+→ in Zed); each press expands the selection one syntactic level outward: identifier → expression → statement → block → function body → file.

### Document Symbols

Full nested outline: functions, structs with fields, interfaces with methods, enums with values, constants, type aliases.

### Workspace Symbols

Global search backed by the persistent stub index; fast, not a live file scan.

### Document Highlights

Read vs write access highlighted differently; updates on cursor move.

### Code Actions

Make Mutable, Make Public, Add `[heap]`, Add `[flag]`, Import Module, Remove Unused Import.

### Code Lens

Inline annotations above `fn main()`, test functions, interface declarations, and struct declarations; shows run controls and implementation counts (see [Editor Support](#editor-support) for per-editor setup).

### Diagnostics

Real V compiler errors, warnings, and notices; unused symbols tagged with `DiagnosticTag.unnecessary`, deprecated symbols with `DiagnosticTag.deprecated`.

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

To check whether you are on the latest release without rebuilding:

```sh
velvet check-updates
```

When up to date:

```txt
[INFO] Checking for velvet updates...
[INFO] Local version: 0.1.0
[INFO] Latest release: 0.1.0
[SUCCESS] velvet is up to date (0.1.0)
```

When behind:

```txt
[INFO] Checking for velvet updates...
[INFO] Local version: 0.0.6
[INFO] Latest release: 0.1.0
[UPDATE] velvet 0.1.0 is available (you have 0.0.6)

To update, run:
  cd velvet && git pull && v run build.vsh release
  then copy bin/velvet to your PATH
```

---

## Configuration

velvet is configured via a global or per-project TOML file.

**Global config** — applies to all projects:

```txt
~/.config/velvet/config.toml
```

**Per-project config** — create a `.velvet/config.toml` file at your project root (velvet looks for this path automatically). Key settings:

```toml
# Path to your V installation (set this if velvet can't find V automatically)
custom_vroot = "/path/to/v"

# Cache directory
custom_cache_dir = ".velvet/cache"

# Semantic tokens mode: "full", "syntax", or "none"
# "full"   — accurate resolve-based highlighting (default for files < 1000 lines)
# "syntax" — faster syntax-only pass, always used for large files
# "none"   — disable semantic tokens entirely
enable_semantic_tokens = "full"

[inlay_hints]
enable = true
enable_type_hints = true
enable_parameter_name_hints = true
enable_range_hints = true
enable_implicit_err_hints = true
enable_constant_type_hints = true
enable_enum_field_value_hints = true
enable_anon_fn_return_type_hints = true   # inferred return type on anonymous fn closing `}`

[code_lens]
enable = true
enable_run_lens = true
enable_inheritors_lens = true
enable_super_interfaces_lens = true
enable_run_tests_lens = true
```

> **Editor override:** All of the above settings can also be supplied at runtime via the LSP `initializationOptions` field — no config file required. Editors like Zed send these automatically from `settings.json`. Values from `initializationOptions` take precedence over the TOML file.

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
>
> **`root_markers` is a flat list**, not a nested table. Wrapping entries in an inner table (e.g. `{ { 'v.mod' }, '.git' }`) causes Neovim to treat each marker group as a conjunction — if your project has no `v.mod`, the group fails and the server never attaches. Use a flat list so velvet attaches in any V project, with or without a module file.
>
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

#### Code Lens in Neovim

velvet emits four types of Code Lens:

| Lens | Appears on | What it does |
|------|-----------|-------------|
| `▶ Run workspace` | `fn main()` | Runs the project root with `v run` |
| `single file` | `fn main()` | Runs only the current file with `v run` |
| `▶ Run test` / `all file tests` | `test_*` functions | Runs a single test or the entire test file |
| `N implementations` | `interface` declarations | Jumps to all structs that implement the interface |
| `implement N interfaces` | `struct` declarations | Jumps to all interfaces the struct satisfies |

Code Lens display requires the `vim.lsp.codelens` API, which is available in Neovim 0.9+. Add this to your `init.lua` to enable it:

```lua
-- Refresh and display code lenses when a V file is attached or saved.
vim.api.nvim_create_autocmd({ 'LspAttach', 'BufWritePost' }, {
  pattern = { '*.v', '*.vsh', '*.vv' },
  callback = function()
    vim.lsp.codelens.refresh()
  end,
})
```

To trigger a lens manually: place your cursor on the lens line and run `:lua vim.lsp.codelens.run()`.

The run lenses (`▶ Run workspace`, `single file`, `▶ Run test`) fire the custom commands `velvet.runWorkspace`, `velvet.runFile`, and `velvet.runTests`. Neovim does not handle these automatically — you need to register handlers for them. Add the following to your `init.lua`:

```lua
vim.lsp.commands['velvet.runWorkspace'] = function(cmd)
  local dir = vim.fn.fnamemodify(cmd.arguments[1], ':h')
  vim.cmd('split | terminal v run ' .. dir)
end

vim.lsp.commands['velvet.runFile'] = function(cmd)
  vim.cmd('split | terminal v run ' .. cmd.arguments[1])
end

vim.lsp.commands['velvet.runTests'] = function(cmd)
  local path = cmd.arguments[1]
  local name = cmd.arguments[2]
  if name then
    vim.cmd('split | terminal v test -run ' .. name .. ' ' .. path)
  else
    vim.cmd('split | terminal v test ' .. path)
  end
end
```

The `velvet.showReferences` command (used by the implementations and interfaces lenses) is handled natively by Neovim's LSP client — no extra configuration is needed for those lenses.

Any editor that supports the Language Server Protocol can use velvet by pointing its LSP client at the binary.

### CLion

CLion 2023.2 and later include built-in LSP support — no plugin is required. For earlier versions, install the **LSP Support** plugin from the JetBrains Marketplace first.

> **Note:** CLion has no built-in syntax highlighting for V. All LSP features (completion, hover, go-to-definition, find references, rename, diagnostics, etc.) will work correctly, but the editor will not colour the source as V-specific syntax — it will fall back to plain text highlighting.

#### CLion 2023.2+ (built-in LSP)

1. Open **Settings** → **Languages & Frameworks** → **Language Server Protocol**.
2. If **Language Server Protocol** is not listed, install the [LSP4IJ plugin](https://github.com/redhat-developer/lsp4ij/tree/main)
3. Click **+** to add a new server.
4. Fill in the fields:

   | Field | Value |
   |---|---|
   | Name | `velvet` |
   | Command | Path to the velvet binary (see below) |
   | File name patterns | `*.v;*.vsh;*.vv` |

   **Linux / macOS:**

   ```txt
   /home/<you>/.local/bin/velvet
   ```

   **Windows:**

   ```txt
   C:\Users\<you>\.config\velvet\bin\velvet.exe
   ```

5. Leave the **Working directory** blank — CLion will use the project root automatically.
6. Click **OK** and restart CLion if prompted.

No `--stdio` flag is needed in the command. velvet defaults to stdio transport internally.

#### Older CLion (LSP Support plugin)

1. Install the **LSP Support** plugin: **Settings** → **Plugins** → search for `LSP Support` → **Install** → restart CLion.
2. After restart, open **Settings** → **Languages & Frameworks** → **LSP Support** → **Server Definitions**.
3. Set the **Extension** to `v` and the **Path** to the velvet binary.
4. Repeat for the `vsh` and `vv` extensions if needed.
5. Click **OK**.

#### Code Lens in CLion

CLion renders Code Lens annotations via the LSP4IJ plugin (required for built-in LSP support — see setup above). velvet emits four types of Code Lens:

| Lens | Appears on | What it does |
|------|-----------|-------------|
| `▶ Run workspace` | `fn main()` | Runs the project root with `v run` |
| `single file` | `fn main()` | Runs only the current file with `v run` |
| `▶ Run test` / `all file tests` | `test_*` functions | Runs a single test or the entire test file |
| `N implementations` | `interface` declarations | Jumps to all structs that implement the interface |
| `implement N interfaces` | `struct` declarations | Jumps to all interfaces the struct satisfies |

The implementations and interfaces lenses (`velvet.showReferences`) work out of the box — clicking them opens a references panel. The run lenses fire custom commands (`velvet.runWorkspace`, `velvet.runFile`, `velvet.runTests`) that must be mapped to CLion run configurations to do anything.

To wire the run lenses to CLion's terminal:

1. Open **Settings** → **Tools** → **LSP4IJ** → **Language Servers** → select **velvet** → **Configuration**.
2. Under **Client-side commands**, add a command mapping for each of the three run commands:

   | Command ID | Action |
   |---|---|
   | `velvet.runWorkspace` | Run `v run $FOLDER_PATH` in the terminal |
   | `velvet.runFile` | Run `v run $FILE_PATH` in the terminal |
   | `velvet.runTests` | Run `v test $FILE_PATH` in the terminal |

3. Click **OK**.

> **Note:** The exact UI for client-side command mappings depends on the LSP4IJ version. If the option is not available in your version, the run lenses will still appear in the gutter but clicking them will be a no-op. The implementations and interfaces lenses are unaffected and always work.

#### Verifying the connection

Open a V project in CLion and open any `.v` file. Check the status bar at the bottom of the editor window — an LSP indicator should appear. You can also open the **Event Log** (**View** → **Tool Windows** → **Event Log**) and look for a message confirming the language server started.

Test that features are working:

- **Hover** — hold the cursor over a function or struct name; a documentation popup should appear.
- **Completion** — type inside a function body and trigger completion with **Ctrl+Space**; velvet's suggestions should appear.
- **Go to Definition** — place the cursor on a symbol and press **Ctrl+B** (or **Ctrl+Click**); CLion should navigate to the declaration.
- **Diagnostics** — introduce a type error; a red underline and error tooltip should appear after a short delay.
- **Code Lens** — hover over `fn main()` or an `interface` declaration; lens annotations should appear above the line.

---

## Troubleshooting

### Default keymaps produce nothing (grt, grr, grn, gO)

The Neovim default LSP keymaps (`grt` = type definition, `grr` = references, `grn` = rename, `gO` = document symbols, `gri` = implementation, `gra` = code action) only activate when velvet is **actually attached to the current buffer**. The server process appearing to start is not sufficient — it must complete the LSP handshake and attach.

Work through these steps in order:

#### Step 1 — Confirm attachment

Open a `.v` file, then run:

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
```

You should see a table with a `name = "velvet"` entry. If the table is empty, velvet is not attached to the buffer — the keymaps will never fire. Continue to the steps below to find out why.

#### Step 2 — Check the filetype

Run `:set ft?` while a `.v` file is open. It must print `filetype=v`.

- If it prints `filetype=verilog` or is blank, Neovim has not detected the V filetype. Add the `vim.filetype.add` block from the Neovim setup section to your `init.lua` and ensure it is loaded before `vim.lsp.enable('velvet')` or `lspconfig.velvet.setup({})` is called.
- `.v` is ambiguous — Verilog also uses it, and without explicit registration, Neovim may silently pick the wrong filetype or none at all.

#### Step 3 — nvim-lspconfig users: do not use `lspconfig.v_analyzer.setup()`

The built-in `v_analyzer` config hardcodes `cmd = { 'v-analyzer' }`. Using it for velvet means Neovim tries to launch the wrong binary (or nothing, if `v-analyzer` is not on your PATH). Velvet never starts, so the keymaps never work.

Register velvet as a **new** config using `configs.velvet = { ... }` as shown in the [nvim-lspconfig section](#older-neovim-nvim-lspconfig) above. Do not call `lspconfig.v_analyzer.setup({})` alongside it.

#### Step 4 — Verify `--stdio` is in `cmd`

Ensure your `cmd` table includes `'--stdio'` as the second element:

```lua
cmd = { '/path/to/velvet', '--stdio' },
```

Without `--stdio`, the handshake may fail silently on some systems, leaving the server running but unattached.

#### Step 5 — Check root detection

Velvet must find a root marker to attach. Run:

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 })[1].root_dir)
```

It should print your project root. If it prints `nil`, velvet could not find a root marker.

- Ensure `root_markers = { 'v.mod', '.git' }` is a **flat list**, not a nested table. Using `{ { 'v.mod' }, '.git' }` treats each inner table as a conjunction — if `v.mod` is absent, that group fails entirely.
- If your project has neither a `v.mod` nor a `.git`, add `single_file_support = true` (nvim-lspconfig) or open the file from within a directory that has one.

#### Step 6 — Check `:checkhealth vim.lsp`

Run `:checkhealth vim.lsp` **with a `.v` file open**. If you run it without a V buffer active, it will report no clients — that is expected. With a V file open, velvet should appear under **Active Clients**. Any warnings or errors reported by checkhealth will point at the remaining misconfiguration.

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
