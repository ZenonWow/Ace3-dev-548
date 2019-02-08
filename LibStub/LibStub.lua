-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, VERSION: 2 -> 3

--- Version 3:
-- Saves  lib.name = major  and  lib.revision = minor.
-- Allows fractional MINOR version numbers such as 2.1 to express patches, development versions (svn rev. 52 (2007-08-26) removed this possibility).
-- Releases are whole numbers. Patches should not go over .9, that would confuse the version comparison:  x.10 < x.9  evaluates as smaller.

-- GLOBALS: <none>
-- Upvalued:  type,tonumber,tostring,strmatch,setmetatable
-- Used from _G:  error,geterrorhandler,getmetatable,pairs
-- Exported to _G:  LibStub


local _G, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = _G[LIBSTUB_NAME] or { minor = 0, libs = {}, minors = {}, dependents = {}  }

-- Check if current version of LibStub is obsolete.
if  (LibStub.minor or 0) < LIBSTUB_REVISION  then
	_G[LIBSTUB_NAME] = LibStub
	LibStub.minor  = LIBSTUB_REVISION
	LibStub.libs   = LibStub.libs   or {}
	LibStub.minors = LibStub.minors or {}
	LibStub.libs.LibStub   = LibStub
	LibStub.minors.LibStub = LIBSTUB_REVISION

	-- Upvalued Lua globals:
	local type,tonumber,tostring,strmatch,setmetatable = type,tonumber,tostring,string.match,setmetatable
	local function torevision(version)  return  tonumber(version)  or  type(version)=='string' and tonumber(strmatch(version, "%d+")) )  end

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(name, revision): Declare a library implementation.
	-- Returns the library object if declared revision is an upgrade and needs to be loaded.
	-- @param name (string) - the name and major version of the library.
	-- @param revision (number/string) - the minor version of the library.
	-- @return nil  if newer or same revision of the library is already present.
	-- @return old library object (empty table at first) if upgrade is needed.
	--
	function LibStub:NewLibrary(name, revision, _, _, stackdepth)
		if type(name)~='string' then  _G.error( "Usage: LibStub:NewLibrary(name, revision):  `name` - string expected, got "..type(name) , (stackdepth or 1)+1 )  end
		revision = torevision(revision)
		if not revision then  _G.error( "Usage: LibStub:NewLibrary(name, revision):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )  end

		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision then  return nil  end

		local lib =  self.libs[name]  or  { name = name }
		self.libs[name], self.minors[name], lib.revision = lib, revision, revision
		if not oldrevision then  self:_PreCreateLibrary(lib, name)  end
		return lib, oldrevision or 0
	end

	-- Callback before first loading a library.
	function LibStub:_PreCreateLibrary(lib, name)
		setmetatable(lib, self.LibMeta)
		for i,receiver in ipairs(self.callbacks) do  receiver:LibStub_PreCreateLibrary(lib, name)  end
	end

	-- Library metatable for pretty print(lib).
	LibStub.LibMeta    = LibStub.LibMeta    or {}
	LibStub.LibMeta.__tostring  = function(lib)  return  lib.revision  and  tostring(lib.name).." (r"..tostring(lib.revision)..")"  or  tostring(lib.name)  end


	-----------------------------------------------------------------------------
	--- LibStub:RegisterCallback(receiver)
	-- Adds a recever for the  receiver:LibStub_PreCreateLibrary(lib, name)  event.
	--
	LibStub:RegisterCallback(receiver)
		assert(receiver.LibStub_PreCreateLibrary, "LibStub:RegisterCallback(receiver):  receiver must have :LibStub_PreCreateLibrary(lib, name) method.")
		if self.callbacks[receiver] then  return false  end
		self.callbacks[#self.callbacks+1], self.callbacks[receiver] receiver,receiver
	end

	LibStub.callbacks = LibStub.callbacks or setmetatable({}, { __mode = 'kv'} )


	-----------------------------------------------------------------------------
	--- LibStub(name, [optional/client]): Get a library from the registry.
	--- LibStub:GetLibrary(name, [optional/client])
	-- @throw an error if the library is not loaded (if not optional).
	-- @param name (string) - the name and major version of the library.
	-- @param optional (boolean) - don't raise error if optional, just silently return nil if its not loaded.
	-- @param client (table/string) - dependent library/addon object or the name of it.
	--   Client's .name is included in error report if requested library is not loaded.
	-- @return the library object if found.
	function LibStub:GetLibrary(name, optional)
		local lib = self.libs[name]
		if lib then  return lib, self.minors[name]
		if  optional == true  or  type(optional)=='number'  then  return nil  end
		if type(optional)=='table' then  optional = tostring(optional.name or optional)  end
		if type(optional)=='string' then  _G.error(optional..' requires "'..tostring(name)..'" library loaded before.", 2)
		elseif optional then  return nil    -- Just in case non-boolean `optional` parameter was passed, eg. the number 1.
		else  _G.error('LibStub:GetLibrary("'..tostring(name)..'"):  library is not loaded at this point.", 2)
		end
	end

	--- LibStub(name, [optional/client])
	local metatable = _G.getmetatable(LibStub)
	if not metatable then  metatable = {}  ;  setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary


	-----------------------------------------------------------------------------
	--- for  name,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries()  return _G.pairs(self.libs)  end


	-----------------------------------------------------------------------------
	-- Upgrade libs with .name and .revision fields. (oldversion <= 2)
	for name,lib in _G.pairs(LibStub.libs) do
		lib.name     = lib.name     or name
		lib.revision = lib.revision or LibStub.minors[name]
	end

end -- LibStub



