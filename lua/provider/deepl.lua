---@type hover_translate.Provider
local M = {
	build_request = function(text, config)
		local url = string.format("https://api-free.deepl.com/v2/translate?auth_key=%s", config.api_key)
		local body = vim.fn.json_encode({ text = { text }, target_lang = config.target_lang:upper() })
		return url, body
	end,
	parse_response = function(result, default_text)
		return result.translations and result.translations[1].text or default_text
	end,
}

return M
