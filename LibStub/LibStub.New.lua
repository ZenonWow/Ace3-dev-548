local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or "LibStub", 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }

-- Check if current version of LibStub:NewLibrary() is obsolete.
if  not LibStub.NewLibrary  or  LibStub.minor < LIBSTUB_VERSION and (LibStub.minorNewLibrary or 0) < LIBSTUB_VERSION  then
	LibStub.minorNewLibrary = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

	-- Upvalued Lua globals
	local type,tonumber,strmatch = type,tonumber,string.match

	function LibStub:NewLibrary(libname, version, import)
		if type(libname)~='string' then  _G.error( "Usage: LibStub:NewLibrary(libname, version, import):  `libname` - string expected, got "..type(libname) )  end
		version = tonumber(version) or tonumber(strmatch(version, "%d+"))
		if not version then  _G.error( "Usage: LibStub:NewLibrary(libname, version, import):  `version` - expected a number or a string containing a number, got '".._G.tostring(version).."'." )  end

		local oldversion = self.minors[libname]
		if oldversion and oldversion >= version then  return nil  end

		local lib =  self.libs[libname]  or  import  or  { libname = libname }
		oldversion = oldversion or lib.version  -- Get .version from import.
		self.libs[libname], self.minors[libname], lib.version = lib, version, version
		if lib.libname == nil then  lib.libname = libname  end
		return lib, oldversion
	end

end -- LibStub.NewLibrary

