local G, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = assert(G[LIBSTUB_NAME], 'Include "LibStub.lua" before LibStub.AfterNewLibrary.')
if LibStub.minor < 3 then  G.geterrorhandler()( 'Include an updated revision (>=3) of "LibStub.lua" before LibStub.AfterNewLibrary.')  end

local LIB_NAME, LIB_REVISION  =  "LibStub.LibMeta", LIBSTUB_REVISION

-- local LibMeta, oldrevision = LibStub:NewLibrary(LIB_NAME, LIB_REVISION, true)
-- local LibMeta, oldrevision = LibStub:DefineLibrary(LIB_NAME, LIB_REVISION)
local LibMeta, oldrevision = LibStub:BeginLibrary(LIB_NAME, LIB_REVISION)

if LibMeta then
	LibStub.LibMeta = LibMeta

	-- Upvalued Lua globals:
	local getmetatable,setmetatable,type,tostring = getmetatable,setmetatable,type,tostring


	------------------------------
	--- LibMeta:BeforeNewLibrary(lib, name, revision, oldrevision):
  -- Add .name, .revision fields, metatable and pretty print() to the library.
	--
	function LibMeta:BeforeNewLibrary(lib, name, revision, oldrevision)
		-- meta.__tostring(lib)  uses the `.name` and `.revision` fields.
		lib.name     = lib.name     or name
		-- Both lib.revision==nil and oldrevision==nil for first-time loaded libraries.
		if lib.revision == oldrevision then  lib.revision = revision  end

		local meta = getmetatable(lib)
		if nil==meta then  meta={} ; setmetatable(lib, meta)  end
		if  type(meta)=='table'  and  meta.__tostring==nil  then  meta.__tostring = self.libtostring  end
	end 


	------------------------------
	--- tostring(lib):  Print "<LibName> (r<Revision>)" instead of default "Table: 0x12345678", using metatable.__tostring().
	--
	local oldtostring = LibMeta.libtostring
	function LibMeta.libtostring(lib)
		if lib.revision then  return  tostring(lib.name).." (r"..tostring(lib.revision)..")"
		elseif lib.IsNotLoaded then  return  tostring(lib.name).." (is not loaded yet)"    -- Support LibStub.AfterNewLibrary
		elseif lib.name then  return  tostring(lib.name)
		else  return  "Some library with `lib.name` deleted."
		end
	end


	------------------------------
	-- Init / upgrade all libraries.
	--
	if not oldrevision then
		-- First load:  add .name, .revision fields and metatable to libraries.
		for name,lib in G.pairs(LibStub.libs) do  LibMeta:BeforeNewLibrary(lib, name, LibStub.minors[name])  end
	else
		for name,lib in G.pairs(LibStub.libs) do
			local meta = getmetatable(lib)
			if  type(meta)=='table'  and  meta.__tostring == oldtostring  then  meta.__tostring = libtostring  end
		end
	end
	
	

	------------------------------
	-- Register last. If it raises error, everything else is done.
	-- if LibStub.AddListener then  LibStub:AddListener(LibMeta)  end
	assert(LibStub.AddListener, 'LibStub.LibMeta requires "LibStub.BeforeNewLibrary" loaded before.')
	LibStub:AddListener(LibAfter)

	-- Notify LibStub of successful load.
	LibStub:EndLibrary(LibMeta)

end -- LibStub.LibMeta


