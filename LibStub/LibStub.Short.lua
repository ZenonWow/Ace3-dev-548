-- LibStubs.<shortname>  enables the use of short library references in the form:
-- LibStubs.LibDataBroker, LibStubs.LibSharedMedia, LibStubs.AceAddon
-- LibStubs.LibDataBroker11, LibStubs.LibSharedMedia30, LibStubs.AceAddon30, etc.
-- The short reference without version number refers to the highest major version loaded.
-- eg.  LibStubs.AceAddon  is  LibStubs.AceAddon30, not LibStubs.AceAddon20.
-- Different major versions are generally not around. If in doubt, use the reference with version number.
-- Does _not_ raise an error if the library is not found.

-- GLOBALS:
-- Used from _G:  pairs, next, getmetatable, setmetatable, geterrorhandler
-- Used from LibCommon:
-- Upvalued Lua globals:  type,getmetatable,setmetatable,rawset
-- Exported to _G:  LibStubs
-- Exported to LibCommon:  initmetatable


local _G, LIBSTUBS_NAME = _G, LIBSTUBS_NAME or 'LibStubs'
local Shorty = LibStub:NewLibrary("LibStub.Short", 1)

if Shorty then

	-- Short name -> library index
	Shorty.shortNames = Shorty.shortNames or {}

	-- Exported to  LibStub.Short:
	LibStub.Short = LibStub.Short or Shorty.shortNames
	if LibStub.Short ~= Shorty.shortNames then  _G.geterrorhandler()("_G.LibStub.Short is already in use.")

	-- Exported to _G:  LibStubs == LibStub.Short
	_G[LIBSTUBS_NAME] = _G[LIBSTUBS_NAME] or Shorty.shortNames
	if _G[LIBSTUBS_NAME] ~= Shorty.shortNames then  _G.geterrorhandler()("LibStub.Short:  _G."..LIBSTUBS_NAME.." is already in use.")


	local function InsertCheckConflict(shortNames, libname, lib, short)
		local conflict = shortNames[short]
		if  conflict == lib  then  return  end
		if  conflict  and  libname <= (conflict.libname or "")  then  return  end
		shortNames[short] = lib
	end

	function Shorty.InsertLib(shortNames, libname, lib)
		-- Remove '-','.'
		InsertCheckConflict(shortNames, libname, lib, libname:gsub("[%-%.]", "") )
		-- Remove version: "-n.n" and remove '-','.'
		InsertCheckConflict(shortNames, libname, lib, libname:gsub("%-[%.%d]+$", ""):gsub("[%-%.]", "") )
	end

	if LibStub.RegisterCallback then
		LibStub:RegisterCallback(Shorty.shortNames, Shorty.InsertLib)
	end
end



-- _OnCreateLibrary() callback without LibStub:RegisterCallback() (<- one line)
if  Shorty  and  not LibStub.RegisterCallback  then

	-- Upvalued globals:
	local LibStub,rawset = LibStub,rawset
	local type,getmetatable,setmetatable = type,getmetatable,setmetatable
	local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon

	-- Exported to LibCommon:  initmetatable
	LibCommon.initmetatable = LibCommon.initmetatable  or function(obj)
		local meta = getmetatable(obj) ; if not meta then  meta = {} ; setmetatable(obj, meta)  end ; return type(meta)=='table' and meta  end
	end

	-- Hook the original LibStub.libs map.
	function Shorty:HookLibs(libs)
		self.libs = libs

		-- This hook is specifically tailored for this `shortNames` index:
		local InsertLib,shortNames = self.InsertLib, self.shortNames

		-- Import the loaded libraries from LibStub.
		for libname,lib in _G.pairs(libs) do
			lib.libname = libname
			InsertLib(shortNames, libname, lib)
		end

		local meta = LibCommon.initmetatable(libs)
		assert(type(meta)=='table', "LibStub.Short is incompatible with a custom protected metatable on LibStub.libs. Libraries loaded after this will not be indexed.")

		-- Unhook old hook before upgrading.
		if meta and meta.__newindex == meta.ShortStubsHook then  meta.__newindex = nil  end
		assert(not meta.__newindex), "LibStub.Short is incompatible with a custom metatable on LibStub.libs. Libraries loaded after this will not be indexed.")

	-- The metatable hook to capture new libraries.
		meta.ShortStubsHook = function(libs, libname, lib)
			-- Only self (self) is upvalued.
			rawset(libs, libname, lib)
			InsertLib(shortNames, libname, lib)
		end

		-- Hook inserting new libraries into LibStub.libs.
		meta.__newindex = meta.ShortStubsHook
	end

	-- For completeness:
	function Shorty:UnhookLibs()
		local meta = _G.getmetatable(self.libs)
		if type(meta)~='table' or meta.__newindex ~= meta.ShortStubsHook then
			_G.geterrorhandler()("LibStub.Short:UnhookLibs():  the metatable of LibStub.libs has been modified, cannot unhook.")
		else
			meta.__newindex = nil
			if not _G.next(meta) then  _G.setmetatable(self.libs, nil)  end
		end
		self.libs = nil
	end


	-- Set up.
	Shorty:HookLibs(LibStub.libs)

end -- LibStub.Short



