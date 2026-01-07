--!strict
-- UIManager.lua

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Importando suas ferramentas
local TweenUtil = require(script.Parent:WaitForChild("TweenUtil"))
local UIState = require(script.Parent:WaitForChild("UIState"))
local Config = require(script.Parent:WaitForChild("Config"))

local UIManager = {}

--  CONFIGURAÇÃO DE CAMADAS (LAYERS) --
-- Isso garante que nada importante fique escondido atrás de janelas comuns
local LAYERS = {
	HUD = 1,
	SCREEN = 10,     -- Inventário, Loja, etc.
	OVERLAY = 20,    -- Modals, Pop-ups de confirmação
	NOTIFICATION = 30 -- Avisos de Erro, Mensagens do Sistema
}

-- ESTADO INTERNO  --
local CurrentFrame: GuiObject? = nil
local CurrentState: any = nil
local ActiveOverlays: {[GuiObject]: any} = {}

--  FUNÇÕES AUXILIARES --

-- Busca o primeiro botão clicável para dar foco (Gamepad/Teclado)
local function setFocusToFrame(frame: GuiObject)
	local firstButton = frame:FindFirstChildWhichIsA("GuiButton", true)
	if firstButton then
		GuiService.SelectedObject = firstButton
	end
end

--  MÉTODOS PÚBLICOS --

-- Abre uma tela principal (Fecha a anterior e limpa o estado)
function UIManager.Open(frame: GuiObject)
	assert(frame and frame:IsA("GuiObject"), "[UIManager] Open: Frame inválido")
	if CurrentFrame == frame then return end

	-- Fecha a tela anterior se existir
	if CurrentFrame then
		UIManager.CloseCurrent()
	end

	-- Prepara a nova tela
	local state = UIState.new()
	CurrentFrame = frame
	CurrentState = state
	
	-- Define a camada de tela principal
	local screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
	if screenGui then screenGui.DisplayOrder = LAYERS.SCREEN end

	-- Animação e Foco
	frame.Visible = true
	TweenUtil.FadeIn(frame, Config.UI.DefaultFadeTime)
	setFocusToFrame(frame)

	return state
end

-- Fecha a tela principal atual e faz a faxina de memória
function UIManager.CloseCurrent()
	if CurrentFrame and CurrentState then
		local frameToClose = CurrentFrame
		
		CurrentState:Cleanup() -- Limpa cliques e eventos
		
		TweenUtil.FadeOut(frameToClose, Config.UI.DefaultFadeTime, nil, function()
			frameToClose.Visible = false
		end)

		CurrentFrame = nil
		CurrentState = nil
		GuiService.SelectedObject = nil
	end
end

-- Abre um Overlay (não fecha a tela principal)
function UIManager.OpenOverlay(frame: GuiObject)
	assert(frame and frame:IsA("GuiObject"), "[UIManager] OpenOverlay: Frame inválido")
	
	if ActiveOverlays[frame] then return end

	local state = UIState.new()
	ActiveOverlays[frame] = state

	-- Garante que o overlay fique por cima de tudo
	local screenGui = frame:FindFirstAncestorOfClass("ScreenGui")
	if screenGui then screenGui.DisplayOrder = LAYERS.OVERLAY end

	frame.Visible = true
	TweenUtil.FadeIn(frame, Config.UI.OverlayFadeTime)
	setFocusToFrame(frame)

	return state
end

-- Fecha um overlay específico e limpa seus eventos
function UIManager.CloseOverlay(frame: GuiObject)
	local state = ActiveOverlays[frame]
	if state then
		state:Cleanup()
		TweenUtil.FadeOut(frame, Config.UI.OverlayFadeTime, nil, function()
			frame.Visible = false
		end)
		ActiveOverlays[frame] = nil
	end
end

-- Retorna a tela principal ativa
function UIManager.GetCurrent(): GuiObject?
	return CurrentFrame
end

return UIManager
