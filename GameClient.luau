--!strict
-- GameClient.lua


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

-- Importação dos Módulos Core
local Network = require(Modules.Client.Network)
local ClientCurrencies = require(Modules.Client.ClientCurrencies)
local Maid = require(Modules.Shared.Maid)

-- Tipagem para autocomplete
export type GameClientType = {
	Network: any,
	Store: any,
	Maid: any,
	Start: () -> GameClientType,
}

local GameClient = {}
GameClient.__index = GameClient

function GameClient.Start()
	local self = setmetatable({}, GameClient)
	
	self.Maid = Maid.new()
	
	-- 1. Inicializa o Network (Aponte para sua pasta de Remotes)
	local remoteFolder = ReplicatedStorage:WaitForChild("Remotes")
	self.Network = Network.new(nil, true) -- true para modo Debug
	
	-- 2. Inicializa o Banco de Dados Local
	self.Store = ClientCurrencies.new()
	self.Maid:Give(self.Store)
	
	-- 3. Configura Contratos de Segurança (Exemplos)
	-- Isso impede que o servidor mande dados lixo e quebre sua UI
	self.Network:SetContract("UpdateCurrency", {"string", "number"})
	self.Network:SetContract("BatchUpdate", {"table"}) -- Para atualizar tudo de uma vez
	
	-- 4. Cria a Ponte de Dados (Data Bridge)
	-- Sempre que o servidor disparar "UpdateCurrency", o Store atualiza automaticamente
	self.Network:Listen("UpdateCurrency", function(name: string, amount: number)
		self.Store:Set(name, amount)
	end)
	
	self.Network:Listen("BatchUpdate", function(data: {[string]: number})
		for name, amount in pairs(data) do
			self.Store:Set(name, amount)
		end
	end)

	print("[GameClient] Framework Inicializado!")
	return self
end

return GameClient
