--!strict
-- TweenUtil.lua

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage:WaitForChild("Maid"))
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TweenUtil = {}
TweenUtil.__index = TweenUtil

-- DEFINIÇÃO DE TIPOS --

export type TweenProperties = {
	BackgroundTransparency: number?,
	TextTransparency: number?,
	GroupTransparency: number?, -- Suporte para CanvasGroup 
	Position: UDim2?,
	Size: UDim2?,
	BackgroundColor3: Color3?,
	Text: string?,
	Sound: Sound?, 
}

-- Rastreia animações ativas para evitar que uma atropele a outra
local activeTweens: {[GuiObject]: Tween} = {}

-- FUNÇÃO CENTRAL  --

local function safePlayTween(
	frame: GuiObject?,
	properties: TweenProperties,
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	onComplete: (() -> ())?
)
	-- Segurança: Garante que o objeto existe
	if not frame or not frame:IsA("GuiObject") then
		error("TweenUtil: Objeto de interface inválido!")
	end

	duration = duration or Config.UI.DefaultTweenTime
	if duration <= 0 then
		error("TweenUtil: A duração precisa ser maior que zero.")
	end

	-- Suporte inteligente para CanvasGroup
	if frame:IsA("CanvasGroup") and properties.BackgroundTransparency then
		properties.GroupTransparency = properties.BackgroundTransparency
	end

	-- se houver um som definido, ele toca no início da animação
	if properties.Sound then
		properties.Sound:Play()
	end

	-- Cancela animações antigas no mesmo objeto para evitar conflitos
	if activeTweens[frame] then
		activeTweens[frame]:Cancel()
		activeTweens[frame] = nil
	end

	local info = TweenInfo.new(
		duration,
		easingStyle or Config.UI.DefaultTweenStyle,
		easingDirection or Config.UI.DefaultTweenDirection
	)

	-- Removemos o Sound da tabela de propriedades antes de criar o Tween
	-- porque o TweenService não sabe animar um objeto "Sound"
	local cleanProperties = {}
	for k, v in pairs(properties) do
		if k ~= "Sound" then
			cleanProperties[k] = v
		end
	end

	local tween = TweenService:Create(frame, info, cleanProperties)
	activeTweens[frame] = tween
	
	tween.Completed:Connect(function()
		activeTweens[frame] = nil
		if onComplete then onComplete() end
	end)
	
	tween:Play()

	return {
		Cancel = function()
			if activeTweens[frame] then
				activeTweens[frame]:Cancel()
				activeTweens[frame] = nil
			end
		end
	}
end

TweenUtil.PlayTween = safePlayTween

--  ATALHOS (HELPERS) --

-- Abre um frame com fade e som opcional
function TweenUtil.FadeIn(frame: GuiObject, duration: number?, sound: Sound?, onComplete: (() -> ())?)
	return safePlayTween(frame, {BackgroundTransparency = 0, Sound = sound}, duration, nil, nil, onComplete)
end

-- Fecha um frame com fade e som opcional
function TweenUtil.FadeOut(frame: GuiObject, duration: number?, sound: Sound?, onComplete: (() -> ())?)
	return safePlayTween(frame, {BackgroundTransparency = 1, Sound = sound}, duration, nil, nil, onComplete)
end

-- Move o frame (ex: menu deslizando lateralmente)
function TweenUtil.TweenPosition(frame: GuiObject, position: UDim2, duration: number?, sound: Sound?, onComplete: (() -> ())?)
	return safePlayTween(frame, {Position = position, Sound = sound}, duration, nil, nil, onComplete)
end

-- Muda o tamanho (ex: botão pulsando ao clicar)
function TweenUtil.TweenSize(frame: GuiObject, size: UDim2, duration: number?, sound: Sound?, onComplete: (() -> ())?)
	return safePlayTween(frame, {Size = size, Sound = sound}, duration, nil, nil, onComplete)
end

--  EFEITO MÁQUINA DE ESCREVER  --

function TweenUtil.TypeText(maid: Maid, label: TextLabel | TextButton, fullText: string, delay: number?, sound: Sound?, onComplete: (() -> ())?)
	delay = delay or Config.Text.DefaultTypingSpeed
	label.Text = ""

	local running = true
	local paused = false
	
	local co = coroutine.create(function()
		for i = 1, #fullText do
			if not running then break end
			while paused do task.wait() end
			
			label.Text = fullText:sub(1, i)
			
			-- Toca o som de "tecla" se ele existir
			if sound then sound:Play() end
			
			task.wait(delay)
		end
		if running and onComplete then onComplete() end
	end)

	coroutine.resume(co)

	local controller = {
		Pause = function() paused = true end,
		Resume = function() paused = false end,
		Cancel = function() running = false end
	}

	maid:Give({
		Destroy = function() running = false end
	})

	return controller
end

return TweenUtil
