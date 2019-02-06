-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, VERSION: 2 -> 3

--- Version 3:
-- Saves  lib.name = major  and  lib.version = minor.
-- Allows fractional MINOR version numbers such as 2.1 to express patches, development versions (svn rev. 52 (2007-08-26) removed this possibility).
-- Releases are whole numbers. Patches should not go over .9, that would confuse the version comparison:  x.10 < x.9  evaluates as smaller.

-- GLOBALS: <none>
-- Upvalued:  _G,type,tonumber,tostring,strmatch
-- Used from _G:  error,geterrorhandler,getmetatable,setmetatable,pairs
-- Exported to _G:  LibStub


local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, stubs = {}, minors = {}, minor = 0 }
local oldversion = LibStub.minor or 0

-- Check if current version of LibStub is obsolete.
if  oldversion < LIBSTUB_VERSION  then
	_G[LIBSTUB_NAME] = LibStub
	LibStub.minor = LIBSTUB_VERSION
	LibStub.stubs = LibStub.stubs or {}

	-- Upvalued Lua globals:
	local type,tonumber,tostring,strmatch = type,tonumber,tostring,string.match
	local function toversion(version)  return  tonumber(version)  or  type(version)=='string' and tonumber(strmatch(version, "%d+")) )  end

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(name, version): Declare a library implementation.
	-- Returns the library object if declared version is an upgrade and needs to be loaded.
	-- @param name (string) - the name and major version of the library.
	-- @param version (number/string) - the minor version of the library.
	-- @return nil  if newer or same version of the library is already present.
	-- @return old library object (empty table at first) if upgrade is needed.
	--
	function LibStub:NewLibrary(name, version, _, _, stackdepth)
		if type(name)~='string' then  _G.error( "Usage: LibStub:NewLibrary(name, version):  `name` - string expected, got "..type(name) , (stackdepth or 1)+1 )  end
		version = toversion(version)
		if not version then  _G.error( "Usage: LibStub:NewLibrary(name, version):  `version` - expected a number or a string containing a number, got '"..tostring(version).."'." , (stackdepth or 1)+1 )  end

		local oldversion = self.minors[name]
		if oldversion and oldversion >= version then  return nil  end

		local lib =  self.libs[name]  or  self.stubs[name]  or  { name = name }
		self.libs[name], self.minors[name], lib.version = lib, version, version
		if not oldversion then  self:_OnCreateLibrary(lib)  end
		return lib, oldversion
	end

	-----------------------------------------------------------------------------
	--- LibStub:NewGlobalLibrary(name, version, [globalname, [oldversion]]):
	-- Declare a library implementation and export to global environment as:  _G[globalname or name]
	-- Returns the library object if declared version is an upgrade and needs to be loaded.
	-- @param name (string) - the name and major version of the library.
	-- @param version (number/string) - the minor version of the library.
	-- @param globalname (string) - export to global environment with this name (default: same as the library name)
	-- @param oldversion (number/string) - version of previous global library, needed if not stored in  _G[globalname].version
	-- @return nil  if newer or same version of the library is already present.
	-- @return old library object (empty table at first) if upgrade is needed.
	--
	function LibStub:NewGlobalLibrary(name, version, globalname, oldversion)
		local global = _G[globalname or name]
		if  type(global)=='table'  and  not self.libs[name]  then    -- Import if not in LibStub.
			self.libs[name], self.minors[name] = global, toversion(oldversion or global.version) or 1
		end
		local lib, oldversion = self:NewLibrary(name, version, nil, nil, 2)

		if  lib  and  not global  then
			_G[globalname or name] = lib
		elseif  lib  and  global ~= lib  then
			_G.geterrorhandler()( "Warning: LibStub:NewGlobalLibrary("..name..", "..version..", "..tostring(globalname).."):  _G."..tostring(globalname or name).." is different from the library in LibStub." , 2 )
		end
		return lib, oldversion
	end

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
		if lib or optional == true then  return lib, self.minors[name]  end
		if type(optional)=='table' then  optional = tostring(optional.name or optional)  end
		if type(optional)=='string' then  _G.error(optional..' requires "'..tostring(name)..'" library loaded before.", 2)
		elseif optional then  return lib    -- Just in case non-boolean `optional` parameter was passed, eg. the number 1.
		else  _G.error('LibStub:GetLibrary("'..tostring(name)..'"):  library is not loaded at this point.", 2)
		end
	end

	--- LibStub(name, [optional/client])
	local metatable = _G.getmetatable(LibStub)
	if not metatable then  metatable = {} ; _G.setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary


	-----------------------------------------------------------------------------
	--- for  name,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries()  return _G.pairs(self.libs)  end


	-----------------------------------------------------------------------------
	-- Upgrade libs with .name and .version fields. (oldversion <= 2)
	for name,lib in _G.pairs(LibStub.libs) do
		lib.name    = lib.name    or name
		lib.version = lib.version or LibStub.minors[name]
	end



	-- Upvalued Lua globals:
	local ipairs,unpack = ipairs,unpack

	-----------------------------------------------------------------------------
	--- LibStub:GetDependencies(client, libname, libname*)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library objects, or placeholder stubs for not loaded libraries.
	function LibStub:GetDependencies(client, libname, ...)
		if ... then
			local libs = {}
			for i,name in ipairs({ libname, ... }) do  libs[i] = self:GetDependency(client, name, 2)  end
			return unpack(libs)
		else
			return self:GetDependency(client, libname, 2)
		end
	end

	-----------------------------------------------------------------------------
	--- LibStub:GetDependency(client, libname)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library object, or placeholder stub if not loaded yet.
	function LibStub:GetDependency(client, libname, stackdepth)
		if type(libname)~='string' then  error( "Usage: LibStub:GetDependency(client, libname):  `libname` - expected string, got "..type(libname) , (stackdepth or 1)+1)  end
		local lib = self.libs[libname]
		if lib then  return lib  end
		-- if self.version[libname] then  return lib  end
		lib = self.stubs[libname] or _G.setmetatable({ name = libname, LibNotLoaded = true, dependents = {} }, self.StubMeta)
		self.stubs[libname] = lib
		lib.dependents.lib = lib  -- Circular reference.
		lib.dependents[#lib.dependents+1] = client
		return lib
	end


	-----------------------------------------------------------------------------
	--- LibStub:RegisterCallback(receiver, callback)
	--
	LibStub:RegisterCallback(receiver, callback)  self.callbacks[receiver] = callback  end
	LibStub.callbacks = { [LibStub] = LibStub._FirstLoadInit }

	function LibStub:_OnCreateLibrary(lib)
		for receiver,callback in self.callbacks do  callback(receiver, lib)  end
	end


	-----------------------------------------------------------------------------
	-- On first load: replace the StubMeta metatable with LibMeta,  clear LibNotLoaded flag
	function LibStub:_FirstLoadInit(lib)
		_G.setmetatable(lib, self.LibMeta)
		-- self.loaded[#self.loaded+1] = lib.dependents
		lib.dependents, lib.LibNotLoaded = nil,nil
	end

	-- LibStub.loaded = LibStub.loaded or {}
	LibStub.LibMeta = LibStub.LibMeta or {}
	LibStub.StubMeta = LibStub.StubMeta or {}
	LibStub.LibMeta.__tostring = function(lib)  return  lib.version  and  lib.name.." (v"..lib.version..")"  or  lib.name  end
	LibStub.StubMeta.__tostring = function(lib)  return  lib.name.." (is not loaded yet)"  end
	LibStub.StubMeta.__index = function(lib, field)  error(lib.name.." is not loaded yet.", 2)  end
	LibStub.StubMeta.__newindex = function(lib, field, newvalue)  error(lib.name.." is not loaded yet.", 2)  end

end -- LibStub



