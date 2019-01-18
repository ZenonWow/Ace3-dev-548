local AddonEnv = LibStub:NewLibrary("AddonEnv", 1)
if  AddonEnv  then

	local AddonEnvMeta = {
		SetNoGlobals = false,
		SetGlobalProxy = { __index = _G },
	}

	-- local _ADDON = AddonEnv.SetGlobalProxy(...)
	-- local _ENV = AddonEnv.SetNoGlobals(...)
	for  kind  in next, AddonEnvMeta do
		AddonEnv[kind] = function (ADDON_NAME, _ADDON)
			setfenv(2, setmetatable(_ADDON, AddonEnvMeta[kind] or nil))
			_ADDON.ADDON_NAME = ADDON_NAME
			_ADDON._ADDON = _ADDON
			_ADDON._G = _G
			return _ADDON
		end
	end
	
	_G.AddonEnv = AddonEnv

end


