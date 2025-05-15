# hover-translate.nvim

Translate LSP hover documentation in Neovim using Google Translate or DeepL.

## ✨ Features

- Translates `textDocument/hover` output from LSP
- Supports Google Translate and DeepL
- Displayed in floating window
- Simple setup & configuration

## 📦 Installation (with [lazy.nvim](https://github.com/folke/lazy.nvim))

```lua
{
  "your-username/hover-translate.nvim",
  config = function()
    require("hover_translate").setup({
      target_lang = "ja", -- Japanese
      provider = "google", -- or "deepl"
      api_key = os.getenv("TRANSLATE_API_KEY"), -- recommend env vars
    })

    vim.keymap.set("n", "K", require("hover_translate").hover, { desc = "LSP Hover (translated)" })
  end,
}
