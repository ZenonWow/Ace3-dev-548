-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
-- LibStub is hereby placed in the Public Domain
-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
-- @name LibStub.lua
-- @release $Id: LibStub.lua 76 2007-09-03 01:50:17Z mikk $
-- @patch $Id: LibStub.lua 76.1 2019-01 Mongusius, MINOR: 2 -> 2.1
-- 2.1 allows fractional MINOR numbers such as 2.1 to express patches.
-- Enables the use of shortened references in the form:  LibStub.CallbackHandler11, LibStub.AceAddon3, LibStub.AceDB3, LibStub.AceEvent3, LibStub.LibDataBroker11

local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2.1  -- NEVER MAKE THIS AN SVN REVISION! IT NEEDS TO BE USABLE IN ALL REPOS!
local LibStub = _G[LIBSTUB_MAJOR]

-- Check to see is this version of the stub is obsolete
if not LibStub or LibStub.minor < LIBSTUB_MINOR then
	LibStub = LibStub or {libs = {}, minors = {} }
	_G[LIBSTUB_MAJOR] = LibStub
	LibStub.minor = LIBSTUB_MINOR
	
	local function shorten(major)
		-- Cut off ".0", "-1", remove '-','.'
		-- Sidenote: AncientLib-11.0 and AncientLib-1.1 would produce the same conflicting shortened name. No problem, as there are no libraries with such high major.
		return major:gsub("%.0$", ""):gsub("%-1$", ""):gsub("[%-%.]", "")
	end
	if  not LibStub.short  then
		LibStub.short = {}
		for  major, lib  in pairs(LibStub.libs)  do  LibStub.short[shorten(major)] = lib  end
	end
	
	-- LibStub:NewLibrary(major, minor)
	-- major (string) - the name and major version of the library
	-- minor (string or number ) - the minor version of the library
	-- 
	-- returns nil if a newer or same version of the lib is already present
	-- returns empty library object or old library object if upgrade is needed
	function LibStub:NewLibrary(major, minor)
		assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
		if  type(minor) ~= 'number'  then  minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")  end
		
		local oldminor = self.minors[major]
		if oldminor and oldminor >= minor then return nil end
		
		self.minors[major], lib = minor, self.libs[major] or {}
		if  not self.libs[major]  then
			-- first time registering this library (major)
			self.libs[major] = lib
			self.short[shorten(major)] = lib
		end
		return lib, oldminor
	end
	
	-- LibStub:GetLibrary(major, [silent])
	-- major (string) - the major version of the library
	-- silent (boolean) - if true, library is optional, silently return nil if its not found
	--
	-- throws an error if the library can not be found (except silent is set)
	-- returns the library object if found
	function LibStub:GetLibrary(major, silent)
		if  not silent  and  not self.libs[major]  then
			error('Cannot find a library instance of "'..tostring(major)..'".', 2)
		end
		return self.libs[major], self.minors[major]
	end
	
	-- LibStub:IterateLibraries()
	-- 
	-- Returns an iterator for the currently registered libraries
	function LibStub:IterateLibraries() return pairs(self.libs) end
	
	setmetatable(LibStub, { __call = LibStub.GetLibrary, __index = LibStub.short })
end
