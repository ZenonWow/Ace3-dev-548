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

	-- Exported to _G:  LibStubs == LibStub.Short
	_G[LIBSTUBS_NAME] = _G[LIBSTUBS_NAME] or Shorty.shortNames
	if _G[LIBSTUBS_NAME] ~= Shorty.shortNames then
		_G.geterrorhandler()("LibStub.Short:  _G."..LIBSTUBS_NAME.." is already in use.")
	end


	local function InsertCheckConflict(shortNames, lib, libname, short)
		local conflict = shortNames[short]
		if  conflict == lib  then  return  end
		if  conflict  and  libname <= (conflict.libname or "")  then  return  end
		shortNames[short] = lib
	end

	function Shorty:LibStub_PreCreateLibrary(lib, libname)
		-- Remove '-','.'
		InsertCheckConflict(self.shortNames, lib, libname, libname:gsub("[%-%.]", "") )
		-- Remove version: "-n.n" and remove '-','.'
		InsertCheckConflict(self.shortNames, lib, libname, libname:gsub("%-[%.%d]+$", ""):gsub("[%-%.]", "") )
	end

	-- Import the loaded libraries from LibStub.
	for libname,lib in _G.pairs(LibStub.libs) do
		Shorty:LibStub_PreCreateLibrary(lib, libname)
	end

	assert(LibStub.RegisterCallback, 'LibStub.Short requires "LibStub.PreCreateLibrary" loaded before.')
	LibStub:RegisterCallback(Shorty)

end


