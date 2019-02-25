-- GLOBALS: <none>
-- Exported to _G:  LibStub(name, [optional]), LibStub:GetLibrary(name, [optional]), LibStub:RequireLibrary(name, client), LibStub:IterateLibraries() [not used]
-- Used from _G:  error,type,tostring,getmetatable,setmetatable
-- Upvalued: <none>

local GL, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = assert(GL[LIBSTUB_NAME], 'Include "LibStub.lua" before LibStub.GetLibrary.')


-- Check if current version of LibStub.GetLibrary is obsolete.
if (LibStub.minors[LibStub.GetLibrary] or LibStub.minor or 0) < LIBSTUB_REVISION then

	-- If both NewLibrary() and GetLibrary() are at this revision then LibStub.minor can be upgraded.
	if (LibStub.minors[LibStub.NewLibrary] or 0) >= LIBSTUB_REVISION then  LibStub.minor = LIBSTUB_REVISION  end


	------------------------------
	--- LibStub:RequireLibrary(name, client)
	-- @throw an error if the library is not loaded, with an error message including the `client.name`.
	-- @param name (string) - the name and major version of the library.
	-- @param client (table/string) - dependent library/addon object or the name of the client.
	-- @return the library object if found.
	--
	function LibStub:RequireLibrary(name, client)
		local revision = self.minors[name]
		if revision then  return self.libs[name], revision  end

		client = GL.tostring( GL.type(client)=='table' and client.name  or  client )
		GL.error(client..' requires "'..GL.tostring(name)..'" library loaded before.', 2)
	end


	------------------------------
	--- LibStub(name, [optional]): Get a library from the registry.
	--- LibStub:GetLibrary(name, [optional])
	-- @throw an error if the library is not loaded (if not optional).
	-- @param name (string) - the name and major version of the library.
	-- @param optional (boolean) - don't raise error if optional, just silently return nil if its not loaded.
	-- @return the library object if found.
	--
	function LibStub:GetLibrary(name, optional)
		local revision = self.minors[name]
		if revision then  return self.libs[name], revision  end
		if optional then  return nil  end
		GL.error('LibStub:GetLibrary("'..GL.tostring(name)..'"):  library is not loaded at this point.', 2)
	end


	------------------------------
	--- LibStub(name, [optional]): Get a library from the registry.
	-- local metatable = GL.getmetatable(LibStub)
	-- if not metatable then  metatable = {}  ;  setmetatable(LibStub, metatable)  end
	local metatable = LibStub    -- Is its own metatable.
	if GL.getmetatable(LibStub)~=metatable then  GL.setmetatable(LibStub, metatable)  end
	metatable.__call = LibStub.GetLibrary
	-- Protect from setmetatable(), while getmetatable() works as usual.
	metatable.__metatable = metatable


	------------------------------
	--- for  name,lib  in LibStub:IterateLibraries() do
	-- Iterate over the currently registered libraries.
	-- @return an iterator used with `for in`.
	function LibStub:IterateLibraries()  return GL.pairs(self.libs)  end



	-- Upgrade revision of this feature.
	LibStub.minors[LibStub.GetLibrary] = LIBSTUB_REVISION

end -- LibStub

