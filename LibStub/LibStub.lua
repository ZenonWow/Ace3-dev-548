-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, VERSION: 2 -> 3

--- Revision 3:
-- Adds a hook function for LibStub.PreCreateLibrary, which is optional, but more efficient than hooking __newindex on LibStub.minors (done for MINOR=2).
-- Allows fractional MINOR revision numbers such as 2.1 for development versions, patches.  Svn rev. 52 (2007-08-26) removed this possibility.
-- Patches should not go over .9, that would confuse the version comparison:  x.10 < x.9  evaluates as smaller.

-- GLOBALS: <none>
-- Exported to _G:  LibStub
-- Used from _G:  error,geterrorhandler,getmetatable,pairs
-- Upvalued:  type,tonumber,tostring,strmatch,setmetatable


local _G, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = _G[LIBSTUB_NAME] or { minor = 0, libs = {}, stubs = {}, minors = {} }  --, dependents = {} }

-- Check if current version of LibStub is obsolete.
if  (LibStub.minor or 0) < LIBSTUB_REVISION  then
	_G[LIBSTUB_NAME] = LibStub
	LibStub.name  = LIBSTUB_NAME
	LibStub.minor = LIBSTUB_REVISION
	LibStub.stubs = LibStub.stubs or {}
	-- LibStub.libs, LibStub.minors  =  LibStub.libs or {}, LibStub.minors or {}
	-- LibStub.libs.LibStub, LibStub.minors.LibStub  =  LibStub, LIBSTUB_REVISION

	-- Upvalued Lua globals:
	local type,tonumber,tostring,strmatch,setmetatable = type,tonumber,tostring,string.match,setmetatable
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
			_G.error( "Usage: LibStub:NewLibrary(name, revision):  `name` - string expected, got "..type(name) , (stackdepth or 1)+1 )
		end

		revision = torevision(revision)
		if not revision then
			_G.error( "Usage: LibStub:NewLibrary(name, revision):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )
		end

		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision then  return nil  end

		if _G.DEVMODE and _G.DEVMODE.LibStub then  _G.print("LibStub:NewLibrary():", name, "  rev:", oldrevision, "->", revision, "  @", _G.debugstack(2,1,0):gsub(": .*", ""):gsub("^Interface\\AddOns\\", ""):gsub("^%.%.[^:]*Ons\\", "") )  end
		-- Huh that was tedious. Now, Dear-lua, did i forget the end at the end? ;-)
		local lib =  self.libs[name]  or  self.stubs[name]  or  {}
		self.libs[name], self.minors[name] = lib, revision
		-- The minimal LibStub.NewLibrary.lua does not have this call.
		LibStub:BeforeDefineLibrary(lib, name, revision, oldrevision)
		return lib, oldrevision
	end


	function LibStub._donothing()  end
	-----------------------------------------------------------------------------
	-- Function to hook by LibStub.BeforeDefineLibrary.
	LibStub.BeforeDefineLibrary = LibStub.BeforeDefineLibrary  or  LibStub._donothing


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
		if lib then  return lib, self.minors[name]  end
		if  optional == true  or  type(optional)=='number'  then  return nil  end
		if type(optional)=='table' then  optional = tostring(optional.name or optional)  end

		if type(optional)=='string' then  _G.error(optional..' requires "'..tostring(name)..'" library loaded before.', 2)
		elseif optional then  return nil    -- Just in case non-boolean `optional` parameter was passed, eg. the number 1.
		else  _G.error('LibStub:GetLibrary("'..tostring(name)..'"):  library is not loaded at this point.', 2)
		end
	end

	--- LibStub(name, [optional/client])
	local metatable = _G.getmetatable(LibStub)
	if not metatable then  metatable = {}  ;  setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary
	-- Protect from setmetatable(), while getmetatable() works as usual.
	metatable.__metatable = metatable


	-----------------------------------------------------------------------------
	--- for  name,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries()  return _G.pairs(self.libs)  end

end -- LibStub



