local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or "LibStub", 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }

-- @requires LibStub.New.lua
-- Check if current version of LibStub:NewGlobalLibrary() is obsolete.
if  not LibStub.NewGlobalLibrary  or  LibStub.minor < LIBSTUB_VERSION and (LibStub.minorNewGlobalLibrary or 0) < LIBSTUB_VERSION  then
	LibStub.minorNewGlobalLibrary = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

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

end -- LibStub.NewGlobalLibrary

