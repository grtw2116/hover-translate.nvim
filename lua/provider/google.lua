---@type hover_translate.Provider
local M = {
	build_request = function(text, config)
		local url = string.format("https://translation.googleapis.com/language/translate/v2?key=%s", config.api_key)
		local body = vim.fn.json_encode({ q = text, target = config.target_lang, format = "text" })
		return url, body
	end,
	parse_response = function(result, default_text)
		return result.data and result.data.translations[1].translatedText or default_text
	end,
}

return M
