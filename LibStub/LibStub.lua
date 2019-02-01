-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, VERSION: 2 -> 2.1
--- Version 3:
-- Saves  lib.libname = major  and  lib.version = minor.
-- Allows fractional MINOR version numbers such as 2.1 to express patches, development versions (svn rev. 52 (2007-08-26) removed this possibility).
-- Releases are whole numbers. Patches should not go over .9:  x.10 < x.9
--- LibShort.LibDataBroker, LibShort.LibSharedMedia:  Enables the use of short references.

-- GLOBALS: _G, type, error, tonumber, tostring, string, pairs, setmetatable, getmetatable

local LIBSTUB_NAME, LIBSTUB_VERSION = "LibStub", 2.1
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }

-- Check to see if current version of the stub is obsolete.
if  LibStub.minor < LIBSTUB_VERSION  then
	LibStub.minor = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(libname, version): Declare a library implementation.
	-- Returns the library object if this version is an upgrade and needs to be loaded.
	-- @param libname (string) - the name and major version of the library.
	-- @param version (number or string) - the minor version of the library.
	-- @return  nil  if a newer or same version of the lib is already present.
	-- @return empty library object or old library object if upgrade is needed.
	function LibStub:NewLibrary(libname, version)
		if type(libname)~='string' then  error( "LibStub:NewLibrary(libname, version):  `libname` - string expected, got "..type(libname) )  end
		version = tonumber(version) or tonumber(string.match(version, "%d+"))
		if not version then  error( "LibStub:NewLibrary(libname, version):  `version` - expected a number or a string containing a number, got '"..tostring(version).."'." )  end

		local oldversion = self.minors[libname]
		if oldversion and oldversion >= version then  return nil  end

		local lib =  self.libs[libname]  or  { libname = libname }
		self.libs[libname], self.minors[libname], lib.version = lib, version, version
		return lib, oldversion
	end

	-----------------------------------------------------------------------------
	--- LibStub(libname, [optional]): Get a library from the registry.
	--- LibStub:GetLibrary(libname, [optional])
	-- Raises an error if the library can not be found (except if optional is set).
	-- @param libname (string) - the name and major version of the library.
	-- @param optional (boolean) - don't raise error if optional, just silently return nil if its not found.
	-- @return the library object if found.
	function LibStub:GetLibrary(libname, optional)
		local lib = self.libs[libname]
		if lib or optional then  return lib, self.minors[libname]  end
		error('Cannot find a library instance of "'..tostring(libname)..'".', 2)
	end

	--- LibStub(libname, [optional])
	local metatable = getmetatable(LibStub)
	if not metatable then  metatable = {} ; setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary

	-----------------------------------------------------------------------------
	--- for  libname,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries() return pairs(self.libs) end

	-----------------------------------------------------------------------------
	-- Upgrade libs with .libname and .version fields. (oldversion <= 2)
	for libname,lib in pairs(LibStub.libs) do
		lib.libname, lib.version = libname, LibStub.minors[libname]
	end

end  -- LibStub



