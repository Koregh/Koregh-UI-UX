--!strict
-- Maid.lua

local Maid = {}
Maid.__index = Maid

-- [[ DEFINIÇÃO DE TIPOS ]] --

export type Maid = {
	Tasks: {[any]: any},
	Give: (self: Maid, task: any, key: any?) -> any,
	LinkToInstance: (self: Maid, instance: Instance) -> any,
	DoCleaning: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

-- [[ CONSTRUTOR ]] --

-- @desc Cria uma nova instância de Maid
function Maid.new(): Maid
	return setmetatable({ Tasks = {} }, Maid) :: any
end

-- [[ MÉTODOS PÚBLICOS ]] --

-- @desc Adiciona uma tarefa ao Maid. 
-- @param task: RBXScriptConnection, Instance, function, thread, ou objeto com Destroy/Disconnect.
-- @param key: (Opcional) Se fornecido, substitui a tarefa anterior com a mesma chave.
function Maid:Give(task: any, key: any?): any
	if task == nil then
		warn("[Maid] Tentativa de adicionar task inválida (nil)")
		return nil
	end

	-- Se houver uma chave, limpa o que existia nela antes
	if key then
		if self.Tasks[key] then
			self:CleanupTask(self.Tasks[key])
		end
		self.Tasks[key] = task
	else
		table.insert(self.Tasks, task)
	end

	return task
end

-- @desc Vincula o Maid a uma Instância do Roblox.
--       Quando a instância for destruída, o Maid limpa tudo automaticamente.
function Maid:LinkToInstance(instance: Instance): any
	local connection = instance.Destroying:Connect(function()
		self:DoCleaning()
	end)
	return self:Give(connection)
end

-- @desc Limpa uma tarefa específica baseado no seu tipo (Interno)
local function cleanupTask(task: any)
	local taskType = typeof(task)

	if taskType == "RBXScriptConnection" then
		task:Disconnect()
	elseif taskType == "Instance" then
		task:Destroy()
	elseif taskType == "function" then
		task()
	elseif taskType == "thread" then
		-- Cancela a thread (task.delay/spawn) se ainda estiver ativa
		local success, _ = pcall(task.cancel, task)
	elseif taskType == "table" or taskType == "userdata" then
		-- Suporte a objetos customizados ou Maids aninhados
		if task.Destroy then
			task:Destroy()
		elseif task.DoCleaning then
			task:DoCleaning()
		elseif task.Disconnect then
			task:Disconnect()
		elseif task.Cancel then
			task:Cancel()
		end
	end
end

-- @private
Maid.CleanupTask = cleanupTask

-- @desc Executa a limpeza de todas as tarefas gerenciadas
function Maid:DoCleaning()
	for key, task in pairs(self.Tasks) do
		cleanupTask(task)
		self.Tasks[key] = nil
	end
end

-- @desc Alias para DoCleaning, permitindo que o Maid seja limpo por outro Maid
function Maid:Destroy()
	self:DoCleaning()
end

return Maid
