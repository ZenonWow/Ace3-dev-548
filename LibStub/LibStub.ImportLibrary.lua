local GL, LIBSTUB_NAME, LIBSTUB_REVISION = _G, LIBSTUB_NAME or 'LibStub', 3
local LibStub = assert(GL[LIBSTUB_NAME], 'Include "LibStub.lua" before LibStub.GetLibrary.')
if LibStub.minor < 3 then  GL.geterrorhandler()( 'Include an updated revision (>=3) of "LibStub.lua" before LibStub.BeforeNewLibrary. ')  end


-- Check if current version of LibStub.ImportLibrary is obsolete.
if (LibStub.minors[LibStub.ImportLibrary] or 0) < LIBSTUB_REVISION then

	function LibStub:ImportLibrary(name, revision, lib, noversioncheck)
		if not lib then  return  end
		revision = LibStub.torevision(revision)
		if not revision then
			GL.errorhandler()( "Usage: LibStub:ImportLibrary(name, revision, lib):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )
			revision = 0
		end
		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision and not noversioncheck then  return nil  end

		self.libs[name], self.minors[name] = lib, revision
		-- self.libs[name] = lib
		-- Optimized path to skip  __newindex()  call in  self.minors'  metatable.
		-- The minimal LibStub.NewLibrary.lua does not have _newminor(), neither this optimization.
		-- if not oldrevision then  self._newminor(self.minors, name, revision)  end
		return lib, oldrevision
	end

end


