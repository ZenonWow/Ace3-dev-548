local _G, LIBSTUB_NAME, LIBSTUB_VERSION = _G, LIBSTUB_NAME or "LibStub", 3
local LibStub = _G[LIBSTUB_NAME] or { libs = {}, minors = {}, minor = 0 }

-- @requires LibStub.New.lua
-- Check if current version of LibStub:NewGlobalLibrary() is obsolete.
if  not LibStub.NewGlobalLibrary  or  LibStub.minor < LIBSTUB_VERSION and (LibStub.minorNewGlobalLibrary or 0) < LIBSTUB_VERSION  then
	LibStub.minorNewGlobalLibrary = LIBSTUB_VERSION
	_G[LIBSTUB_NAME] = LibStub

	function LibStub:NewGlobalLibrary(libname, version, globalname)
		local global = _G[globalname or libname]
		local lib, oldversion = self:NewLibrary(libname, version, global)
		if  lib  and  not global  then
			_G[globalname or libname] = lib
		elseif  lib  and  global ~= lib  then
			_G.geterrorhandler()( "Warning: LibStub:NewGlobalLibrary("..libname..", "..version..", ".._G.tostring(globalname).."):  _G.".._G.tostring(globalname or libname).." is different from the library in LibStub." )
		end
		return lib, oldversion
	end

end -- LibStub.NewGlobalLibrary

