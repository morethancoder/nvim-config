# Neovim Configuration

Welcome to my Neovim configuration! 

## Prerequisites

Before you get started, make sure you have Neovim installed on your system. 
You can download and install Neovim from the official website: [Neovim](https://neovim.io/)

## Installation

To install my Neovim configuration, follow these simple steps:

```bash
git clone https://github.com/morethancoder/nvim-config.git ~/.config/nvim
```


Then open Neovim and install the plugins ([packer.nvim](https://github.com/wbthomason/packer.nvim) bootstraps itself):

```vim
:so ~/.config/nvim/lua/morethancoder/packer.lua
:PackerSync
```

Restart Neovim afterwards.

## Compatibility

Use **Neovim 0.11.x**. The `master` branch of nvim-treesitter used here does not support Neovim 0.12, and
nvim-lspconfig / mason are pinned to the last versions that work with lsp-zero v2 (see `lua/morethancoder/packer.lua`).

## Human notes for AI agents (Markdown)

In a Markdown file, type `!` at the start of a line and pick a suggestion:

- `!context` – background for AI agents that is not part of the document
- `!request` – an instruction for the AI agent to act on and then remove

Both expand to a hidden HTML comment (`<!-- HUMAN_CONTEXT … -->` / `<!-- HUMAN_REQUEST … -->`), so the notes never
show up in rendered Markdown. They are highlighted by todo-comments and listed by `:TodoTelescope`.
See `after/plugin/human-notes.lua`.
