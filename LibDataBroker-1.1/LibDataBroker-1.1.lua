-- 5 added separate metatables for each dataobject to skip a function call and 2 lookups in attribute reads.

local MAJOR, MINOR = "LibDataBroker-1.1", 5
assert(LibStub, "LibDataBroker-1.1 requires LibStub")
LibStub("CallbackHandler-1.0", nil, MAJOR)

local LibDataBroker, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibDataBroker then  return  end
oldminor = oldminor or 0
-- Dataobjects registered by version MINOR = 1 cannot be upgraded: there is no programmatic way to access the local variable `domt` to update or unprotect the metatable.


-- Lua APIs
local _G, pairs, ipairs, wipe = _G, pairs, ipairs, wipe
local assert, type, getmetatable, setmetatable = assert, type, getmetatable, setmetatable
local pcall, print, tostring = pcall, print, tostring
local format = string.format


-- Recurring functions
local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon

LibCommon.softassert = LibCommon.softassert or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end
LibCommon.assertf = LibCommon.assertf or  function(ok, messageFormat, ...)  if not ok then  error( format(messageFormat, ...) )  end  end
LibCommon.asserttype = LibCommon.asserttype  or function(value, typename, messagePrefix)
	if type(value)~=typename then  error( (messagePrefix or "")..typename.." expected, got "..type(value) )  end
end
local softassert,assertf,asserttype = LibCommon.softassert,LibCommon.assertf,LibCommon.asserttype



-----------------------------------------------
--- LibDataBroker:NewDataObject(name, dataobj, [returnExisting]):  Create or add a new dataobject to the registry.
--
-- This will turn `dataobj` into an empty proxy table that triggers LibDataBroker_AttributeChanged callbacks whenever an attribute/field is changed in it.
-- Do not use rawset(dataobj, key, value) on it. That would disable triggers for the `key` field.
-- Returns:  (new) dataobj
--
function LibDataBroker:NewDataObject(name, dataobj)
	-- if self.proxystorage[name] then  return false  end
	-- Accept repeated registration:  merge fields from provided object  and return the previously registered dataobj (proxy).
	local existing = self.proxystorage[name]
	-- Save name to `dataobj.name` since MINOR = 5. Not guaranteed to remain the same, clients can change it.
	-- local attributes = existing and self.attributestorage[existing]  or  { name = name }
	local attributes = existing and getmetatable(existing).__index  or  { name = name }

	if dataobj then
		asserttype(dataobj, 'table', "Usage: LDB:NewDataObject(name, dataobject): `dataobject` - ")
		-- Move fields from the dataobject to the attributestorage:  merge(attributes, dataobj)
		for k,v in pairs(dataobj) do  attributes[k] = v  end
		wipe(dataobj)
	end

	if existing then
		-- Make dataobj a secondary proxy to the attributes of existing. Most addons will drop and garbagecollect it.
		-- Those that keep it can use it with 100% functionality. There will be two proxies with these. Big deal.
		if dataobj then  setmetatable(dataobj, self:MakeProxyMetaTable(attributes, name))  end
		self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, existing)
		-- Returning existing ~= dataobj. Some naughty addons ignore the return and keep using dataobj:
		-- AdiBags/modules/DataSource.lua
		-- Bazooka/Bazooka.lua
		-- AddonLoader/Conditions.lua
		-- FasterCamera.lua
		-- Bugger.lua
		return existing
	end

	-- Alternative: do not return, but replace the previous dataobj (self.proxystorage[name]),
	-- this will move the responsibility to display addons to update their dataobj reference
	-- in their buttons (plugin objects) when the Created event fires. Do they do that? 
	--  OK  Bazooka:createPlugin() overwrites it's .dataobj
	--  OK  ButtonBin:  ldbObjects[name] = obj
	--  NO  ChocolateBar:RegisterDataObject()  does not save the new reference
	--  NO  DockingStation/Core.lua#ValidateDataObject()  does not save the new reference
	--  NO  StatBlockCore creates a duplicate button.
	--  NO  MakeRocketGoNow creates a duplicate button.
	--  OK  Auctioneer/SlideBar/SlideMain.lua updates its button.
	--  GREAT  Lui infotext explicitly updates the dataobject.
	--  OK  tek Cork updates.  if dataobj.type ~= "cork" then return end  New type. ChocolateBar would complain.
	--  NO  tek Quickie  duplicates.
	
	-- dataobj = setmetatable(dataobj or {}, self.domt)  -- Until MINOR = 4
	-- dataobj = setmetatable(dataobj or {}, self:MakeProxyMetaTableMinor4(attributes, name))
	dataobj = setmetatable(dataobj or {}, self:MakeProxyMetaTable(attributes, name))
	-- attributestorage and namestorage are practically not used since MINOR = 5.
	self.attributestorage[dataobj] = attributes
	self.proxystorage[name], self.namestorage[dataobj] = dataobj, name
	self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, dataobj)
	return dataobj
