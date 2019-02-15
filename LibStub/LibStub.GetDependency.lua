local _G, LIBSTUB_NAME = _G, LIBSTUB_NAME or 'LibStub'
local LibStub, LIB_NAME, LIB_REVISION  =  _G[LIBSTUB_NAME], "LibStub.GetDependency", 1
assert(LibStub, 'Include "LibStub.lua" before LibStub.GetDependency.')


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
		if lib then  return lib  end

		lib = self.stubs[libname]
		if not lib then
			local dependents = { libname = libname }
			lib = _G.setmetatable({ name = libname, IsNotLoaded = true, dependents = dependents}, self.StubMeta)
			dependents.lib = lib
			-- Avoid PreCreateLibrary's __newindex hook on LibStub.libs
			self.stubs[libname] = lib
			self.dependents[libname] = dependents
		end
		lib.dependents[#lib.dependents+1] = client
		return lib
	end


	-----------------------------------------------------------------------------
	-- On first load:  replace the StubMeta metatable with LibMeta,  clear IsNotLoaded flag
	function LibGetDep:BeforeDefineLibrary(lib, name)
		-- if _G.getmetatable(lib) == self.libMeta then  _G.geterrorhandler()("LibStub:_PreCreateLibrary() called twice: from NewLibrary() and LibStub.minors metatable.")  ;  return  end
		LibStub.stubs[libname] = nil
		self.loaded[#self.loaded+1] = LibStub.dependents[name]
		LibStub.dependents[name], lib.dependents, lib.IsNotLoaded = nil,nil,nil
		self:RunOnUpdate()
	end


	function LibGetDep:OnUpdate(elapsed)
		-- One library in one OnUpdate
		local dependents, client = self.loaded[1]
		if not dependents then  return  end
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
		local RunOnUpdate = CreateFrame('Frame')
		getmetatable(RunOnUpdate).__call = function(RunOnUpdate, LibGetDep)  RunOnUpdate.receiver = LibGetDep  ;  RunOnUpdate:Show()  end
		RunOnUpdate:SetScript('OnUpdate', function(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:OnUpdate(elapsed)  ;  RunOnUpdate:Hide()  end)
		RunOnUpdate:Hide()
		LibGetDep.RunOnUpdate = RunOnUpdate
	else
		LibGetDep.RunOnUpdate = CreateFrame('Frame')
		getmetatable(LibGetDep.RunOnUpdate).__call = function(RunOnUpdate, LibGetDep)  RunOnUpdate.receiver = LibGetDep  ;  RunOnUpdate:SetScript('OnUpdate', RunOnUpdate.OnUpdate)  end
		function LibGetDep.RunOnUpdate.OnUpdate(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:OnUpdate(elapsed)  ;  if not more then RunOnUpdate:SetScript('OnUpdate', nil) end  end
	end


	assert(LibStub.RegisterCallback, 'LibStub.GetDependency requires "LibStub.PreCreateLibrary" loaded before.')
	LibStub:RegisterCallback(LibGetDep)

	-- setmetatable(LibStub.minors, { __index = function(minors, libname)  return LibStub.stubs[libname] and 0 or -1  end })
	LibGetDep.loaded   = LibGetDep.loaded   or {}
	LibStub.dependents = LibStub.dependents or {}
	LibStub.StubMeta   = LibStub.StubMeta   or {}
	LibStub.StubMeta.__tostring = function(lib)  return  lib.name.." (is not loaded yet)"  end
	LibStub.StubMeta.__index    = function(lib, field)  error(lib.name.." is not loaded yet.", 2)  end
	LibStub.StubMeta.__newindex = function(lib, field, newvalue)  error(lib.name.." is not loaded yet.", 2)  end

end


