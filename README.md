# signals-like-roblox

Roblox-style Signal implementation for Lune.

> **Requires**: [Lune Custom Build](https://github.com/yanlvl99/lune-custom-build)
> 
> **Docs**: [https://yanlvl99.github.io/lune-custom-build-doc/](https://yanlvl99.github.io/lune-custom-build-doc/)

## Installation

```bash
lune --install signals-like-roblox
```

## Quick Start

```lua
local Signal = require("@signals-like-roblox")

local PlayerDied = Signal.new()

-- Connect listener
PlayerDied:Connect(function(playerName, cause)
    print(playerName, "died from", cause)
end)

-- Fire signal
PlayerDied:Fire("John", "explosion")
```

---

## API Reference

### `Signal.new(onFirstConnect?)`

Creates a new signal.

| Parameter | Type | Description |
|-----------|------|-------------|
| `onFirstConnect` | `function?` | Called once when first listener connects |

```lua
local MySignal = Signal.new()

-- With activation callback
local LazySignal = Signal.new(function()
    print("First connection! Starting monitoring...")
end)
```

---

### `Signal.newAction(actionFn, waitFn?, onFirstConnect?)`

Creates an Action - a hybrid signal/method. Callable as both property and method.

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionFn` | `function` | Called when action is invoked |
| `waitFn` | `function?` | Called by `:Wait()`, returns boolean |
| `onFirstConnect` | `function?` | Called on first connection |

```lua
local CloseAction = Signal.newAction(
    function() print("Closing...") end,
    function(timeout) 
        -- Wait logic, return true if success
        return true 
    end
)

-- Use as method
CloseAction()           -- prints "Closing..."

-- Use Wait
CloseAction:Wait(5)     -- Waits for completion
```

---

### Methods

#### `Signal:Connect(callback) -> Connection`

Connects a callback to the signal.

```lua
local connection = MySignal:Connect(function(a, b, c)
    print("Received:", a, b, c)
end)

-- Later...
connection:Disconnect()
```

#### `Signal:Once(callback) -> Connection`

Connects a callback that fires only once.

```lua
MySignal:Once(function(value)
    print("Only runs once:", value)
end)
```

#### `Signal:Fire(...)`

Fires the signal with arguments.

```lua
MySignal:Fire("hello", 123, true)
```

#### `Signal:Wait(timeout?) -> ...`

Yields until signal fires. Returns the fired arguments.

```lua
-- Wait indefinitely
local name, score = ScoreChanged:Wait()

-- With timeout (returns nil if timeout)
local result = MySignal:Wait(5)
```

---

### Connection Object

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `Connected` | `boolean` | Whether still connected |
| `Disconnect()` | `function` | Disconnects the listener |

```lua
local conn = Signal:Connect(callback)
print(conn.Connected)  -- true

conn:Disconnect()
print(conn.Connected)  -- false
```

---

## Types

```lua
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
```

---

## Examples

### Event System

```lua
local Signal = require("@signals-like-roblox")

local Events = {
    PlayerJoined = Signal.new(),
    PlayerLeft = Signal.new(),
    ChatMessage = Signal.new(),
}

Events.PlayerJoined:Connect(function(name)
    print(name, "joined the game")
end)

Events.ChatMessage:Connect(function(sender, message)
    print("[" .. sender .. "]:", message)
end)

-- Fire events
Events.PlayerJoined:Fire("Alice")
Events.ChatMessage:Fire("Alice", "Hello everyone!")
```

### Lazy Initialization

```lua
local ExpensiveSignal = Signal.new(function()
    print("Starting expensive operation...")
    -- Only runs when someone connects
end)

-- Nothing happens yet...
task.wait(5)

-- Now the initialization runs
ExpensiveSignal:Connect(function() end)
```

### Wait Pattern

```lua
-- Wait for user input
print("Press any key...")
local key = KeyPressed:Wait()
print("You pressed:", key)

-- With timeout
local result = DataLoaded:Wait(10)
if result then
    print("Data loaded:", result)
else
    print("Timeout!")
end
```
