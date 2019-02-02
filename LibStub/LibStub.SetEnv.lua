--[[ Usage at the beginning of a file:
-- UseNoGlobals:  report error when using globals but continue without halting
local _G, _ADDON = LibEnv.UseNoGlobals(...)
local _G, _ADDON = LibEnv.UseAddonEnv(...)
local _G, _ADDON = LibEnv.UseGlobalEnv(...)
local ADDON_NAME = ...    -- if necessary
-- UseAddonAndGlobalEnv:  use variable in _ADDON environment; if does not exist there (== nil) then in _G
local _G, _ADDON = LibEnv.UseAddonAndGlobalEnv(...)
--]]

local LibEnv = LibStub:NewLibrary("LibStub.SetEnv", 1)
if not LibEnv then  return  end


-- Import
local _G, LibCommon = getfenv(1), LibCommon

-- Upvalued Lua globals
local assert,setfenv,rawget = assert,setfenv,rawget

-- Export
_G.LibEnv = LibEnv
LibEnv._G = _G



-- Forward declaration
local SetupEnv, CheckVar, NoGlobalsMeta, AddonAndGlobalEnvMeta

-- API
function LibEnv.UseNoGlobals(ADDON_NAME, _ADDON)  return SetupEnv( NoGlobalsMeta:NewEnv({}) , ADDON_NAME, _ADDON )  end
function LibEnv.UseAddonEnv (ADDON_NAME, _ADDON)  return SetupEnv(_ADDON or ADDON_NAME, ADDON_NAME, _ADDON)  end
function LibEnv.UseGlobalEnv(ADDON_NAME, _ADDON)  return SetupEnv(_G, ADDON_NAME, _ADDON)  end
function LibEnv.UseAddonAndGlobalEnv(ADDON_NAME, _ADDON)  return SetupEnv( AddonAndGlobalEnvMeta:NewEnv({_ADDON = _ADDON}) , ADDON_NAME, _ADDON )  end

-- local
function SetupEnv(ENV, ADDON_NAME, _ADDON)
	assert(type(ENV) == 'table', "_ADDON parameter type '"..type(ENV).."' should be table. Usage: LibEnv.Use*(...) at the beginning of a file  or  LibEnv.Use*(ADDON_NAME, _ADDON)  or  LibEnv.Use*(_ADDON)")
	setfenv(3, ENV)    -- 0:setfenv, 1:SetupEnv, 2:LibEnv.UseNoGlobals()/LibEnv.UseAddonEnv()/LibEnv.UseGlobalEnv(), 3:caller
	if  type(ADDON_NAME) == 'string'  then  CheckVar(_ADDON, 'ADDON_NAME', ADDON_NAME)
	elseif  not _ADDON  and  type(ADDON_NAME) == 'table'  then  _ADDON = ADDON_NAME
	end
	return _G, _ADDON
end

-- local
function CheckVar(_ADDON, var, value)
	local was = rawget(_ADDON, var)
	-- Not using rawset. Metatable's __newindex is triggered, if set.
	if was == nil then  _ADDON[var] = value
	elseif was ~= value then  _G.geterrorhandler()( _G.string.format('_ADDON.%s = "%s" must be the same as currently provided %s = "%s".', var, was, var, value) )
	end
end


--------------------------------------------------------------------------
-- UseNoGlobals:  report error when using globals but continue without halting

-- Map of reported global uses
LibEnv.envData = LibEnv.envData or {}

local function report(envData, var, action)
	-- if  envData.allowed[var]  then  return  end
	
	local varData = envData[var]
	local filePath = _G.debugstack(3, 1, 0):match([[\AddOns\(.-):]])
	if  not varData  then  _G.geterrorhandler()(FUNCTION_COLOR.."LibEnv.UseNoGlobals:|r  "..filePath.."  "..action.." global  "..MESSAGE_COLOR..var)  end
	if  not varData  then  varData = {}  envData[var] = varData  end
	
	-- 0:debugstack, 1:report, 2:__index, 3:caller
	local fileLine = _G.debugstack(3, 1, 0):match([[\AddOns\(.-:.-:)]])
	local prev = varData[fileLine]
	if  not prev  then  _G.print()(FUNCTION_COLOR.."LibEnv.UseNoGlobals:|r  "..fileLine.."  "..action.." global  "..MESSAGE_COLOR..var)  end
	varData[fileLine] = (prev or 0) + 1
end

-- local
NoGlobalsMeta = {
	NewEnv = function(self, env)
		LibEnv.envData[env] = LibEnv.envData[env] or {}
		return setmetatable(env, self)
	end,
	__index = function(env, var)
		local envData = LibEnv.envData[env]
		report(envData, var, 'read')
		return _G[var]
	end,
	__newindex = function(env, var, value)
		local envData = LibEnv.envData[env]
		report(envData, var, 'set')
		_G[var] = value
	end,
}


--------------------------------------------------------------------------
-- UseAddonAndGlobalEnv:  use variable in _ADDON environment; if does not exist there (== nil) then in _G

-- local
UseAddonAndGlobalEnv = {
	NewEnv = function(self, env)
		return setmetatable(env, self)
	end,
	__index = function(env, var)
		local value = env._ADDON[var]
		-- If [var] exists in _ADDON then return it.
		if  value ~= nil  then  return value
		-- Return [var] from _G.
		else  return _G[var]
		end
	end,
	__newindex = function(env, var, value)
		local _ADDON = env._ADDON
		-- If [var] exists in _ADDON then overwrite there.
		if  nil ~= rawget(_ADDON, var)  then  _ADDON[var] = value
		-- If [var] exists in _G then overwrite there.
		elseif  nil ~= rawget(_G, var)  then  _G[var] = value
		-- If [var] does not exist then create in _ADDON.
		else _ADDON[var] = value
		end
	end,
}



