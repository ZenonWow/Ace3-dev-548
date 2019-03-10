local G, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = G[LIBSTUB_NAME] or { minor = 0, libs = {}, stubs = {}, minors = {} }  --, dependents = {} }

-- GLOBALS: <none>
-- Exported to _G:  LibStub, LibStub:NewLibrary()
-- Used from _G:  error,getmetatable,setmetatable
-- Upvalued Lua globals:  type,tonumber,tostring,strmatch


-- Check if current version of LibStub.NewLibraryPart is obsolete.
if (LibStub.minors[LibStub.NewLibraryPart] or LibStub.minor or 0) < LIBSTUB_REVISION then

	-- Upvalued Lua globals:
	local type,tonumber,tostring,strmatch = type,tonumber,tostring,string.match

	-----------------------------------------------------------------------------
	--- LibStub:NewLibraryPart(name, revision, partName):  Declare part of a library implementation.
	-- Returns the library object if declared revision is an upgrade and needs to be loaded.
	-- @param name (string) - the name and major version of the library.
	-- @param revision (number) - the minor version of the library. Increment it when an updated version is released.
	-- @param partName (string) - the name of the function in the library.
	-- @return nil  if newer or same revision of the library is already present.
	-- @return library object (empty table initially) if upgrade is needed.
	--
	function LibStub:NewLibraryPart(name, revision, partName)
		if type(name)~='string' then
			G.error( "Usage: LibStub:NewLibraryPart(name, revision, partName):  `name` - string expected, got "..type(name) , 2 )
		end
		if type(revision)~='number' then
			G.error( "Usage: LibStub:NewLibraryPart(name, revision, partName):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , 2 )
		end
		if type(partName)~='string' then
			G.error( "Usage: LibStub:NewLibraryPart(name, revision, partName):  `partName` - string expected, got "..type(partName) , 2 )
		end

		local lib =  self.libs[name]  or  lib  or  self.stubs[name]  or  {}
		local part = lib[partName]
		local oldrevision = self.minors[name.."."..partName]  or  nil~=part and self.minors[name]
		if oldrevision and oldrevision >= rev then  return nil  end

		self.libs[name], self.minors[name.."."..partName] = lib, rev

		-- BeforeNewLibrary is called by :NewLibrary() usually after the :NewLibraryPart()s.
		-- self:BeforeNewLibrary(lib, name, rev, oldrevision)
		return lib, oldrevision
	end

end -- LibStub.NewLibraryPart


