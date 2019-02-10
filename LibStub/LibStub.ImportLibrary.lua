local _G, LibStub, LIB_NAME, LIB_REVISION  =  _G, LibStub, "LibStub.ImportLibrary", 1
assert(LibStub, 'Include "LibStub.lua" before LibStub.ImportLibrary.')
LibStub.libs[LIB_NAME] = LibStub.libs[LIB_NAME] or LibStub

--[[
local oldrevision  =  LibStub.minors[LIB_NAME] or 0
if oldrevision < LIB_REVISION then
--]]

if LibStub:NewLibrary(LIB_NAME, LIB_REVISION) then

	function LibStub:ImportLibrary(name, revision, lib, noversioncheck)
		if not lib then  return  end
		local oldrevision = self.minors[name]
		if oldrevision and oldrevision >= revision and not noversioncheck then  return nil  end

		self.libs[name], self.minors[name] = lib, revision
		if not oldrevision then  self:_PreCreateLibrary(lib)  end
		return lib, oldrevision or 0
	end

end


