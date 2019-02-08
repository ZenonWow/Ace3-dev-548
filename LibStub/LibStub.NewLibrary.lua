local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or "LibStub", 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }

-- Check if current version of LibStub:NewLibrary() is obsolete.
if  not LibStub.NewLibrary  or  LibStub.minor < LIBSTUB_VERSION and (LibStub.minorNewLibrary or 0) < LIBSTUB_VERSION  then
	LibStub.minorNewLibrary = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

	-- Upvalued Lua globals
	local type,tonumber,strmatch = type,tonumber,string.match

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

end -- LibStub.NewLibrary

