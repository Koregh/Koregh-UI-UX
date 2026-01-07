-- Bootclient.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameClient = require(ReplicatedStorage.Modules.Client.GameClient)

-- Inicia o framework e guarda a referência global se necessário
_G.Engine = GameClient.Start()
