if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1)

local BASE = "https://raw.githubusercontent.com/moshixzn/Lycoris-Rewrite-TypeSoul/refs/heads/main/"

local loaded = {}
getfenv().require = function(path)
    if loaded[path] then return loaded[path] end
    local url = BASE .. path:gsub("/", "/") .. ".lua"
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok then warn("[Lycoris] Failed to load: " .. path .. " | " .. tostring(result)) return nil end
    loaded[path] = result
    return result
end

shared = shared or {}
getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end
getfenv().PP_SCRAMBLE_NUM = function(...) return ... end
getfenv().PP_SCRAMBLE_STR = function(...) return ... end
getfenv().PP_SCRAMBLE_RE_NUM = function(...) return ... end

loadstring(game:HttpGet(BASE .. "Main.lua"))()
