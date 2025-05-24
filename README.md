# hover-translate.nvim

Translate LSP hover documentation in Neovim using Google Translate or DeepL.

> **Note**: This plugin is currently in **ALPHA** stage. Features may change and bugs might be present. Use at your own risk.

## ✨ Features

- Translates `textDocument/hover` output from LSP
- Supports Google Translate and DeepL
- Asynchronous translation with caching for better performance

## 📦 Installation (with [lazy.nvim](https://github.com/folke/lazy.nvim))

```lua
{
  "grtw2116/hover-translate.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    translator = {
      target_lang = "ja",
      provider = "google", -- "google", "deepl", or "deepl_free"
      api_key = os.getenv("TRANSLATE_API_KEY"),
    },
    hover_window = { -- options for vim.util.open_floating_preview()
      border = "rounded",
    },
  },
  keys = {
    {
      "gK",
      function()
        require("hover_translate").hover()
      end,
      desc = "LSP Hover (translated)",
    },
  },
}
```

## 📦 Cache System

Translations are cached in `vim.fn.stdpath("cache") .. "/hover-translate"` to improve performance and reduce API calls. The cache key is generated based on:

- Translation provider
- Target language
- Current filetype
- LSP client information
- Original hover text

