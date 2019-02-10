local _G, LIBSTUB_NAME = _G, LIBSTUB_NAME or 'LibStub'
local LibStub, LIB_NAME, LIB_REVISION  =  _G[LIBSTUB_NAME], "LibStub.PreCreateLibrary", 1
assert(LibStub, 'Include "LibStub.lua" before LibStub.PreCreateLibrary.')


local LibPreCreate, oldrevision = LibStub:NewLibrary(LIB_NAME, LIB_REVISION)
if LibPreCreate then

	-----------------------------------------------------------------------------
	--- LibStub:RegisterCallback(receiver)
	-- Adds a recever for the  receiver:LibStub_PreCreateLibrary(lib, name)  event.
	--
	function LibStub:RegisterCallback(receiver)
		assert(receiver.LibStub_PreCreateLibrary, "LibStub:RegisterCallback(receiver):  receiver must have :LibStub_PreCreateLibrary(lib, name) method.")
		if self.callbacks[receiver] then  return false  end
		self.callbacks[#self.callbacks+1], self.callbacks[receiver] receiver,receiver
	end

	LibStub.callbacks = LibStub.callbacks or setmetatable({}, { __mode = 'kv'} )



	-- Library metatable for pretty print(lib).
	LibStub.LibMeta = LibStub.LibMeta or {}
	LibStub.LibMeta.__tostring = function(lib)  return  lib.revision  and  tostring(lib.name).." (r"..tostring(lib.revision)..")"  or  tostring(lib.name)  end


	-- Hook MINOR = 3 for callbacks before first loading a library.
	function LibStub._newminor(minors, name, revision)
		local self = LibStub  -- LibStub is upvalue.
		-- self.minors[name] = revision  was replaced by this hook.
		-- First do the original task, with rawset() to avoid the hook below for MINOR = 2.
		rawset(minors, name, revision)

		-- Store name, revision for pretty `print(lib)`. Not an integral part of _newminor(),
		-- could be a separate LibStub_PreCreateLibrary(), but it's one less function call (callback) this way.
		local lib = self.libs[name]
		lib.name, lib.revision  =  lib.name or name, lib.revision or revision
		setmetatable(lib, self.LibMeta)

		-- Dispatch to callbacks. Should be safecall, will be, probably.
		for  i,receiver  in ipairs(self.callbacks) do
			receiver:LibStub_PreCreateLibrary(lib, name)
		end
	end 

	-- Hook MINOR = 2.  Note: MINOR = 3 calls _newminor() directly, avoiding this hook.
	LibStub.minorsMeta = getmetatable(LibStub.minors) or {}
	setmetatable(LibStub.minors, LibStub.minorsMeta)
	LibStub.minorsMeta.__newindex = LibStub._newminor
	-- Protect from some addon having the same idea to setmetatable(LibStub.libs, ..).  getmetatable() works as before.
	LibStub.minorsMeta.__metatable = LibStub.minorsMeta



	-----------------------------------------------------------------------------
	-- Upgrade libs with .name, .revision fields and metatable. (LibStub.MINOR <= 2)
	--
	-- if (oldrevision or 0) < 1 then
	do
		-- Note: _newminor() does an unnecessary (repeated) rawset(minors, name, revision).
		-- Does not matter, this code seldom executes.
		for name,lib in _G.pairs(LibStub.libs) do  LibStub._newminor(name, lib)  end
	end

end  -- LibStub.PreCreateLibrary


