-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-03 Mongusius, VERSION: 2 -> 3

--- Revision 3:
-- - Adds a callback function for the optional LibStub.BeforeNewLibrary.
--   The callback is more efficient than hooking __newindex on LibStub.minors, and also notifies of updates.
-- - Allows fractional MINOR revision numbers such as 2.1 for development versions, patches.  Svn rev. 52 (2007-08-26) removed this possibility.
--   Patches should not go over .9, that will confuse the version comparison:  x.10 < x.9  evaluates as smaller.

-- GLOBALS: <none>
-- Exported to _G:  LibStub, LibStub:NewLibrary()
-- Used from _G:  error,getmetatable,setmetatable
-- Upvalued:  type,tonumber,tostring,strmatch

local GL, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = GL[LIBSTUB_NAME] or { minor = 0, libs = {}, stubs = {}, minors = {} }  --, dependents = {} }


-- Check if current version of LibStub.NewLibrary is obsolete.
if (LibStub.minors[LibStub.NewLibrary] or LibStub.minor or 0) < LIBSTUB_REVISION then

	-- If both NewLibrary() and GetLibrary() are at this revision then LibStub.minor can be upgraded.
	if (LibStub.minors[LibStub.GetLibrary] or 0) >= LIBSTUB_REVISION then  LibStub.minor = LIBSTUB_REVISION  end

	GL[LIBSTUB_NAME] = LibStub
	LibStub.name  = LIBSTUB_NAME
	LibStub.stubs = LibStub.stubs or {}

	-- Upvalued Lua globals:
	local type,tonumber,tostring,strmatch = type,tonumber,tostring,string.match

	local function torevision(version)  return  tonumber(version)  or  type(version)=='string' and tonumber(strmatch(version, "%d+"))  end
	LibStub.torevision = torevision

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(name, revision): Declare a library implementation.
	-- Returns the library object if declared revision is an upgrade and needs to be loaded.
	-- @param name (string) - the name and major version of the library.
	-- @param revision (number/string) - the minor version of the library.
	-- @return nil  if newer or same revision of the library is already present.
	-- @return old library object (empty table at first) if upgrade is needed.
	--
	function LibStub:NewLibrary(name, revision, _, _, stackdepth)
		if type(name)~='string' then
			GL.error( "Usage: LibStub:NewLibrary(name, revision):  `name` - string expected, got "..type(name) , (stackdepth or 1)+1 )
		end

		revision = torevision(revision)
		if not revision then
			GL.error( "Usage: LibStub:NewLibrary(name, revision):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )
		end

		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision then  return nil  end

		local lib =  self.libs[name]  or  self.stubs[name]  or  {}
		self.libs[name], self.minors[name] = lib, revision
		
		-- Support BeforeNewLibrary and AfterNewLibrary event dispatchers.
		self:BeforeNewLibrary(lib, name, revision, oldrevision)
		return lib, oldrevision
	end


	-----------------------------------------------------------------------------
	--- LibStub:BeforeNewLibrary(lib, name, revision, oldrevision):
  -- Internal callback API implemented by the optional  LibStub.BeforeNewLibrary.lua. This is a dummy implementation.
	-- Most use-cases need instead  LibStub.AfterNewLibrary  for a notification _after_ a library is loaded/updated.
	LibStub.BeforeNewLibrary = LibStub.BeforeNewLibrary  or  function(lib, name, revision, oldrevision) end
	


	-- Upgrade revision of this feature.
	LibStub.minors[LibStub.NewLibrary] = LIBSTUB_REVISION
	-- LibStub.minors[LibStub.BeforeNewLibrary] = LibStub.minors[LibStub.BeforeNewLibrary] or 0
	
	-- Weak-keyed hashmap will let the old functions be garbagecollected after they are upgraded by a new revision.
	if not GL.getmetatable(LibStub.minors) then  GL.setmetatable(LibStub.minors, { __mode = 'k' })  end

end -- LibStub.NewLibrary


