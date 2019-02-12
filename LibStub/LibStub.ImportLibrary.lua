local _G, LibStub, LIB_NAME, LIB_REVISION  =  _G, LibStub, "LibStub.ImportLibrary", 1
assert(LibStub, 'Include "LibStub.lua" before LibStub.ImportLibrary.')
LibStub.libs[LIB_NAME] = LibStub.libs[LIB_NAME] or LibStub

--[[
local oldrevision  =  LibStub.minors[LIB_NAME] or 0
if oldrevision < LIB_REVISION then
--]]

-- if LibStub:NewLibrary(LIB_NAME, LIB_REVISION) then
do
	function LibStub:ImportLibrary(name, revision, lib, noversioncheck)
		if not lib then  return  end
		revision = LibStub.torevision(revision)
		if not revision then
			_G.errorhandler()( "Usage: LibStub:ImportLibrary(name, revision, lib):  `revision` - expected a number or a string containing a number, got '"..tostring(revision).."'." , (stackdepth or 1)+1 )
			revision = 0
		end
		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision and not noversioncheck then  return nil  end

		self.libs[name], self.minors[name] = lib, revision
		-- self.libs[name] = lib
		-- Optimized path to skip  __newindex()  call in  self.minors'  metatable.
		-- The minimal LibStub.NewLibrary.lua does not have _newminor(), neither this optimization.
		-- if not oldrevision then  self._newminor(self.minors, name, revision)  end
		return lib, oldrevision or 0
	end

end


