--!strict
-- Network.lua


local Network = {}
Network.__index = Network

-- Configurações de Segurança
local MAX_CALLS_PER_SECOND = 20
local DEFAULT_TIMEOUT = 10 -- Segundos para desistir de um Invoke

-- Tipos
export type RemoteMap = { [string]: RemoteEvent | RemoteFunction | BindableEvent | BindableFunction }
export type Callback = (...any) -> any
export type ListenerMap = { [string]: { RBXScriptConnection } }
export type Contract = { args: {string}, returns: {string}?, version: number? }

export type NetworkType = typeof(setmetatable({} :: {
	Remotes: RemoteMap,
	Listeners: ListenerMap,
	Contracts: { [string]: Contract },
	Debug: boolean,
	OnError: ((string, string) -> ())?,
	_lastCalls: { [string]: number }
}, Network))

-- Helper: Cópia profunda para evitar mutação de dados
local function deepCopy(t: any)
	if type(t) ~= "table" then return t end
	local res = {}
	for k, v in pairs(t) do res[k] = deepCopy(v) end
	return res
end

-- Helper: Validação
local function validateArgs(expected: {string}, actual: {any})
	for i, t in expected do
		if typeof(actual[i]) ~= t then
			return false, ("[Network] Erro de Contrato: Pos %d esperado %s, recebeu %s"):format(i, t, typeof(actual[i]))
		end
	end
	return true
end

function Network.new(remotes: RemoteMap?, debugMode: boolean?): NetworkType
	local self = setmetatable({
		Remotes = remotes or {},
		Listeners = {},
		Contracts = {},
		Debug = debugMode or false,
		OnError = nil,
		_lastCalls = {}
	}, Network)
	return self :: any
end

function Network:Fire(name: string, ...: any): any
	local remote = self.Remotes[name]
	if not remote then warn("[Network] '" .. name .. "' inexistente") return end

	-- 1. Anti-Spam Check
	local now = os.clock()
	if self._lastCalls[name] and (now - self._lastCalls[name]) < (1/MAX_CALLS_PER_SECOND) then
		if self.Debug then warn("[Network] Throttling ativo para: " .. name) end
		return
	end
	self._lastCalls[name] = now

	-- 2. Segurança de Dados
	local args = deepCopy({...})

	-- 3. Validação de Contrato
	local contract = self.Contracts[name]
	if contract and contract.args then
		local valid, err = validateArgs(contract.args, args)
		if not valid then if self.Debug then warn(err) end return end
	end

	-- 4. Execução Protegida
	if remote:IsA("RemoteEvent") or remote:IsA("BindableEvent") then
		local success, err = pcall(function()
			if (remote :: any).FireServer then (remote :: any):FireServer(unpack(args))
			else (remote :: any):Fire(unpack(args)) end
		end)
		if not success and self.OnError then self.OnError(name, err) end
		
	elseif remote:IsA("RemoteFunction") or remote:IsA("BindableFunction") then
		-- Proteção de Timeout para RemoteFunctions
		local result
		local success, err = pcall(function()
			if (remote :: any).InvokeServer then
				-- Simulando timeout para Invoke
				local thread = coroutine.running()
				task.delay(DEFAULT_TIMEOUT, function()
					if coroutine.status(thread) == "suspended" then
						coroutine.resume(thread, nil, "Timeout")
					end
				end)
				result = (remote :: any):InvokeServer(unpack(args))
			else
				result = (remote :: any):Invoke(unpack(args))
			end
		end)
		
		if not success or result == "Timeout" then
			warn("[Network] Falha no Invoke '" .. name .. "': " .. tostring(err or "Timeout"))
			return nil
		end
		return result
	end
end

-- O Listen permanece focado em segurança de entrada
function Network:Listen(name: string, callback: Callback)
	local remote = self.Remotes[name]
	if not remote then return end

	local wrapper = function(...)
		local args = deepCopy({...})
		local contract = self.Contracts[name]
		if contract and contract.args then
			local valid = validateArgs(contract.args, args)
			if not valid then return end
		end
		
		local success, err = pcall(callback, unpack(args))
		if not success and self.OnError then self.OnError(name, err) end
	end

	if remote:IsA("RemoteEvent") then
		local conn = remote.OnClientEvent:Connect(wrapper)
		self.Listeners[name] = self.Listeners[name] or {}
		table.insert(self.Listeners[name], conn)
		return conn
	elseif remote:IsA("BindableEvent") then
		local conn = remote.Event:Connect(wrapper)
		self.Listeners[name] = self.Listeners[name] or {}
		table.insert(self.Listeners[name], conn)
		return conn
	elseif remote:IsA("RemoteFunction") or remote:IsA("BindableFunction") then
		(remote :: any).OnClientInvoke = callback
	end
end

-- [Demais métodos como Disconnect e Register permanecem iguais]
function Network:SetContract(name: string, args: {string}, returns: {string}?, version: number?)
	self.Contracts[name] = {args=args, returns=returns, version=version}
end

function Network:Disconnect(name: string)
	if self.Listeners[name] then
		for _, conn in self.Listeners[name] do conn:Disconnect() end
		self.Listeners[name] = nil
	end
end

function Network:Register(name: string, remote: any) self.Remotes[name] = remote end
function Network:SetErrorCallback(func: (string, string) -> ()) self.OnError = func end

return Network
