-- LibStubs.<shortname>  enables the use of short library references in the form:
-- LibStubs.LibDataBroker, LibStubs.LibSharedMedia, LibStubs.AceAddon
-- LibStubs.LibDataBroker11, LibStubs.LibSharedMedia30, LibStubs.AceAddon30, etc.
-- The short reference without version number refers to the highest major version loaded.
-- eg.  LibStubs.AceAddon  is  LibStubs.AceAddon30, not LibStubs.AceAddon20.
-- Different major versions are generally not around. If in doubt, use the reference with version number.
-- Does _not_ raise an error if the library is not found.


-- local _G, LibShort = _G, LibStub:NewLibrary('LibStub.Short', 1)
local _G, LibShort = _G, LibStub:NewGlobalLibrary('LibStub.Short', 1, 'LibStubs')
if LibShort then
	-- _G.LibStubs = LibShort
	-- LibStub.Short = LibShort

	local function InsertCheckConflict(LibShort, libname, lib, short)
		local conflict = LibShort[short]
		if  conflict == lib  then  return  end
		if  conflict  and  libname <= (conflict.libname or "")  then  return  end
		LibShort[short] = lib
	end

	local function IndexLib(LibShort, libname, lib)
		-- Remove '-','.'
		InsertCheckConflict(LibShort, libname, lib, libname:gsub("[%-%.]", "") )
		-- Remove version: "-n.n" and remove '-','.'
		InsertCheckConflict(LibShort, libname, lib, libname:gsub("%-[%.%d]+$", ""):gsub("[%-%.]", "") )
	end


	-- Hook the original LibStub.libs map.
	function LibShort:_HookLibs(libs)
		self._libs = libs

		-- Import the loaded libraries from LibStub.
		for libname,lib in pairs(libs) do
			lib.libname = libname
			IndexLib(self, libname, lib)
		end

		-- The metatable hook to capture new libraries.
		local rawset = _G.rawset
		self._libsMeta = self._libsMeta or {}
		-- `self` (LibShort) is upvalued, `libs` is _not_, it's a parameter of __newindex()
		self._libsMeta.__newindex = function(libs, libname, lib)
			rawset(libs, libname, lib)
			IndexLib(self, libname, lib)
		end

		-- Hook the metatable of LibStub.libs
		if getmetatable(libs)
		then  _G.geterrorhandler()("LibShort:_HookLibStub()  is incompatible with a custom modification of LibStub.libs. Libraries loaded after this will not be indexed.")
		else  setmetatable(LibStub.libs, self._libsMeta)
		end
	end

	-- For completeness:
	function LibShort:_UnhookLibs()
		if getmetatable(self._libs) ~= self._libsMeta
		then  _G.geterrorhandler()("LibShort:_UnookLibStub():  the metatable of LibStub.libs has been modified, cannot unhook.")
		else  setmetatable(self._libs, nil)
		end
		self._libsMeta = nil
		-- self._libs = nil
	end


	-- Set up.
	LibShort:_HookLibs(LibStub.libs)

end -- LibShort



