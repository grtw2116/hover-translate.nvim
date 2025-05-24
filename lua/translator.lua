local M = {}
local Job = require("plenary.job")

local cache_dir = vim.fn.stdpath("cache") .. "/hover-translate"
vim.fn.mkdir(cache_dir, "p")

---@type hover_translate.Provider[]
local providers = {
	google = require("provider.google"),
	deepl = require("provider.deepl"),
	deepl_free = require("provider.deepl_free"),
}

---@param text string text to translate
---@param config hover_translate.TranslatorInternalConfig
---@return string hash hash value (sha256)
local function compute_cache_key(text, config)
	local client = vim.lsp.get_clients({ bufnr = 0 })[1]

	local cmd = type(client.config.cmd) == "table" and client.config.cmd or {}
	local lsp_id = client and (client.name .. table.concat(cmd, " ")) or ""
	local hash_input = table.concat({
		config.provider,
		config.target_lang,
		vim.bo.filetype,
		lsp_id,
		text,
	}, "\n")

	return vim.fn.sha256(hash_input)
end

---@param text string text to translate
---@param config hover_translate.TranslatorInternalConfig
---@param on_result fun(text: string): nil
function M.translate(text, config, on_result)
	local provider = providers[config.provider]
	if provider == nil then
		vim.notify("[hover-translate.nvim] Invalid provider: " .. config.provider, vim.log.levels.ERROR)
		return
	end

	-- Check file cache
	local key = compute_cache_key(text, config)
	local cache_file = cache_dir .. "/" .. key .. ".json"
	if vim.uv.fs_stat(cache_file) then
		-- Read from JSON
		local lines = vim.fn.readfile(cache_file)
		local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
		if ok and data.translated then
			vim.notify("[hover-translate.nvim] Loaded from cache file", vim.log.levels.INFO)
			vim.schedule(function()
				on_result(data.translated)
			end)
			return
		end
	end

	-- If there's no cache or reading cache fails, then send translation request
	local url, body, headers = provider.build_request(text, config)

	-- Prepare curl arguments
	local args = { "-s", "-X", "POST" }

	-- Add headers
	headers = headers or {}
	for key, value in pairs(headers) do
		table.insert(args, "-H")
		table.insert(args, key .. ": " .. value)
	end

	-- Add URL and body
	table.insert(args, url)
	table.insert(args, "-d")
	table.insert(args, body)

	Job:new({
		command = "curl",
		args = args,
		on_exit = vim.schedule_wrap(function(j_self, return_val)
			local resp = table.concat(j_self:result(), "")

			if return_val ~= 0 then
				vim.notify("[hover-translate.nvim] HTTP error: " .. return_val, vim.log.levels.ERROR)
				return
			end

			local ok, result = pcall(vim.fn.json_decode, resp)
			if not ok or not result then
				vim.notify("[hover-translate.nvim] Cannot decode JSON response", vim.log.levels.ERROR)
				return
			end

			local ok, translated = pcall(provider.parse_response, result)
			if not ok then
				vim.notify(
					"[hover-translate.nvim] Invalid JSON response: " .. vim.inspect(result),
					vim.log.levels.ERROR
				)
				return
			end

			-- Save translated text to cache file
			local data = { translated = translated }
			local ok, err = pcall(vim.fn.writefile, { vim.fn.json_encode(data) }, cache_file)
			if not ok then
				vim.notify("[hover-translate.nvim] Writing cache failed: " .. err, vim.log.levels.WARN)
			end

			on_result(translated)
		end),
	}):start()
end

return M
