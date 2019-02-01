-- LibShort.<shortname>  enables the use of short library references in the form:
-- LibShort.LibDataBroker, LibShort.LibSharedMedia, LibShort.AceAddon
-- LibShort.LibDataBroker11, LibShort.LibSharedMedia30, LibShort.AceAddon30, etc.
-- The short reference without version number refers to the highest major version loaded.
-- eg.  LibShort.AceAddon  is  LibShort.AceAddon30, not LibShort.AceAddon20.
-- Different major versions are generally not around. If in doubt, use the reference with version number.
-- Does _not_ raise an error if the library is not found.

local LibShort = LibStub:NewLibrary('LibShort', 1, true)
if LibShort then
	_G.LibShort = LibShort

	local function _InsertCheckConflict(LibShort, libname, lib, short)
		local conflict = LibShort[short]
		if  conflict == lib  then  return  end
		if  conflict  and  libname <= (conflict.libname or "")  then  return  end
		LibShort[short] = lib
	end

	local function _IndexLib(LibShort, libname, lib)
		-- Remove '-','.'
		_InsertCheckConflict(LibShort, libname, lib, libname:gsub("[%-%.]", "") )
		-- Remove version: "-n.n" and remove '-','.'
		_InsertCheckConflict(LibShort, libname, lib, libname:gsub("%-[%.%d]+$", ""):gsub("[%-%.]", "") )
	end


	-- Hook the original LibStub.libs map.
	function LibShort:_HookLibs(libs)
		self._libs = libs

		-- Import the loaded libraries from LibStub.
		for libname,lib in pairs(libs) do
			lib.libname = libname
			_IndexLib(self, libname, lib)
		end

		-- The metatable hook to capture new libraries.
		local rawset = _G.rawset
		self._libsMeta = self._libsMeta or {}
		-- `self` (LibShort) is upvalued, `libs` is _not_, it's a parameter of __newindex()
		self._libsMeta.__newindex = function(libs, libname, lib)
			rawset(libs, libname, lib)
			_IndexLib(self, libname, lib)
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
	LibShort:_HookLibs(libs)

end -- LibShort



