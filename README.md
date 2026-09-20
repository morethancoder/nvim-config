# Neovim Configuration

My Neovim setup, built around [packer.nvim](https://github.com/wbthomason/packer.nvim), lsp-zero, Telescope,
Treesitter, Harpoon and a handful of colorschemes.

You can install it two ways: run the [interactive install script](#option-1-install-script-recommended), or follow the
[manual steps](#option-2-manual-install).

## Option 1: install script (recommended)

`install.sh` walks you through the whole setup in a minimal terminal UI and does the copying, renaming and installing
for you. It works on macOS and Linux (x86_64 and arm64).

```bash
git clone https://github.com/morethancoder/nvim-config.git ~/nvim-config
cd ~/nvim-config
./install.sh
```

Clone it somewhere other than `~/.config/nvim`; the script installs a copy there, and you can delete the clone afterwards.

The script has seven steps and asks before it changes anything:

| Step | What it does |
| --- | --- |
| 1. Environment | Detects your OS, CPU and package manager (Homebrew, apt, dnf or pacman). |
| 2. Your name | Asks for a name and uses it instead of `morethancoder` for the Lua module (`lua/<name>/`) and every reference to it. |
| 3. Neovim | Checks for Neovim 0.11.x. If it is missing or a different version, offers to install a checksum-verified 0.11.7 into `~/.local` and link it from `~/.local/bin`. Existing installs are left alone. |
| 4. Tools | Lists what is installed (`git`, `curl`, `unzip`, `tar`, a C compiler, `make`, `node`, `ripgrep`, and optionally `go`, `stylua`, a clipboard tool, a Nerd Font) and offers to install what is missing. |
| 5. Config | Builds the config in a staging folder, checks it, moves any existing `~/.config/nvim` to `~/.config/nvim.bak-<timestamp>`, then puts the new one in place. Also creates `~/.vim/undodir`. |
| 6. Plugins | Installs packer.nvim, runs `:PackerSync`, and builds the Treesitter parsers. |
| 7. Language servers | Installs the servers you pick through Mason (web: TypeScript, HTML, Tailwind, plus HTMX when `cargo` is available; Go: `gopls`, `templ`). |

Safety:

- Nothing is deleted. An existing config is moved to a timestamped backup, and restored if the install is interrupted.
- The new config is verified in a staging folder before it replaces anything.
- It refuses to run as root; `sudo` is only used to install system packages on Linux, and only after you agree.
- `--dry-run` shows everything it would do without changing anything.
- If a step fails, the full log is kept and its path is printed.

Options:

```text
-n, --name NAME   name for your config module (skips the prompt)
-y, --yes         accept the default answer to every question
    --skip-deps   do not check or install system tools
    --dry-run     show what would happen without changing anything
-h, --help        show this help
```

The name must be 2-32 characters: lowercase letters, digits or `_`, starting with a letter. Spaces and `-` are turned into `_`.

When it finishes, set a [Nerd Font](https://www.nerdfonts.com/) as your terminal font, open `nvim` and run `:checkhealth`.

## Option 2: manual install

### Prerequisites

| Requirement | Why |
| --- | --- |
| **Neovim 0.11.x** | Required. The `master` branch of nvim-treesitter used here does not support 0.12. |
| `git` | packer.nvim and every plugin are cloned with it. |
| A C compiler (`clang`/`gcc`) and `make` | Compiles the Treesitter parsers. |
| `curl`, `unzip`, `tar` | Used by Mason to download and unpack language servers. |
| `node` + `npm` | Needed by Mason to install the `ts_ls`, `html` and `tailwindcss` language servers. |
| `cargo` | Needed by Mason to install `htmx-lsp`. Optional. |
| `go` | Needed by Mason to install `gopls` and `templ`. Only if you write Go/templ. |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep) | Telescope grep (`<leader>ss`) and `:TodoTelescope`. |
| [`stylua`](https://github.com/JohnnyMorganz/StyLua) | Lua formatting through formatter.nvim. Optional. |
| A [Nerd Font](https://www.nerdfonts.com/) | Icons in lualine. Set it as your terminal font. |
| Clipboard tool | `clipboard=unnamedplus` is on. macOS works out of the box; on Linux install `xclip` (X11) or `wl-clipboard` (Wayland). |

Install Neovim from [neovim.io](https://neovim.io/) or a package manager, and check it with `nvim --version`.
Package managers may ship a newer Neovim than 0.11.x; the install script handles that for you.

### Steps

1. Move any existing config out of the way:

   ```bash
   mv ~/.config/nvim ~/.config/nvim.bak
   ```

2. Clone this repo:

   ```bash
   git clone https://github.com/morethancoder/nvim-config.git ~/.config/nvim
   ```

   The Lua module is called `morethancoder`. To use your own name, rename `lua/morethancoder/` and replace every
   `morethancoder` in `init.lua`, `lua/` and `after/` (the install script does this for you).

3. Create the undo directory used by `undofile`:

   ```bash
   mkdir -p ~/.vim/undodir
   ```

4. Start Neovim. You will see errors about missing plugins, which is expected at this point.

5. Load the plugin list, then install the plugins. packer.nvim itself is cloned automatically when the plugin list loads:

   ```vim
   :so ~/.config/nvim/lua/morethancoder/packer.lua
   :PackerSync
   ```

6. Quit and reopen Neovim. Treesitter parsers (`javascript`, `typescript`, `go`, `rust`, `c`, `lua`, `vim`, `vimdoc`,
   `query`, `python`, `templ`) install on their own; run `:TSUpdate` if any are missing.

7. Install the language servers you need with Mason (`:Mason`, then press `i` on a server). This config sets up
   `gopls`, `ccls`, `cmake`, `ts_ls`, `templ`, `html`, `htmx` and `tailwindcss`. They are **not** installed automatically.

8. Run `:checkhealth` to confirm everything is in order.

## Pinned versions

Some plugins are pinned on purpose in `lua/morethancoder/packer.lua`; do not bump them without migrating the config:

- `nvim-treesitter` is on the `master` branch (the `main` rewrite uses a different API).
- `lsp-zero.nvim` is on `v2.x`, with `nvim-lspconfig` at `v2.5.0`, `mason.nvim` at `v1.11.0` and
  `mason-lspconfig.nvim` at `v1.32.0`.
- `telescope.nvim` is at `v0.2.2`.

## Notes

- Leader key is `<Space>`. Keymaps live in `lua/morethancoder/remap.lua` and plugin config in `after/plugin/`.
- The colorscheme is set in `after/plugin/colors.lua` (`ColorMyCode()`, default `github_dark_high_contrast`).
- Markdown pipe tables are aligned so the source stays readable: `:MdTableAlign` (or `<leader>ta`) pads the columns, and
  it runs on save (turn that off with `vim.g.markdown_table_autoalign = false`). Line wrap is switched off while the cursor
  is on a table row, so wide tables scroll sideways instead of breaking the grid. See `after/ftplugin/markdown.lua`.
- Codeium is installed but disabled (`vim.g.codeium_enabled = false` in `set.lua`). Set it to `true` and run
  `:Codeium Auth` to use it.
- `plugin/packer_compiled.lua` is generated by packer and contains paths for your machine. It is not part of the repo
  (see `.gitignore`); if it ever causes problems, delete it and run `:PackerCompile`.

## Human notes for AI agents (Markdown)

In a Markdown file, type `!` at the start of a line and pick a suggestion:

- `!context` – background for AI agents that is not part of the document
- `!request` – an instruction for the AI agent to act on and then remove

Both expand to a hidden HTML comment (`<!-- HUMAN_CONTEXT … -->` / `<!-- HUMAN_REQUEST … -->`), so the notes never
show up in rendered Markdown. They are highlighted by todo-comments and listed by `:TodoTelescope`.
See `after/plugin/human-notes.lua`.
