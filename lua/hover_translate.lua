local M = {}
local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util

-- Default configuration
M.config = {
	target_lang = "ja", -- translation target language (e.g., 'ja' for Japanese)
	provider = "google", -- translation API provider ('google' or 'deepl')
	api_key = nil, -- your API key for the translation service
	silent = false, -- suppress notifications
}

-- Merge user config
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

-- Perform translation by calling external API
local function translate_text(text)
	if not M.config.api_key then
		vim.notify("Translation API key not set", vim.log.levels.ERROR)
		return text
	end

	-- Build request depending on provider
	local url, body
	if M.config.provider == "google" then
		url = string.format("https://translation.googleapis.com/language/translate/v2?key=%s", M.config.api_key)
		body = vim.fn.json_encode({
			q = text,
			target = M.config.target_lang,
		})
	elseif M.config.provider == "deepl" then
		url = string.format("https://api.deepl.com/v2/translate?auth_key=%s", M.config.api_key)
		body = vim.fn.json_encode({
			text = text,
			target_lang = M.config.target_lang:upper(),
		})
	else
		vim.notify("Unsupported translation provider: " .. M.config.provider, vim.log.levels.ERROR)
		return text
	end

	-- Send HTTP request (using plenary.nvim or curl)
	local ok, resp = pcall(function()
		return vim.fn.system({
			"curl",
			"-s",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			url,
			"-d",
			body,
		})
	end)

	if not ok then
		vim.notify("Translation request failed: " .. resp, vim.log.levels.ERROR)
		return text
	end

	local result = vim.fn.json_decode(resp)
	if M.config.provider == "google" then
		return result.data and result.data.translations[1].translatedText or text
	else -- deepl
		return result.translations and result.translations[1].text or text
	end
end

-- Override hover to translate contents
function M.hover(config)
	config = config or {}
	config.silent = M.config.silent

	-- reuse original hover logic to fetch raw contents
	local client = vim.lsp.get_clients({ bufnr = 0 })[1]
	local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
	lsp.buf_request_all(0, "textDocument/hover", params, function(results, ctx)
		if api.nvim_get_current_buf() ~= ctx.bufnr then
			return
		end

		-- collect successful responses
		local raw = {}
		for _, resp in pairs(results) do
			if not resp.err and resp.result then
				raw = resp.result.contents
				break -- take first available
			end
		end
		if vim.tbl_isempty(raw) then
			if not config.silent then
				vim.notify("No hover information")
			end
			return
		end

		-- convert to markdown lines
		local lines = util.convert_input_to_markdown_lines(raw)
		local text = table.concat(lines, "\n")

		-- translate
		local translated = translate_text(text)
		local translated_lines = vim.split(translated, "\n", { trimempty = true })

		-- show floating preview
		util.open_floating_preview(translated_lines, "markdown", config)
	end)
end

return M
