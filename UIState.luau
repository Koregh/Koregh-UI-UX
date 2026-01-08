--!strict
-- UIState.lua

local Maid = require(script.Parent:WaitForChild("Maid"))

local UIState = {}
UIState.__index = UIState

export type UIStateType = {
	maid: Maid,

	-- Métodos Base
	SetProperty: (self: UIStateType, element: GuiObject, property: string, value: any) -> (),
	SetText: (self: UIStateType, element: TextLabel | TextBox, text: string) -> (),
	SetColor: (self: UIStateType, element: GuiObject, color: Color3) -> (),
	SetSize: (self: UIStateType, element: GuiObject, size: UDim2) -> (),
	SetPosition: (self: UIStateType, element: GuiObject, position: UDim2) -> (),
	SetVisible: (self: UIStateType, element: GuiObject, visible: boolean) -> (),
	SetTransparency: (self: UIStateType, element: GuiObject, transparency: number) -> (),
	
	-- Métodos de Produtividade e Reatividade
	Apply: (self: UIStateType, element: GuiObject, props: {[string]: any}) -> (),
	BindToSignal: (self: UIStateType, signal: any, callback: (...any) -> ()) -> (),
	
	-- Eventos e Limpeza
	ConnectEvent: (self: UIStateType, element: GuiObject, eventName: string, callback: (...any) -> ()) -> (),
	Cleanup: (self: UIStateType) -> (),
}

-- Cria uma nova sessão de estado. Útil para cada janela aberta no jogo.
local function new(): UIStateType
	local self: UIStateType = setmetatable({}, UIState)
	self.maid = Maid.new()
	return self
end

-- Aplica várias configurações de uma vez só usando uma tabela.
function UIState:Apply(element: GuiObject, props: {[string]: any})
	for prop, value in pairs(props) do
		self:SetProperty(element, prop, value)
	end
end

-- Define propriedades de forma segura. Se a propriedade não existir, ele avisa.
function UIState:SetProperty(element: GuiObject, property: string, value: any)
	assert(element and element:IsA("GuiObject"), "[UIState] O elemento fornecido é inválido.")
	
	local success = pcall(function()
		(element :: any)[property] = value
	end)
	
	if not success then
		error(("[UIState] A propriedade '%s' não existe em %s"):format(property, element:GetFullName()))
	end
end

-- Atalhos rápidos para o dia a dia
function UIState:SetText(element: TextLabel | TextBox, text: string) self:SetProperty(element, "Text", text) end
function UIState:SetColor(element: GuiObject, color: Color3) self:SetProperty(element, "BackgroundColor3", color) end
function UIState:SetSize(element: GuiObject, size: UDim2) self:SetProperty(element, "Size", size) end
function UIState:SetPosition(element: GuiObject, position: UDim2) self:SetProperty(element, "Position", position) end
function UIState:SetVisible(element: GuiObject, visible: boolean) self:SetProperty(element, "Visible", visible) end
function UIState:SetTransparency(element: GuiObject, transparency: number) self:SetProperty(element, "BackgroundTransparency", transparency) end

-- Conecta a UI a um evento externo (ex: o dinheiro do player mudou).
-- O Maid garante que essa conexão seja cortada quando a UI fechar.
function UIState:BindToSignal(signal: any, callback: (...any) -> ())
	assert(signal and signal.Connect, "[UIState] O sinal fornecido para BindToSignal é inválido.")
	local conn = signal:Connect(callback)
	self.maid:Give(conn)
end

-- Conecta cliques e interações e guarda a conexão no Maid.
function UIState:ConnectEvent(element: GuiObject, eventName: string, callback: (...any) -> ())
	assert(element and element:IsA("GuiObject"), "[UIState] Elemento inválido no ConnectEvent.")
	
	local event = (element :: any)[eventName]
	if not event or typeof(event) ~= "RBXScriptSignal" then
		error(("[UIState] O evento '%s' é inválido para %s"):format(eventName, element:GetFullName()))
	end
	
	local conn = event:Connect(callback)
	self.maid:Give(conn)
end

-- Desconecta TUDO o que foi registrado nessa sessão de UI. Adeus memory leaks!
function UIState:Cleanup()
	self.maid:DoCleaning()
end

UIState.new = new

return UIState
