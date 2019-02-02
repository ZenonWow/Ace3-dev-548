-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub core part is the minimum to include in libraries to use  LibStub:NewLibrary(libname, version) 
-- Can be copied without comments to the front of a one-file library, or included separately.

-- GLOBALS: _G, LibStub, assert, type, error, tonumber, string

if  not LibStub  then
	-- This core is stripped from the  LibStub.minor == 3  version.
	-- Set minor = 0 to let any full LibStub version overwrite this core.
	LibStub = { libs = {}, minors = {}, minor = 0 }

	-----------------------------------------------------------------------------
	--- LibStub:NewLibrary(libname, version): Declare a library implementation.
	-- Returns the library object if this version is an upgrade and needs to be loaded.
	-- @param libname (string) - the name and major version of the library.
	-- @param version (number or string) - the minor version of the library.
	-- @param global (nil/true) - if true then export to global environment as _G[libname].
	-- @param global (string) - if string then export to global environment as _G[global].
	-- Also imports from _G[libname/global] if library is not in LibStub yet.
	-- Useable to import previous non-LibStub versions of libraries.
	-- @return  nil  if a newer or same version of the lib is already present.
	-- @return empty library object or old library object if upgrade is needed.
	function LibStub:NewLibrary(libname, version, global)
		assert( type(libname)=='string', "LibStub:NewLibrary(libname, version, global):  `libname` - string expected" )
		assert( not global or global == true or type(global)=='string', "LibStub:NewLibrary(libname, version, global):  `global` - nil/boolean or string expected" )
		version = tonumber(version) or tonumber(string.match(version, "%d+"))
		if not version then  error( "LibStub:NewLibrary(libname, version, global):  `version` - expected a number or a string containing a number" )

		local oldversion = self.minors[libname], 
		if oldversion and oldversion >= version then  return nil  end

		if global == true then  global = libname  end
		local lib =  self.libs[libname]  or  global and _G[global]  or  {}
		self.libs[libname], self.minors[libname], lib.version = lib, version, version
		if lib.libname == nil then  lib.libname = libname  end
		if  global  and  not _G[global]  then  _G[global] = lib  end
		return lib, oldversion
	end

end



