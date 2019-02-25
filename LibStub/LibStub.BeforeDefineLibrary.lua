local GL, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = assert(GL[LIBSTUB_NAME], 'Include "LibStub.lua" before LibStub.BeforeNewLibrary.')
if LibStub.minor < 3 then  GL.geterrorhandler()( 'Include an updated revision (>=3) of "LibStub.lua" before LibStub.BeforeNewLibrary. ')  end


-- Check if current version of LibStub.BeforeNewLibrary is obsolete.
if (LibStub.minors[LibStub.BeforeNewLibrary] or 0) < LIBSTUB_REVISION then

	------------------------------
	--- LibStub:AddListener(obj)
	-- Adds a listener for the  BeforeNewLibrary  event.
	-- @param  obj (table)  must have  obj:BeforeNewLibrary(lib, name)  method.
	-- This will be called when LibStub:NewLibrary() is called, before the library is actually loaded.
	-- Note:  LibStub.AfterNewLibrary() is more suitable for most use-cases, this is internal API.
	-- The extensions using it do not need to unregister. If the need arises, a RemoveListener(obj) method will be implemented.
	--
	function LibStub:AddListener(obj)
		GL.assert(GL.type(obj)=='table', "LibStub:AddListener(obj):  obj - expected table, got "..GL.type(obj))
		GL.assert(GL.type(obj.BeforeNewLibrary)=='function' or GL.type(obj.AfterNewLibrary)=='function', "LibStub:AddListener(obj):  obj must have :BeforeNewLibrary(lib, name) or :AfterNewLibrary(lib, name) method.")
		local listeners = self.listeners
		if listeners[obj] then  return false  end
		listeners[obj] = obj
		listeners[#listeners+1] = obj
	end


	-- List and hashset of listeners. Can be indexed as an array (i->listener) or map (listener->listener)
	LibStub.listeners = LibStub.listeners or {}


	------------------------------
	--- LibStub:BeforeNewLibrary(..):  Callback from LibStub:NewLibrary()
	--
	function LibStub:BeforeNewLibrary(lib, name, revision, oldrevision)
		if GL.DEVMODE and GL.DEVMODE.LibStub then
			-- Print which revision loads from which file.
			GL.print("LibStub:NewLibrary():", name, "  rev:", oldrevision, "->", revision, "  @", GL.debugstack(2,1,0):gsub(": .*", ""):gsub("^Interface\\AddOns\\", ""):gsub("^%.%.[^:]*Ons\\", "") )
		end

		-- Dispatch to listeners. Should be safecall, will be, probably.
		for i,listener in GL.ipairs(self.listeners) do
			if listener.BeforeNewLibrary then  listener:BeforeNewLibrary(lib, name, revision, oldrevision)  end
		end
	end 



	-- Upgrade revision of this feature.
	LibStub.minors[LibStub.BeforeNewLibrary] = LIBSTUB_REVISION

end  -- LibStub.BeforeNewLibrary


