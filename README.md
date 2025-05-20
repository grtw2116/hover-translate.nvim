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
    target_lang = "ja", -- target language
    provider = "google", -- or "deepl"
    api_key = os.getenv("TRANSLATE_API_KEY"), -- recommend env vars
    silent = false, -- suppress notifications
    hover_window = { -- options for vim.util.open_floating_preview()
      border = "rounded",
    },
  }
  config = function(_, opts)
    require("hover_translate").setup(opts)
    vim.keymap.set("n", "K", require("hover_translate").hover, { desc = "LSP Hover (translated)" })
  end,
}
```

## ⚙️ Configuration

The plugin comes with sensible defaults, but you can customize it with these options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `target_lang` | string | `"ja"` | Target language for translation |
| `provider` | string | `"google"` | Translation provider (`"google"` or `"deepl"`) |
| `api_key` | string | `nil` | API key for the selected provider |
| `silent` | boolean | `false` | When true, suppresses most notifications |
| `opts` | table | `{}` | Options passed to `vim.lsp.util.open_floating_preview()` |

## 📦 Cache System

Translations are cached in `vim.fn.stdpath("cache") .. "/hover-translate"` to improve performance and reduce API calls. The cache key is generated based on:

- Translation provider
- Target language
- Current filetype
- LSP client information
- Original hover text

