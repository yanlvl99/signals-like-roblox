# ffi-like-roblox

Create Roblox-style classes from Windows DLLs using FFI.

> **Requires**: [Lune Custom Build](https://github.com/yanlvl99/lune-custom-build) with FFI support
> 
> **Docs**: [https://yanlvl99.github.io/lune-custom-build-doc/](https://yanlvl99.github.io/lune-custom-build-doc/)

## Installation

```bash
lune --install ffi-like-roblox
```

## Quick Start

```lua
local createClass = require("@ffi-like-roblox")

local Window = createClass({
    Dll = "user32.dll",
    
    Constructor = function(lib, className, title)
        return lib:call("FindWindowA", "u64", {"string", "string"}, className, title)
    end,
    
    Properties = {
        Title = {
            type = "string",
            get = function(lib, ptr)
                local buf = require("@lune/ffi").buffer(256)
                lib:call("GetWindowTextA", "i32", {"u64", "pointer", "i32"}, ptr, buf.ptr, 256)
                return buf:readString()
            end
        }
    }
})

local notepad = Window.new("Notepad", nil)
print(notepad.Title)
```

---

## API Reference

### `createClass(config) -> Class`

Creates a new class with the specified configuration.

```lua
local MyClass = createClass({
    Dll = "mydll.dll",
    Constructor = { ... },
    Properties = { ... },
    Methods = { ... },
    Static = { ... },
    Events = { ... },
})
```

---

## Configuration

### `Dll: string`

The DLL file to load.

```lua
Dll = "user32.dll"
Dll = "kernel32.dll"
Dll = "C:\\path\\to\\custom.dll"
```

---

### `Constructor`

How to create instances. Can be a function or definition table.

#### Function Constructor

```lua
Constructor = function(lib, arg1, arg2)
    -- lib is the opened DLL
    -- Return a pointer value
    return lib:call("CreateObject", "pointer", {"i32", "i32"}, arg1, arg2)
end
```

#### Definition Constructor

```lua
Constructor = {
    symbol = "FindWindowA",
    args = { "string", "string" },  -- Auto-converted
}
```

---

### `Properties`

Define readable/writable properties.

```lua
Properties = {
    -- Read-only with custom getter
    Title = {
        type = "string",
        get = function(lib, ptr)
            local buf = ffi.buffer(256)
            lib:call("GetWindowTextA", "i32", {"u64", "pointer", "i32"}, ptr, buf.ptr, 256)
            return buf:readString()
        end
    },
    
    -- Read-write with symbol names
    Visible = {
        type = "bool",
        get = "IsWindowVisible",   -- Automatic call
        set = function(lib, ptr, value)
            lib:call("ShowWindow", "bool", {"u64", "i32"}, ptr, value and 1 or 0)
        end
    },
    
    -- Write-only
    Style = {
        type = "i32",
        set = "SetWindowLongA"
    }
}
```

---

### `Methods`

Define instance methods.

```lua
Methods = {
    -- With wrapper function
    Close = {
        wrapper = function(lib, ptr)
            lib:call("PostMessageA", "bool", {"u64", "u32", "u64", "i64"}, ptr, 0x10, 0, 0)
        end
    },
    
    -- Auto-generated from symbol
    Flash = {
        symbol = "FlashWindow",
        ret = "bool",
        args = { "bool" }  -- Args after ptr
    },
    
    Move = {
        symbol = "MoveWindow",
        ret = "bool",
        args = { "i32", "i32", "i32", "i32", "bool" }
    }
}
```

---

### `Static`

Define static class methods.

```lua
Static = {
    GetDesktop = {
        symbol = "GetDesktopWindow",
        ret = "u64",
        args = {}
    },
    
    GetActive = {
        wrapper = function(lib)
            return lib:call("GetForegroundWindow", "u64", {})
        end
    }
}
```

Usage:
```lua
local desktop = Window.GetDesktop()
local active = Window.GetActive()
```

---

### `Events`

Define signals that can be connected to.

```lua
Events = {
    Closed = true,
    Moved = true,
    Resized = true,
},

MonitoringFunc = function(instance, rate)
    -- Start polling for changes
    task.spawn(function()
        while instance._monitoring do
            -- Check for changes and fire signals
            task.wait(rate)
        end
    end)
end,

MonitoringRate = 0.1  -- Optional, default 0.1
```

Events are created as Signals when the instance is created:
```lua
local win = Window.new(...)
win.Closed:Connect(function()
    print("Window closed!")
end)
```

---

## Instance Properties

All instances have these built-in properties:

| Property | Type | Description |
|----------|------|-------------|
| `_ptr` | `any` | The native pointer/handle |
| `_lib` | `Library` | The opened DLL |
| `_destroyed` | `boolean` | Whether Destroy() was called |
| `_monitoring` | `boolean` | Whether event monitoring is active |

---

## Class Methods

### `Class.new(...) -> Instance`

Creates a new instance.

```lua
local win = Window.new("Notepad", nil)
```

### `Class.fromPointer(ptr) -> Instance`

Wraps an existing pointer.

```lua
local hwnd = SomeApi.GetWindowHandle()
local win = Window.fromPointer(hwnd)
```

### `Instance:Destroy()`

Marks the instance as destroyed.

```lua
win:Destroy()
-- win:SomeMethod() will now error
```

---

## Type Conversion

The wrapper automatically handles type conversion:

| Lua Type | FFI Type | Notes |
|----------|----------|-------|
| `string` | Buffer → `pointer` | Auto-creates null-terminated buffer |
| `nil` | `0` | For u64/pointer types |
| `number` | As specified | Direct pass-through |
| `boolean` | As specified | Direct pass-through |

---

## Complete Example

```lua
local ffi = require("@lune/ffi")
local createClass = require("@ffi-like-roblox")
local Signal = require("@signals-like-roblox")

local Window = createClass({
    Dll = "user32.dll",
    
    Constructor = function(lib, className, title)
        local classPtr, titlePtr
        if className then
            local buf = ffi.buffer(#className + 1)
            buf:writeString(0, className)
            classPtr = buf.ptr
        end
        if title then
            local buf = ffi.buffer(#title + 1)
            buf:writeString(0, title)
            titlePtr = buf.ptr
        end
        return lib:call("FindWindowA", "u64", {"pointer", "pointer"}, 
            classPtr or ffi.null, titlePtr or ffi.null)
    end,
    
    Properties = {
        Title = {
            type = "string",
            get = function(lib, ptr)
                local buf = ffi.buffer(256)
                lib:call("GetWindowTextA", "i32", {"u64", "pointer", "i32"}, ptr, buf.ptr, 256)
                return buf:readString()
            end
        },
        IsVisible = {
            type = "bool",
            get = function(lib, ptr)
                return lib:call("IsWindowVisible", "bool", {"u64"}, ptr)
            end
        }
    },
    
    Methods = {
        Close = {
            wrapper = function(lib, ptr)
                lib:call("PostMessageA", "bool", {"u64", "u32", "u64", "i64"}, ptr, 0x10, 0, 0)
            end
        },
        Focus = {
            wrapper = function(lib, ptr)
                lib:call("SetForegroundWindow", "bool", {"u64"}, ptr)
            end
        }
    },
    
    Static = {
        GetFocused = {
            wrapper = function(lib)
                return lib:call("GetForegroundWindow", "u64", {})
            end
        }
    }
})

-- Usage
local notepad = Window.new("Notepad", nil)
if notepad then
    print("Found:", notepad.Title)
    notepad:Focus()
    notepad:Close()
end
```
