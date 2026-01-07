--!strict
-- GameClient.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Network = require(Modules.Client.Network)
local ClientCurrencies = require(Modules.Client.ClientCurrencies)
local Maid = require(Modules.Shared.Maid)

-- Tipos
export type GameClientType = {
	Network: any,
	Store: any,
	Maid: Maid.Maid,
}

local GameClient = {}
local instance: GameClientType? = nil -- Cache da instância única

function GameClient.Start(): GameClientType
	-- Se já foi iniciado, apenas retorna a instância existente
	if instance then return instance end
	
	local self = {}
	self.Maid = Maid.new()
	
	-- 1. Inicializa o Network
	self.Network = Network.new(nil, true)
	
	-- 2. Inicializa o Banco de Dados
	self.Store = ClientCurrencies.new()
	self.Maid:Give(self.Store)
	
	-- 3. Contratos
	self.Network:SetContract("UpdateCurrency", {"string", "number"})
	self.Network:SetContract("BatchUpdate", {"table"})
	
	-- 4. Ponte de Dados (Data Bridge)
	self.Network:Listen("UpdateCurrency", function(name: string, amount: number)
		self.Store:Set(name, amount)
	end)
	
	self.Network:Listen("BatchUpdate", function(data: {[string]: number})
		for name, amount in pairs(data) do
			self.Store:Set(name, amount)
		end
	end)

	instance = self :: any
	print("[GameClient] Framework de Elite Inicializado!")
	return instance :: GameClientType
end

-- Função para pegar a instância em outros scripts sem precisar iniciar de novo
function GameClient.GetInstance(): GameClientType
	if not instance then
		return GameClient.Start()
	end
	return instance :: GameClientType
end

return GameClient

