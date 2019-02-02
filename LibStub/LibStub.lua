-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, VERSION: 2 -> 3

--- Version 3:
-- Saves  lib.libname = major  and  lib.version = minor.
-- Allows fractional MINOR version numbers such as 2.1 to express patches, development versions (svn rev. 52 (2007-08-26) removed this possibility).
-- Releases are whole numbers. Patches should not go over .9, that would confuse the version comparison:  x.10 < x.9  evaluates as smaller.

-- GLOBALS: <none>
-- Used from _G:  error,tostring,geterrorhandler,getmetatable,setmetatable,pairs

local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or "LibStub", 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }
local oldversion = LibStub.minor or 0

-- Check if current version of LibStub is obsolete.
if  oldversion < LIBSTUB_VERSION  then
	LibStub.minor = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

	-- Upvalued Lua globals
	local type,tonumber,strmatch = type,tonumber,string.match

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(libname, version): Declare a library implementation.
	-- Returns the library object if this version is an upgrade and needs to be loaded.
	-- @param libname (string) - the name and major version of the library.
	-- @param version (number or string) - the minor version of the library.
	-- @return  nil  if a newer or same version of the lib is already present.
	-- @return empty library object or old library object if upgrade is needed.
	--
	function LibStub:NewLibrary(libname, version)
		if type(libname)~='string' then  _G.error( "Usage: LibStub:NewLibrary(libname, version):  `libname` - string expected, got "..type(libname) )  end
		version = tonumber(version) or tonumber(strmatch(version, "%d+"))
		if not version then  _G.error( "Usage: LibStub:NewLibrary(libname, version):  `version` - expected a number or a string containing a number, got '".._G.tostring(version).."'." )  end

		local oldversion = self.minors[libname]
		if oldversion and oldversion >= version then  return nil  end

		local lib =  self.libs[libname]  or  { libname = libname }
		self.libs[libname], self.minors[libname], lib.version = lib, version, version
		return lib, oldversion
	end

	function LibStub:NewGlobalLibrary(libname, version, globalname)
		local global = _G[globalname or libname]
		if  global  and  not self.libs[libname]  then    -- Import if not in LibStub.
			self.libs[libname], self.minors[libname] = global, global.version
		end
		local lib, oldversion = self:NewLibrary(libname, version, global)
		if  lib  and  not global  then
			_G[globalname or libname] = lib
		elseif  lib  and  global ~= lib  then
			_G.geterrorhandler()( "Warning: LibStub:NewGlobalLibrary("..libname..", "..version..", ".._G.tostring(globalname).."):  _G.".._G.tostring(globalname or libname).." is different from the library in LibStub." )
		end
		return lib, oldversion
	end

	-----------------------------------------------------------------------------
	--- LibStub(libname, [optional, clientname]): Get a library from the registry.
	--- LibStub:GetLibrary(libname, [optional, clientname])
	-- Raises an error if the library is not loaded (except if optional is set).
	-- @param libname (string) - the name and major version of the library.
	-- @param optional (boolean) - don't raise error if optional, just silently return nil if its not loaded.
	-- @param clientname (string) - name of dependent library/addon to put in error report if requested library is not loaded.
	-- @return the library object if found.
	function LibStub:GetLibrary(libname, optional, clientname)
		local lib = self.libs[libname]
		if lib or optional then  return lib, self.minors[libname]  end
		if clientname then  _G.error(clientname..' requires "'.._G.tostring(libname)..'" library loaded before.", 2)
		else  _G.error('LibStub:GetLibrary("'.._G.tostring(libname)..'"):  library is not loaded at this point.", 2)
		end
	end

	--- LibStub(libname, [optional])
	local metatable = _G.getmetatable(LibStub)
	if not metatable then  metatable = {} ; _G.setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary

	-----------------------------------------------------------------------------
	--- for  libname,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries() return _G.pairs(self.libs) end

	-----------------------------------------------------------------------------
	-- Upgrade libs with .libname and .version fields. (oldversion <= 2)
	if oldversion <= 2 then  for libname,lib in _G.pairs(LibStub.libs) do
		lib.libname, lib.version = libname, LibStub.minors[libname]
	end end -- if for

end -- LibStub



