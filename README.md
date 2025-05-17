# hover-translate.nvim

Translate LSP hover documentation in Neovim using Google Translate or DeepL.

> **Note**: This plugin is currently in **ALPHA** stage. Features may change and bugs might be present. Use at your own risk.

## ✨ Features

- Translates `textDocument/hover` output from LSP
- Supports Google Translate and DeepL
- Displayed in floating window
- Simple setup & configuration

## 📦 Installation (with [lazy.nvim](https://github.com/folke/lazy.nvim))

```lua
{
  "grtw2116/hover-translate.nvim",
  config = function()
    require("hover_translate").setup({
      target_lang = "ja", -- Japanese
      provider = "google", -- or "deepl"
      api_key = os.getenv("TRANSLATE_API_KEY"), -- recommend env vars
    })

    vim.keymap.set("n", "K", require("hover_translate").hover, { desc = "LSP Hover (translated)" })
  end,
}
