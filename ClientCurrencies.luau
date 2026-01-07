--!strict
-- ClientCurrencies.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maid = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Maid"))

local ClientCurrencies = {}
ClientCurrencies.__index = ClientCurrencies

-- [Regras de Negócio] Exemplo de limites para moedas específicas
local CONSTRAINTS: {[string]: {min: number, max: number}} = {
	["Level"] = {min = 1, max = 100},
	["Stamina"] = {min = 0, max = 100},
}

export type ClientCurrenciesType = {
	currencies: {[string]: number},
	maid: Maid,
	OnChange: BindableEvent,
	Set: (self: ClientCurrenciesType, name: string, amount: number) -> (),
	Get: (self: ClientCurrenciesType, name: string) -> number,
	Observe: (self: ClientCurrenciesType, name: string, callback: (new: number, old: number) -> ()) -> RBXScriptConnection,
	CanAfford: (self: ClientCurrenciesType, name: string, price: number) -> boolean,
	Destroy: (self: ClientCurrenciesType) -> (),
}

function ClientCurrencies.new(): ClientCurrenciesType
	local self = setmetatable({}, ClientCurrencies)
	self.currencies = {}
	self.maid = Maid.new()
	self.OnChange = Instance.new("BindableEvent")
	self.maid:Give(self.OnChange)
	return self :: any
end

function ClientCurrencies:Set(name: string, amount: number)
	local prev = self.currencies[name] or 0
	local current = amount

	-- Aplica limites se existirem, caso contrário apenas garante que não é negativo
	local limit = CONSTRAINTS[name]
	if limit then
		current = math.clamp(amount, limit.min, limit.max)
	else
		current = math.max(amount, 0)
	end

	if prev ~= current then
		self.currencies[name] = current
		self.OnChange:Fire(name, current, prev)
	end
end

function ClientCurrencies:Get(name: string): number
	return self.currencies[name] or 0
end

function ClientCurrencies:CanAfford(name: string, price: number): boolean
	return self:Get(name) >= price
end

-- Reatividade para a UI (Dispara o valor atual imediatamente + conexões futuras)
function ClientCurrencies:Observe(name: string, callback: (new: number, old: number) -> ()): RBXScriptConnection
	task.spawn(callback, self:Get(name), self:Get(name))
	return self.OnChange.Event:Connect(function(target, new, old)
		if target == name then callback(new, old) end
	end)
end

function ClientCurrencies:Destroy()
	self.maid:DoCleaning()
end

return ClientCurrencies
