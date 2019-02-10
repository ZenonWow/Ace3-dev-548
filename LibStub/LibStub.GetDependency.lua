local _G, LIBSTUB_NAME = _G, LIBSTUB_NAME or 'LibStub'
local LibStub, LIB_NAME, LIB_REVISION  =  _G[LIBSTUB_NAME], "LibStub.GetDependency", 1
assert(LibStub, "Include  LibStub  before LibStub.GetDependency.")


local LibGetDep, oldrevision = LibStub:NewLibrary(LIB_NAME, LIB_REVISION)
if LibGetDep then
	-- Upvalued Lua globals:
	local ipairs,unpack = ipairs,unpack


	-----------------------------------------------------------------------------
	--- LibStub:GetDependencies(client, libname, libname*)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library objects, or placeholder stubs for not loaded libraries.
	function LibStub:GetDependencies(client, libname, ...)
		if ... then
			local libs = {}
			for i,name in ipairs({ libname, ... }) do  libs[i] = self:GetDependency(client, name, 2)  end
			return unpack(libs)
		else
			return self:GetDependency(client, libname, 2)
		end
	end


	-----------------------------------------------------------------------------
	--- LibStub:GetDependency(client, libname)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library object, or placeholder stub if not loaded yet.
	function LibStub:GetDependency(client, libname, stackdepth)
		if type(libname)~='string' then  error( "Usage: LibStub:GetDependency(client, libname):  `libname` - expected string, got "..type(libname) , (stackdepth or 1)+1)  end
		local lib, revision  =  self.libs[libname], self.minors[libname]
		if revision then  return lib  end

		if not lib then
			local dependents = { libname = libname }
			lib = _G.setmetatable({ name = libname, LibNotLoaded = true, dependents = dependents} }, self.StubMeta)
			dependents.lib = lib
			self.libs[libname] = lib
			self.dependents[libname] = dependents
		end
		lib.dependents[#lib.dependents+1] = client
		return lib
	end


	-----------------------------------------------------------------------------
	-- On first load:  replace the StubMeta metatable with LibMeta,  clear LibNotLoaded flag
	function LibGetDep:LibStub_PreCreateLibrary(lib, name)
		-- if _G.getmetatable(lib) == self.libMeta then  _G.geterrorhandler()("LibStub:_PreCreateLibrary() called twice: from NewLibrary() and LibStub.minors metatable.")  ;  return  end
		self.loaded[#self.loaded+1] = LibStub.dependents[name]
		LibStub.dependents[name], lib.dependents, lib.LibNotLoaded = nil,nil,nil
		self:RunOnUpdate()
	end


	function LibGetDep:OnUpdate(elapsed)
		-- One library in one OnUpdate
		local dependents, client = self.loaded[1]
		for i = 1,#dependents do
			-- Remove before executing:  if it crashes, OnUpdate will be aborted,
			-- processing will continue in next OnUpdate() with remaining clients.
			client = table.remove(dependents, 1)
			if client.LibStub_OnLibraryLoaded then  client:LibStub_OnLibraryLoaded(dependents.lib, dependents.libname)  end
		end
		table.remove(self.loaded, 1)
		return 0 < #self.loaded
	end


	if false then
		local RunOnUpdate = setmetatable(CreateFrame('Frame'), { __call = function(RunOnUpdate, LibGetDep)  RunOnUpdate.receiver = LibGetDep  ;  RunOnUpdate:Show()  end })
		RunOnUpdate:SetScript('OnUpdate', function(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:OnUpdate(elapsed)  ;  RunOnUpdate:Hide()  end)
		RunOnUpdate:Hide()
		LibGetDep.RunOnUpdate = RunOnUpdate
	else
		LibGetDep.RunOnUpdate = setmetatable(CreateFrame('Frame'), { __call = function(RunOnUpdate, LibGetDep)  RunOnUpdate.receiver = LibGetDep  ;  RunOnUpdate:SetScript('OnUpdate', RunOnUpdate.OnUpdate)  end })
		function LibGetDep.RunOnUpdate.OnUpdate(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:OnUpdate(elapsed)  ;  if not more then RunOnUpdate:SetScript('OnUpdate', nil) end  end
	end


	assert(LibStub.RegisterCallback, "LibStub:GetDependency() requires LibStub MINOR >= 3")
	LibStub:RegisterCallback(LibStub)

	--[[ Patch MINOR = 2 problems: Conflicts with LibStub.Short. If upgraded to MINOR = 3 then calls the callback twice.
		LibStub.minorsMeta = { __newindex = function(minors, libname, newrevision)  rawset(minors, libname, newrevision)  ;  LibStub:LibStub_PreCreateLibrary(LibStub.libs[libname])  end })
		setmetatable(LibStub.minors, LibStub.minorsMeta)
	--]]

	-- setmetatable(LibStub.minors, { __index = function(minors, libname)  return LibStub.stubs[libname] and 0 or -1  end })
	LibGetDep.loaded   = LibGetDep.loaded   or {}
	LibStub.dependents = LibStub.dependents or {}
	LibStub.StubMeta   = LibStub.StubMeta   or {}
	LibStub.StubMeta.__tostring = function(lib)  return  lib.name.." (is not loaded yet)"  end
	LibStub.StubMeta.__index    = function(lib, field)  error(lib.name.." is not loaded yet.", 2)  end
	LibStub.StubMeta.__newindex = function(lib, field, newvalue)  error(lib.name.." is not loaded yet.", 2)  end

end

