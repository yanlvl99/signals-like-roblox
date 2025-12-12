-- lune_packages/signals-like-roblox/init.luau
local task = require("@lune/task")

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> ()
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _connections = {} }, Signal)
end

function Signal:Connect(callback)
	local connection = {
		Connected = true,
		_signal = self,
		_fn = callback
	}
	function connection:Disconnect()
		self.Connected = false
		local conns = self._signal._connections
		for i, conn in ipairs(conns) do
			if conn == self then
				table.remove(conns, i)
				break
			end
		end
	end
	table.insert(self._connections, connection)
	return connection
end

function Signal:Fire(...)
	for _, conn in ipairs(self._connections) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
