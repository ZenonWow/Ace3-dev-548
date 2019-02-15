local _G, LIBSTUB_NAME = _G, LIBSTUB_NAME or 'LibStub'
local LibStub, LIB_NAME, LIB_REVISION  =  _G[LIBSTUB_NAME], "LibStub.BeforeDefineLibrary", 1
assert(LibStub, 'Include "LibStub.lua" before LibStub.BeforeDefineLibrary.')
assert(LibStub.minor >= 3, 'Include an updated revision (>=3) of "LibStub.lua" before LibStub.BeforeDefineLibrary.')

local LibPreCreate, oldrevision = LibStub:NewLibrary(LIB_NAME, LIB_REVISION)
if LibPreCreate then

	-----------------------------------------------------------------------------
	--- LibStub:RegisterCallback(receiver)
	-- Adds a recever for the  receiver:BeforeDefineLibrary(lib, name)  event.
	--
	function LibStub:RegisterCallback(receiver)
		assert(receiver.BeforeDefineLibrary, "LibStub:RegisterCallback(receiver):  receiver must have :BeforeDefineLibrary(lib, name) method.")
		if self.callbacks[receiver] then  return false  end
		self.callbacks[#self.callbacks+1], self.callbacks[receiver]  =  receiver,receiver
	end

	LibStub.callbacks = LibStub.callbacks or setmetatable({}, { __mode = 'kv'} )



	-----------------------------------------------------------------------------
	function LibStub:BeforeDefineLibrary(lib, name, revision, oldrevision)
		-- Skip  lib.IsNotLoaded  stubs
		-- if not revision then  return  end

		lib.name     = lib.name or name
		lib.revision = lib.revision or revision

		local meta = getmetatable(lib)
		if not meta then  meta={} ; setmetatable(lib, meta)  end
		-- local meta = _G.LibCommon.initmetatable(lib)
		if type(meta)=='table' then
			meta.__tostring = meta.__tostring  or  LibStub.LibMeta.__tostring
		end
		-- _G.LibCommon.initmetatableField(lib, '__tostring', LibStub.LibMeta.__tostring)

		-- Dispatch to callbacks. Should be safecall, will be, probably.
		for  i,receiver  in ipairs(self.callbacks) do
			receiver:BeforeDefineLibrary(lib, name, revision, oldrevision)
		end
	end 


	-----------------------------------------------------------------------------
	--- tostring(lib):  metatable for pretty print(lib)
	LibStub.LibMeta = LibStub.LibMeta or {}
	-- LibStub.LibMeta.__tostring = function(lib)  return  lib.name  end
	LibStub.LibMeta.__tostring = function(lib)  return  lib.revision  and  tostring(lib.name).." (r"..tostring(lib.revision)..")"  or  tostring(lib.name)  end


	-----------------------------------------------------------------------------
	-- Upgrade libs with .name, .revision fields and metatable.
	--
	-- if (oldrevision or 0) < 1 then
	do
		local self = LibStub
		for name,revision in _G.pairs(self.minors) do  self:BeforeDefineLibrary(self.libs[name], name, self.minors[name], nil)  end
		-- for name,lib in _G.pairs(self.libs) do  if self.minors[name] then self.BeforeDefineLibrary(lib, name) end  end
	end

end  -- LibStub.BeforeDefineLibrary



--[[
	-- Hook MINOR = 3 for callbacks before first loading a library.
	function LibStub._setminor(minors, name, revision)
		-- self.minors[name] = revision  was replaced by this hook.
		-- First do the original task, with rawset() to avoid the hook below for MINOR = 2.
		-- rawset(minors, name, revision)  -- Hook deprecated in favor of overriding LibStub:NewLibrary()
		minors[name] = revision

		-- Store name, revision for pretty `print(lib)`. Not an integral part of _newminor(),
		-- could be a separate BeforeDefineLibrary(), but it's one less function call (callback) this way.
		local lib = LibStub.libs[name]
		if not lib then  return  end
		LibStub:BeforeDefineLibrary(lib, name)
	end

	function LibStub._newlib(libs, name, lib)
		rawset(libs, name, lib)
		-- LibStub is upvalue.
		LibStub:BeforeDefineLibrary(lib, name)
	end

	-- Hook MINOR = 2.  Note: MINOR = 3 calls _newminor() directly, avoiding this hook.
	LibStub.minorsMeta = getmetatable(LibStub.minors) or {}
	setmetatable(LibStub.minors, LibStub.minorsMeta)
	LibStub.minorsMeta.__newindex = LibStub._newminor
	-- Protect from some addon having the same idea to setmetatable(LibStub.minors, ..).  getmetatable() works as before.
	LibStub.minorsMeta.__metatable = LibStub.minorsMeta

	LibStub.libsMeta = getmetatable(LibStub.libs) or {}
	setmetatable(LibStub.libs, LibStub.libsMeta)
	LibStub.libsMeta.__newindex = LibStub._newlib
	-- Protect from some addon having the same idea to setmetatable(LibStub.libs, ..).  getmetatable() works as before.
	LibStub.libsMeta.__metatable = LibStub.libsMeta
--]]

