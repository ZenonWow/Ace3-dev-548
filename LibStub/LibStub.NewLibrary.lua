local _G, LIBSTUB_NAME, LIBSTUB_REVISION, LIB_NAME = _G, LIBSTUB_NAME or 'LibStub', 3,  "LibStub.NewLibrary"
local LibStub = _G[LIBSTUB_NAME] or { minor = 0, libs = {}, minors = {} }

-- Check if current version of LibStub:NewLibrary() is obsolete.
if  not LibStub.NewLibrary  or  ( (LibStub.minor or 0) < LIBSTUB_REVISION  and  (LibStub.minors[LIB_NAME] or 0) < LIBSTUB_REVISION )  then
	LibStub.libs[LIB_NAME] = LibStub
	LibStub.minors[LIB_NAME] = LIBSTUB_REVISION
	_G[LIBSTUB_NAME] = LibStub

	-- Upvalued Lua globals:

	local type,tonumber,tostring,strmatch = type,tonumber,tostring,string.match
	local function torevision(version)  return  tonumber(version)  or  type(version)=='string' and tonumber(strmatch(version, "%d+")) )  end

	function LibStub:NewLibrary(name, revision, _, _, stackdepth)
		if type(name)~='string' then  _G.error( "Usage: LibStub:NewLibrary(name, revision):  `name` - string expected, got "..type(name) , (stackdepth or 1)+1 )  end

		revision = torevision(revision)
		if not revision then
			_G.error( "Usage: LibStub:NewLibrary(name, revision):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )
		end

		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision then  return nil  end

		local lib = self.libs[name] or {}
		-- self.libs[name] = lib
		-- if not oldrevision then  self._newminor(minors, name, revision)  end
		self.libs[name], self.minors[name] = lib, revision
		return lib, oldrevision or 0
	end

end -- LibStub.NewLibrary

