-- LibStubs.<shortname>  enables the use of short library references in the form:
-- LibStubs.LibDataBroker, LibStubs.LibSharedMedia, LibStubs.AceAddon
-- LibStubs.LibDataBroker11, LibStubs.LibSharedMedia30, LibStubs.AceAddon30, etc.
-- The short reference without version number refers to the highest major version loaded.
-- eg.  LibStubs.AceAddon  is  LibStubs.AceAddon30, not LibStubs.AceAddon20.
-- Different major versions are generally not around. If in doubt, use the reference with version number.
-- Does _not_ raise an error if the library is not found.

-- GLOBALS:
-- Exported to _G:  LibStubs
-- Used from LibCommon:
-- Used from _G:  pairs, next, getmetatable, setmetatable, geterrorhandler
-- Upvalued Lua globals:  type,getmetatable,setmetatable,rawset


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


	local function InsertCheckConflict(shortNames, lib, name, short)
		-- Remove '-','.' so the resulting name is a valid lua variable name.
		name = name:gsub("[%-%.]", "")
		local conflict = shortNames[short]
		if conflict == lib then  return  end
		if _G.DEVMODE then  _G.LibCommon.softassert(not conflict, 'Warn: LibStub.Short:  There should be no conflicting shortname, and there it is: "'..name..'" vs "'..tostring(conflict.name)..'"."')  end
		if  conflict  and  name <= (conflict.name or "")  then  return  end
		shortNames[short] = lib
	end

	function Shorty:BeforeDefineLibrary(lib, name, revision, oldrevision)
		if oldrevision then  return  end    -- Do it only at first definition.
		-- Insert with subversion, eg.:  AceAddon30
		-- InsertCheckConflict(self.shortNames, lib, name, name)
		-- Remove ".0" subversion, eg.:  AceAddon3,  CallbackHandler1,  but LibDataBroker11
		local nameNoSub0 = name:gsub("%.0$", "")
		InsertCheckConflict(self.shortNames, lib, name, nameNoSub0)
		-- Remove "-1" and "-1.0" version completely, eg.:  CallbackHandler-1.0 -> CallbackHandler
		local nameNoMajor1 = nameNoSub0:gsub("%-1$", "")
		InsertCheckConflict(self.shortNames, lib, name, nameNoMajor1)
	end

	-- Import the loaded libraries from LibStub.
	for name,lib in _G.pairs(LibStub.libs) do
		Shorty:BeforeDefineLibrary(lib, name)
	end

	assert(LibStub.RegisterCallback, 'LibStub.Short requires "LibStub.PreCreateLibrary" loaded before.')
	LibStub:RegisterCallback(Shorty)

end


