-- Async LSP Hover Translator using plenary.nvim Job
local M = {}
local api = vim.api
local lsp = vim.lsp
local util = vim.lsp.util
local Job = require("plenary.job")
local cache_dir = vim.fn.stdpath("cache") .. "/hover-translate"

vim.fn.mkdir(cache_dir, "p")

-- Default configuration
M.config = {
	target_lang = "ja",
	provider = "google", -- "google" or "deepl"
	api_key = nil,
	silent = false,
	hover_window = {}, -- options for vim.util.open_floating_preview()
}

-- Merge user config with validation
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	-- Validate provider
	if not vim.tbl_contains({ "google", "deepl" }, M.config.provider) then
		vim.notify(
			"[hover-translate.nvim] Unsupported translation provider: " .. tostring(M.config.provider),
			vim.log.levels.WARN
		)
	end
	-- Ensure api_key is set
	if not M.config.api_key then
		vim.notify("[hover-translate.nvim] API key not set", vim.log.levels.WARN)
	end
end

-- Build request URL and payload
local function build_request(text)
	local url, body
	if M.config.provider == "google" then
		url = string.format("https://translation.googleapis.com/language/translate/v2?key=%s", M.config.api_key)
		body = vim.fn.json_encode({ q = text, target = M.config.target_lang, format = "text" })
	else
		url = string.format("https://api-free.deepl.com/v2/translate?auth_key=%s", M.config.api_key)
		body = vim.fn.json_encode({ text = { text }, target_lang = M.config.target_lang:upper() })
	end
	return url, body
end

local function compute_cache_key(text)
	local client = vim.lsp.get_clients({ bufnr = 0 })[1]

	---@type table
	local cmd = type(client.config.cmd) == "table" and client.config.cmd or {}
	local lsp_id = client and (client.name .. table.concat(cmd, " ")) or ""
	local hash_input = table.concat({
		M.config.provider,
		M.config.target_lang,
		vim.bo.filetype,
		lsp_id,
		text,
	}, "\n")

	return vim.fn.sha256(hash_input)
end

local function translate_text_async(text, on_result)
	-- Check file cache
	local key = compute_cache_key(text)
	local cache_file = cache_dir .. "/" .. key .. ".json"
	if vim.uv.fs_stat(cache_file) then
		-- Read from JSON
		local lines = vim.fn.readfile(cache_file)
		local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
		if ok and data.translated then
			vim.schedule(function()
				on_result(data.translated)
			end)
			return
		end
	end

	-- If there's no cache or reading cache fails, then send translation request
	local url, body = build_request(text)
	Job:new({
		command = "curl",
		args = { "-s", "-X", "POST", "-H", "Content-Type: application/json", url, "-d", body },
		on_exit = vim.schedule_wrap(function(j_self, return_val)
			local resp = table.concat(j_self:result(), "")

			if return_val ~= 0 then
				vim.notify("HTTP error: " .. return_val, vim.log.levels.ERROR)
				return on_result(text)
			end

			local ok, result = pcall(vim.fn.json_decode, resp)

			if not ok or not result then
				vim.notify("Invalid JSON response", vim.log.levels.ERROR)
				return on_result(text)
			end

			local translated = text
			if M.config.provider == "google" then
				translated = result.data and result.data.translations[1].translatedText or text
			else
				translated = result.translations and result.translations[1].text or text
			end

			-- Save translated text to cache file
			local data = { translated = translated }
			local ok, err = pcall(vim.fn.writefile, { vim.fn.json_encode(data) }, cache_file)
			if not ok then
				vim.notify("[hover-translate.nvim] Writing cache failed: " .. err, vim.log.levels.WARN)
			end

			vim.notify("Translation completed", vim.log.levels.INFO)
			on_result(translated)
		end),
	}):start()
end

-- Override hover to translate contents asynchronously
function M.hover(config)
	config = config or {}
	config.silent = M.config.silent
	config.hover_window = M.config.hover_window

	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if vim.tbl_isempty(clients) then
		if not config.silent then
			vim.notify("[hover-translate.nvim] No LSP client available", vim.log.levels.WARN)
		end
		return
	end

	local client = clients[1] -- TODO: refine client selection
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)

	lsp.buf_request_all(0, "textDocument/hover", params, function(results, ctx)
		if api.nvim_get_current_buf() ~= ctx.bufnr then
			return
		end

		-- Collect first non-error hover content
		local raw = {}
		for _, resp in pairs(results) do
			if not resp.err and resp.result then
				raw = resp.result.contents
				break
			end
		end
		if vim.tbl_isempty(raw) then
			if not config.silent then
				vim.notify("[hover-translate.nvim] No hover information", vim.log.levels.WARN)
			end
			return
		end

		-- Convert to markdown text
		local lines = util.convert_input_to_markdown_lines(raw)
		local text = table.concat(lines, "\n")

		-- Async translate and then show floating
		translate_text_async(text, function(translated)
			local tlines = vim.split(translated, "\n")
			local opts = vim.tbl_deep_extend("force", {
				focusable = true,
				focus_id = "hover-translate",
			}, config.hover_window or {})
			util.open_floating_preview(tlines, "markdown", opts)
		end)
	end)
end

return M
