---@type hover_translate.Provider
local M = {
	build_request = function(text, config)
		local url = "https://translation.googleapis.com/language/translate/v2"
		local body = vim.fn.json_encode({
			q = text,
			target = config.target_lang,
			format = "text",
		})
		local headers = {
			["X-goog-api-key"] = config.api_key,
			["Content-Type"] = "application/json",
		}
		return url, body, headers
	end,
	parse_response = function(result)
		local parsed = result.data and result.data.translations[1].translatedText or nil
		if parsed == nil then
			error("[hover-translate.nvim] Cannot translate: " .. result)
		end

		return parsed
	end,
}

return M
