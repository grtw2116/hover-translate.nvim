---@type hover_translate.Provider
local M = {
	build_request = function(text, config)
		local url = "https://api-free.deepl.com/v2/translate"
		local body = vim.fn.json_encode({ text = { text }, target_lang = config.target_lang:upper() })
		local headers = {
			["Authorization"] = "DeepL-Auth-Key " .. config.api_key,
			["Content-Type"] = "application/json",
		}
		return url, body, headers
	end,
	parse_response = function(result)
		local parsed = result.translations and result.translations[1].text or nil
		if parsed == nil then
			error(result)
		end

		return parsed
	end,
}

return M
