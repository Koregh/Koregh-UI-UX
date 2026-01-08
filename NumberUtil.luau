--!Strict
-- NumberUtil.lua
-- @module NumberUtil


local NumberUtil = {}

-- Lista de sufixos para escalas de magnitude (Suporta até Decilhões)
local SUFFIXES = {"", "K", "M", "B", "T", "Q", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}


-- @desc Formata números com sufixos (Ex: 1.5M, -10K)
-- @param value: O número a ser formatado
-- @param precision: (Opcional) Casas decimais após o ponto (Padrão: 1)
function NumberUtil.FormatAbbreviated(value: number, precision: number?): string
	local p = precision or 1
	local sign = value < 0 and "-" or ""
	local absValue = math.abs(value)
	
	if absValue < 1000 then 
		return sign .. tostring(math.floor(absValue)) 
	end
	
	local index = math.floor(math.log10(absValue) / 3)
	local short = absValue / (10 ^ (index * 3))
	
	-- Garante que o índice não estoure a tabela de sufixos
	local suffix = SUFFIXES[index + 1] or "++"
	
	-- Formatação dinâmica: remove zeros desnecessários (Ex: 1.0K -> 1K)
	local formatStr = "%." .. p .. "f"
	local formatted = string.format(formatStr, short):gsub("%.?0+$", "")
	
	return sign .. formatted .. suffix
end

-- @desc Formata com Espaços (Ex: 1 500 000)
function NumberUtil.FormatSpaces(value: number): string
	local sign = value < 0 and "-" or ""
	local absValue = math.abs(math.floor(value))
	local formatted = tostring(absValue)
	
	local k: number
	while true do
		-- Adiciona espaço a cada 3 dígitos
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
		if k == 0 then break end
	end
	
	return sign .. formatted
end

-- @desc Formata com Vírgulas (Ex: 1,500,000)
function NumberUtil.FormatCommas(value: number): string
	-- Reaproveita a lógica de espaços e substitui por vírgula
	local withSpaces = NumberUtil.FormatSpaces(value)
	return string.gsub(withSpaces, " ", ",")
end


-- @desc Converte segundos em string formatada (Ex: 75 -> "01:15")
-- @param seconds: Total de segundos
-- @param useHours: (Opcional) Se true, retorna "00:00:00", se false "00:00"
function NumberUtil.FormatTime(seconds: number, useHours: boolean?): string
	local s = math.max(math.floor(seconds), 0)
	
	if useHours then
		local h = math.floor(s / 3600)
		local m = math.floor((s % 3600) / 60)
		local sec = s % 60
		return string.format("%02d:%02d:%02d", h, m, sec)
	else
		local m = math.floor(s / 60)
		local sec = s % 60
		return string.format("%02d:%02d", m, sec)
	end
end

-- @desc Interpolação Linear entre dois números
-- @param start: Valor de origem
-- @param target: Valor de destino
-- @param alpha: Progresso (0 a 1)
-- @return O número intermediário para ser usado na UI
function NumberUtil.Lerp(start: number, target: number, alpha: number): number
	return start + (target - start) * alpha
end

return NumberUtil