end


-----------------------------------------
--- Querying the DataBroker registry. ---
-----------------------------------------

-------------------------------------------------
--- for name,dataobj in LibDataBroker:DataObjectIterator() do
-- Iterates all registered dataobjects.
--
function LibDataBroker:DataObjectIterator()
	return pairs(self.proxystorage)
end

-------------------------------------------------
--- LibDataBroker:GetDataObjectByName(dataobjectname)
-- Returns the dataobject registered with this name.
--
function LibDataBroker:GetDataObjectByName(dataobjectname)
	return self.proxystorage[dataobjectname]
end

-------------------------------------------------
--- LibDataBroker:GetNameByDataObject(dataobject)
-- Returns the name of the dataobject at registration.
-- Not used in the few hundred addons I use... Maybe not used at all. Time to deprecate?
--
function LibDataBroker:GetNameByDataObject(dataobject)
	return dataobject.name
	-- return self.namestorage[dataobject]
end



-----------------------------------------
--- Iterating over dataobject fields. ---
-----------------------------------------


-------------------------------------------------
-- Standard `pairs(dataobj)` does nothing on the empty proxy tables (dataobjects).
-- Use instead:    for key,value in LibDataBroker:pairs(dataobject) do
--
function LibDataBroker:pairs(dataobj)
	-- Passing name of dataobject is unused feature, can be phased out.
	if isstring(dataobj) then  dataobj = assertf(self.proxystorage[dataobj], "LDB:pairs():  dataobject '%s' not found", dataobj)
	elseif not istable(dataobj) then  error("Usage: LDB:pairs(dataobject):  table expected, got "..type(dataobj) )
  end

	-- local attributes = assertf(self.attributestorage[dataobj], "LDB:pairs(dataobject):  '%s' is not a registered dataobject.", dataobj)
	local attributes = getmetatable(dataobj).__index
	return pairs(attributes)
end


-------------------------------------------------
-- Standard `ipairs(dataobj)` does nothing on the empty proxy tables (dataobjects).
-- Use instead:    for i,value in LibDataBroker:ipairs(dataobject) do
-- Since MINOR = 5 it adds __len to metatable. After first call  ipairs(dataobj)  also works.
--
function LibDataBroker:ipairs(dataobj)
	-- Passing name of dataobject is unused feature, can be phased out.
	if isstring(dataobj) then  dataobj = assertf(self.proxystorage[dataobj], "LDB:ipairs():  dataobject '%s' is not a registered", dataobj)
	else asserttype(dataobj, 'table', "Usage: LDB:ipairs(dataobject):  ")
	end

	-- local attributes = assertf(self.attributestorage[dataobj], "LDB:ipairs(dataobject):  '%s' is not a registered dataobject.", dataobj)
	local meta = getmetatable(dataobj)
	local attributes = meta.__index
	-- return ipairs(attributes)
	meta.__len = meta.__len or function(dataobj)  return #attributes  end
	return ipairs(attributes)
end




--------------------------------------------
--- Initialization and internal methods. ---
--------------------------------------------

local initmetatable = LibCommon.Require.initmetatable
local LDB = LibDataBroker
-- Dataobject metatables are protected from external access. `getmetatable(dataobj)()` returns an explanation:
LDB.MetaTableNote = "This is a metatable for LDB dataobjects. Not to be modified: it is necessary to update listeners (broker displays) when dataobjects change."
-- Listener registry.
LDB.callbacks = LDB.callbacks or _G.LibStub("CallbackHandler-1.0"):New(LDB)
-- Dataobject registry.
LDB.attributestorage, LDB.namestorage, LDB.proxystorage = LDB.attributestorage or {}, LDB.namestorage or {}, LDB.proxystorage or {}
-- All weak maps. When a dataobject is forgotten (released) LibDataBroker also drops it.
-- getmetatable(dataobj).__index  holds a reference to `attributes` (the value) so there's no point in making the values weak.
initmetatable(LDB.attributestorage).mode = 'k'  -- dataobj -> attributes  weak keyed map.
initmetatable(LDB.namestorage)     .mode = 'k'  -- dataobj -> name  weak keyed map.  Names (values) are strings, not working for weak maps.
initmetatable(LDB.proxystorage)    .mode = 'v'  -- name -> dataobj  weak valued map.
-- initmetatable(  LDB.namestorage   ).mode = 'k'  -- dataobj -> name  weak keyed map.  Names (values) are strings, not working for weak maps.
-- initmetatable(  LDB.proxystorage  ).mode = 'v'  -- name -> dataobj  weak valued map.



