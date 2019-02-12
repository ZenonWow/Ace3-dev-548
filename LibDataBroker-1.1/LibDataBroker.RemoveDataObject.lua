local _G, LibStub, LIB_NAME, LIB_REVISION  =  _G, LibStub, "LibDataBroker.RemoveDataObject", 1
assert(LibStub, 'Include "LibStub.lua" before LibDataBroker.RemoveDataObject.')
if not LibStub:NewLibrary(LIB_NAME, LIB_REVISION) then  return  end
local LibDataBroker = LibStub("LibDataBroker-1.1")


local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon
LibCommon.istable   = LibCommon.istable   or function(value)  return  type(value)=='table'    and value  end
LibCommon.softassert = LibCommon.softassert or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end


-----------------------------------------------------
--- LibDataBroker:RemoveDataObject(dataobject):  Remove a dataobject from the registry.
--
-- Remove `dataobj` from the LibDataBroker registry.
-- The fields retain their values. It's possible to register `dataobj` again with :NewDataObject().
-- The metatable remains and keeps updating observers until the dataobj is released and garbagecollected.
-- Only a few display addons will do so at this stage.
--
function LibDataBroker:RemoveDataObject(dataobj)
	if  type(dataobj) == 'string' then  name,dataobj = dataobj, self.proxystorage[dataobj]
	elseif dataobj then  name =  self.namestorage[dataobj]  or  dataobj.name
	end
	if not dataobj then
		LibCommon.softassert(false, "Warn: LibDataBroker:RemoveDataObject(dataobj):  '"..tostring(dataobj).."' is not a registered dataobject.")
		return false
	end

	local istable = LibCommon.istable
	local meta = getmetatable(dataobj)
	if not istable(meta) then  meta = nil  end

	-- Get backend object. Invariant:  attributes == getmetatable(dataobj).__index
	local attributes =  self.attributestorage[dataobj]  or  meta and istable(meta.__index)
	-- self.attributestorage[dataobj] = nil  -- as a weak-keyed map it will drop dataobj->attribute mapping when dataobj is garbagecollected.
	-- self.namestorage[dataobj] = nil  -- also weak-keyed, auto-drops dataobj
  -- Remove from proxystorage: won't find it by name or LDB:DataObjectIterator().
	self.proxystorage[name] = nil

	if  meta  and  meta.__index == attributes  and  attributes  then
		-- Allow setmetatable() on dataobject if it looks like one from MINOR = 5.
		meta.__metatable = nil
	end
	
	-- Leave the metatable as it is. It will even send events as long as the dataobj reference is around.
	-- And it will be. Many databroker displays keep the first dataobj around, even if a new is registered with the same name.

	self.callbacks:Fire("LibDataBroker_DataObjectRemoved", name, dataobj)
	return dataobj, name
end



