-- signals-like-roblox: Roblox-style signals for Lune
local task = require("@lune/task")

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>, timeout: number?) -> T...,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
}

export type Action = Signal<> & ((any) -> ())

local Signal = {}
Signal.__index = Signal

function Signal.new(onFirstConnect)
	return setmetatable({
		_connections = {},
		_onFirstConnect = onFirstConnect,
		_activated = false,
	}, Signal)
end

function Signal.newAction(actionFn, waitFn, onFirstConnect)
	return setmetatable({
		_connections = {},
		_onFirstConnect = onFirstConnect,
		_activated = false,
		_action = actionFn,
		_wait = waitFn,
	}, Signal)
end

function Signal:Connect(callback)
	local conns = self._connections

	if not self._activated and self._onFirstConnect then
		self._activated = true
		task.spawn(self._onFirstConnect)
	end

	local connection = {
		Connected = true,
		_signal = self,
		_fn = callback,
	}

	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local c = self._signal._connections
		local n = #c
		for i = 1, n do
			if c[i] == self then
				c[i] = c[n]
				c[n] = nil
				break
			end
		end
	end

	conns[#conns + 1] = connection
	return connection
end

function Signal:Once(callback)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		callback(...)
	end)
	return conn
end

function Signal:Fire(...)
	local conns = self._connections
	local n = #conns
	for i = 1, n do
		local conn = conns[i]
		if conn and conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

function Signal:Wait(timeout)
	if self._wait then
		return self._wait(timeout)
	end

	if not self._activated and self._onFirstConnect then
		self._activated = true
		task.spawn(self._onFirstConnect)
	end

	local thread = coroutine.running()
	local timedOut = false
	local conn

	if timeout then
		task.delay(timeout, function()
			if conn and conn.Connected then
				timedOut = true
				conn:Disconnect()
				task.spawn(thread)
			end
		end)
	end

	conn = self:Connect(function(...)
		conn:Disconnect()
		if not timedOut then
			task.spawn(thread, ...)
		end
	end)

	return coroutine.yield()
end

function Signal:__call(...)
	if self._action then
		return self._action(...)
	end
	return nil
end

return Signal