-- Internal method: create individual metatable for each dataobject (since MINOR = 5)
function LDB:MakeProxyMetaTable(attributes, name)
	assert(name, "Dataobject needs a name.")
	local LDB = self  -- Make it a local upvalue for __newindex.
	local metatable = {
		-- Fields are read directly from the backend object in self.attributestorage.
		__index = attributes,

		-- Individual  __newindex()  closure for every dataobject upvalues `attributes` and `name`: -2 lookups
		-- for the price of as many closures as dataobjects, that is <100 for 99% of users and <1000 for addon hoarders.
		-- Upvalues:  attributes, name, LDB
		__newindex = function(dataobj, field, newvalue)
			if attributes[field] == newvalue then  return  end
			attributes[field] = newvalue
			local callbacks = LDB.callbacks
			callbacks:Fire("LibDataBroker_AttributeChanged",                    name, field, newvalue, dataobj)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name,             name, field, newvalue, dataobj)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..field, name, field, newvalue, dataobj)
			callbacks:Fire("LibDataBroker_AttributeChanged__"..field,           name, field, newvalue, dataobj)
		end,

		-- For the sake of completeness #dataobj can be introduced to make ipairs(dataobj) work as expected, but until dataobjects are used as arrays, its pointless.
		-- __len = function(dataobj)  return #attributes  end
	}

	-- Protect against setmetatable(dataobj, ...).
	-- getmetatable(dataobj) returns the metatable, so it can be modified, but not replaced.
	-- Until MINOR == 4 a string was returned, so no code tinkers with the metatable.
	-- For this the closure upvalues `lib` and `metatable`. 
	metatable.__metatable = metatable
	return metatable
end




-- Upgrade registered dataobjects with new metatables.
-- if oldminor <= 4 and LDB.domt then
if LDB.domt then
	-- Allow overwriting metatable for dataobjects registered with 2 <= MINOR <= 4
	LDB.domt.__metatable = nil
	local namestorage = LDB.namestorage

	for dataobj,attributes in pairs(LDB.attributestorage) do
		local name = softassert(namestorage[dataobj], "Missing name of dataobj.") or "?"
		-- Set name without triggering AttributeChanged event. MINOR = 4 did not set it.
		attributes.name = attributes.name or name
		local metatable = LDB:MakeProxyMetaTable(attributes, name)
		local ok, message = pcall(setmetatable, dataobj, metatable)
		if not ok then  _G.geterrorhandler()( "LibDataBroker upgrade:  Failed to unprotect dataobject metatable, cannot upgrade it.  " .. message .. "\nDataobject name='"..name.."' ")  end
	end
	
	-- Not used anymore. Dataobjects have individual metatables.
	LDB.domt = nil
end




-- Regression test: revert to one metatable for all dataobjects (MINOR = 4).
function LDB:MakeProxyMetaTableMinor4()
	local LDB = self  -- Make it a local upvalue.
	-- Non-Lua:  return self.domt or= { .. }
	self.domt = self.domt or {
	-- Since MINOR = 5  `attributestorage[dataobj]`  is never nil. It exists from :NewDataObject(name, dataobj) until :RemoveDataObject(dataobj).
		__index = function(dataobj, field)  return LDB.attributestorage[dataobj][field]  end,

		__newindex = function(dataobj, field, newvalue)
			local attributes = LDB.attributestorage[dataobj]
			if attributes[field] == newvalue then  return  end
			attributes[field] = newvalue

			local name = LDB.namestorage[dataobj] or "?"
			local callbacks = LDB.callbacks
			callbacks:Fire("LibDataBroker_AttributeChanged",                    name, field, newvalue, dataobj)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name,             name, field, newvalue, dataobj)
			callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..field, name, field, newvalue, dataobj)
			-- This is the order since MINOR = 1, tho "__key" might be preferable before "_name" as it is more generic.
			callbacks:Fire("LibDataBroker_AttributeChanged__"..field,           name, field, newvalue, dataobj)
		end,
	}
	return self.domt
end


