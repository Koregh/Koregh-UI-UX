--!strict
-- Network.lua

local Network = {}
Network.__index = Network

-- IDs de Protocolo Binário (Sincronizado com o Servidor)
local PacketType = {
	CFRAME     = 1, VECTOR3    = 2, VECTOR2    = 3,
	COLOR3     = 4, NUMBER     = 5, INT32      = 6,
	BOOLEAN    = 7, STRING     = 8, BRICKCOLOR = 9,
	ENUM       = 10, UDIM2     = 11, INT8      = 12
}

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

-- MÉTODOS PRIVADOS DE AUXÍLIO --

-- Serialização: Transforma tipos pesados em buffers antes de enviar ao servidor
local function _serialize(data: any): any
	local t = typeof(data)
	
	if t == "CFrame" then
		local b = buffer.create(25)
		buffer.writeu8(b, 0, PacketType.CFRAME)
		buffer.writef32(b, 1, data.X); buffer.writef32(b, 5, data.Y); buffer.writef32(b, 9, data.Z)
		local rx, ry, rz = data:ToEulerAnglesXYZ()
		buffer.writef32(b, 13, rx); buffer.writef32(b, 17, ry); buffer.writef32(b, 21, rz)
		return b
	elseif t == "Vector3" then
		local b = buffer.create(13)
		buffer.writeu8(b, 0, PacketType.VECTOR3)
		buffer.writef32(b, 1, data.X); buffer.writef32(b, 5, data.Y); buffer.writef32(b, 9, data.Z)
		return b
	elseif t == "Color3" then
		local b = buffer.create(4)
		buffer.writeu8(b, 0, PacketType.COLOR3)
		buffer.writeu8(b, 1, data.R * 255); buffer.writeu8(b, 2, data.G * 255); buffer.writeu8(b, 3, data.B * 255)
		return b
	elseif t == "number" then
		if data % 1 == 0 and data >= -128 and data <= 127 then
			local b = buffer.create(2); buffer.writeu8(b, 0, PacketType.INT8); buffer.writei8(b, 1, data); return b
		end
		local b = buffer.create(9); buffer.writeu8(b, 0, PacketType.NUMBER); buffer.writef64(b, 1, data); return b
	elseif t == "boolean" then
		local b = buffer.create(2); buffer.writeu8(b, 0, PacketType.BOOLEAN); buffer.writeu8(b, 1, data and 1 or 0); return b
	elseif t == "UDim2" then
		local b = buffer.create(17); buffer.writeu8(b, 0, PacketType.UDIM2)
		buffer.writef32(b, 1, data.X.Scale); buffer.writei32(b, 5, data.X.Offset)
		buffer.writef32(b, 9, data.Y.Scale); buffer.writei32(b, 13, data.Y.Offset); return b
	elseif t == "BrickColor" then
		local b = buffer.create(3); buffer.writeu8(b, 0, PacketType.BRICKCOLOR); buffer.writei16(b, 1, data.Number); return b
	end
	return data
end

-- Deserialização: Transforma buffers recebidos do servidor em tipos Roblox
local function _deserialize(b: any): any
	if typeof(b) ~= "buffer" then return b end
	local header = buffer.readu8(b, 0)
	
	if header == PacketType.CFRAME then
		return CFrame.new(buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9)) * CFrame.Angles(buffer.readf32(b, 13), buffer.readf32(b, 17), buffer.readf32(b, 21))
	elseif header == PacketType.VECTOR3 then
		return Vector3.new(buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9))
	elseif header == PacketType.COLOR3 then
		return Color3.fromRGB(buffer.readu8(b, 1), buffer.readu8(b, 2), buffer.readu8(b, 3))
	elseif header == PacketType.NUMBER then
		return buffer.readf64(b, 1)
	elseif header == PacketType.INT8 then
		return buffer.readi8(b, 1)
	elseif header == PacketType.BOOLEAN then
		return buffer.readu8(b, 1) == 1
	elseif header == PacketType.UDIM2 then
		return UDim2.new(buffer.readf32(b, 1), buffer.readi32(b, 5), buffer.readf32(b, 9), buffer.readi32(b, 13))
	elseif header == PacketType.BRICKCOLOR then
		return BrickColor.new(buffer.readi16(b, 1))
	end
	return b
end

-- Helper: Cópia profunda para evitar mutação de dados
local function deepCopy(t: any)
	if type(t) ~= "table" then return t end
	local res = {}
	for k, v in pairs(t) do res[k] = deepCopy(v) end
	return res
end

-- Helper: Validação de Contrato
local function validateArgs(expected: {string}, actual: {any})
	for i, t in expected do
		if typeof(actual[i]) ~= t then
			return false, ("[Network] Erro de Contrato: Pos %d esperado %s, recebeu %s"):format(i, t, typeof(actual[i]))
		end
	end
	return true
end

-- MÉTODOS DE INSTÂNCIA --

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

	-- Anti-Spam Check
	local now = os.clock()
	if self._lastCalls[name] and (now - self._lastCalls[name]) < (1/MAX_CALLS_PER_SECOND) then
		if self.Debug then warn("[Network] Throttling ativo para: " .. name) end
		return
	end
	self._lastCalls[name] = now

	-- Segurança e Conversão Binária
	local rawArgs = {...}
	local args = {}
	for i, v in ipairs(rawArgs) do
		args[i] = _serialize(v) -- Converte para buffer se possível
	end

	-- Validação de Contrato
	local contract = self.Contracts[name]
	if contract and contract.args then
		-- Validamos contra os dados originais (antes de virar buffer) para bater com os nomes do typeof
		local valid, err = validateArgs(contract.args, rawArgs)
		if not valid then if self.Debug then warn(err) end return end
	end

	-- Execução Protegida
	if remote:IsA("RemoteEvent") or remote:IsA("BindableEvent") then
		local success, err = pcall(function()
			if (remote :: any).FireServer then 
				(remote :: any):FireServer(unpack(args))
			else 
				(remote :: any):Fire(unpack(args)) 
			end
		end)
		if not success and self.OnError then self.OnError(name, err) end
		
	elseif remote:IsA("RemoteFunction") or remote:IsA("BindableFunction") then
		local result
		local success, err = pcall(function()
			if (remote :: any).InvokeServer then
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

		-- Deserializa o retorno do servidor caso ele também use compressão
		return _deserialize(result)
	end
end

function Network:Listen(name: string, callback: Callback)
	local remote = self.Remotes[name]
	if not remote then return end

	local wrapper = function(...)
		-- CAMADA DE TRADUÇÃO
		local rawArgs = {...}
		local args = {}
		for i, v in ipairs(rawArgs) do
			args[i] = _deserialize(v) -- Traduz buffers recebidos do servidor
		end

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
