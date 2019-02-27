local GL, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = assert(GL[LIBSTUB_NAME], 'Include "LibStub.lua" before LibStub.AfterNewLibrary.')
if LibStub.minor < 3 then  GL.geterrorhandler()( 'Include an updated revision (>=3) of "LibStub.lua" before LibStub.AfterNewLibrary.')  end

local LIB_NAME, LIB_REVISION  =  "LibStub.AfterNewLibrary", LIBSTUB_REVISION

-- local LibAfter, oldrevision = LibStub:NewLibrary(LIB_NAME, LIB_REVISION, true)
-- local LibAfter, oldrevision = LibStub:DefineLibrary(LIB_NAME, LIB_REVISION)
local LibAfter, oldrevision = LibStub:BeginLibrary(LIB_NAME, LIB_REVISION)

if LibAfter then
	LibStub.LibAfter = LibAfter

	-- Upvalued Lua globals:
	local pairs,ipairs,unpack = pairs,ipairs,unpack

	
	-----------------------------------------------------------------------------
	--- LibStub:GetDependencies(client, libname, libname*)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library objects, or placeholder stubs for not loaded libraries.
	--
	function LibStub:GetDependencies(client, lib1, ...)
		if ... then
			local libs = {}
			for i,libname in ipairs({ lib1, ... }) do  libs[i] = self:GetDependency(client, libname, 2)  end
			return unpack(libs)
		else
			return self:GetDependency(client, lib1, 2)
		end
	end


	-----------------------------------------------------------------------------
	--- LibStub:GetDependency(client, libname)
	-- @param client (library/addon object) - dependent library/addon, not just the name.
	-- @param libname (string) - the name and major version of required library.
	-- @return the library object, or placeholder stub if not loaded yet.
	--
	function LibStub:GetDependency(client, libname, stackdepth)
		if type(libname)~='string' then  error( "Usage: LibStub:GetDependency(client, libname):  `libname` - expected string, got "..type(libname) , (stackdepth or 1)+1)  end
		local lib, revision  =  self.libs[libname], self.minors[libname]
		if lib then  return lib  end

		lib = self.stubs[libname]
		local observers = self.libObservers[libname]
		if not lib then
			observers = { libname = libname }
			local StubMeta = self.StubMeta
			local clonedStubMeta = { __tostring = StubMeta.__tostring, __index = StubMeta.__index}
			lib = _G.setmetatable({ name = libname, IsNotLoaded = true, _observers = observers}, clonedStubMeta)
			observers.lib = lib
			self.stubs[libname] = lib
			self.libObservers[libname] = observers
		end
		observers[#observers+1] = client
		return lib
	end


	-----------------------------------------------------------------------------
	-- Before updating a library:  add observers to the notifyList.
	--
	function LibAfter:BeforeNewLibrary(lib, libname)
		-- Cleanup stub properties/fields.
		local observers = LibStub.libObservers[libname]

		if LibStub.stubs[libname] then
			-- First definition of this lib.
			if lib.IsNotLoaded == true then  lib.IsNotLoaded = nil  end
			LibStub.stubs[libname] = nil
			-- if lib._observers == observers then  lib._observers = nil  end
		else
			-- Notify only after first NewLibrary():
			-- return
		end

		-- Notify observers after every NewLibrary() update to the lib.
		self.notifyList[#self.notifyList+1] = observers
		-- The lib will load after this, therefore notify observers on the next OnUpdate(), after it loaded.
		-- The initial addon load sequence of wow will load all addons before an OnUpdate is fired, so
		-- this will notify everybody in one big batch.
		-- TODO: use ADDON_LOADED instead, with fallback to OnUpdate for libraries loaded dynamically with loadstring().
		self:RunOnUpdate()
	end


	function LibAfter:NotifyDependents(elapsed)
		-- One library in one OnUpdate. This will change for ADDON_LOADED.
		local observers, client = self.notifyList[1]
		if not observers then  return  end
		for i = 1,#observers do
			-- Remove before executing:  if it crashes, OnUpdate will be aborted,
			-- processing will continue in next OnUpdate() with remaining clients.
			client = table.remove(observers, 1)
			if client.LibStub_OnLibraryLoaded then  client:LibStub_OnLibraryLoaded(observers.lib, observers.libname)  end
		end
		table.remove(self.notifyList, 1)
		return 0 < #self.notifyList
	end


	if false then
		local RunOnUpdate = CreateFrame('Frame')
		getmetatable(RunOnUpdate).__call = function(RunOnUpdate, LibAfter)  RunOnUpdate.receiver = LibAfter  ;  RunOnUpdate:Show()  end
		RunOnUpdate:SetScript('OnUpdate', function(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:NotifyDependents(elapsed)  ;  RunOnUpdate:Hide()  end)
		RunOnUpdate:Hide()
		LibAfter.RunOnUpdate = RunOnUpdate
	else
		LibAfter.RunOnUpdate = CreateFrame('Frame')
		getmetatable(LibAfter.RunOnUpdate).__call = function(RunOnUpdate, LibAfter)  RunOnUpdate.receiver = LibAfter  ;  RunOnUpdate:SetScript('OnUpdate', RunOnUpdate.OnUpdate)  end
		function LibAfter.RunOnUpdate.OnUpdate(RunOnUpdate, elapsed)  local more = RunOnUpdate.receiver:OnUpdate(elapsed)  ;  if not more then RunOnUpdate:SetScript('OnUpdate', nil) end  end
	end


	LibAfter.notifyList    = LibAfter.notifyList or {}
	LibAfter.libObservers  = LibAfter.libObservers or {}
	LibAfter.StubMeta      = LibAfter.StubMeta or {}
	LibAfter.StubMeta.__tostring = function(lib)  return  _G.tostring(lib.name or "Library").." (is not loaded yet)"  end
	LibAfter.StubMeta.__index    = function(lib, field)  error( _G.tostring(lib.name or "Library").." is not loaded yet.", 2)  end
	-- LibAfter.StubMeta.__newindex = function(lib, field, newvalue)  error(lib.name.." is not loaded yet.", 2)  end



	assert(LibStub.AddListener, 'LibStub.GetDependency requires "LibStub.BeforeNewLibrary" loaded before.')
	LibStub:AddListener(LibAfter)

	-- Notify LibStub of successful load.
	LibStub:EndLibrary(LibAfter)

end


