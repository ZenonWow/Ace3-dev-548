-- 5 added separate metatables for each dataobject to skip a function call and 2 lookups in attribute reads.

local MAJOR, MINOR = "LibDataBroker-1.1", 6
assert(LibStub, "LibDataBroker-1.1 requires LibStub")
LibStub("CallbackHandler-1.0", nil, MAJOR)

local LibDataBroker, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibDataBroker then  return  end
oldminor = oldminor or 0
-- Dataobjects registered by version MINOR = 1 cannot be upgraded: there is no programmatic way to access the local variable `domt` to update or unprotect the metatable.

local use_domt
-- Regression test:  uncomment line to revert to one metatable for all dataobjects (MINOR = 4).
use_domt = LibDataBroker.domt


-- Lua APIs
local _G, pairs, ipairs, wipe = _G, pairs, ipairs, wipe
local assert, type, getmetatable, setmetatable = assert, type, getmetatable, setmetatable
local pcall, print, tostring = pcall, print, tostring
local format = string.format


-------------------------
--- Shared functions. ---
-------------------------

-- Export to LibShared:  softassert,softassertf,assertf,asserttype,initmetatable
local LibShared = _G.LibShared or {}  ;  _G.LibShared = LibShared

--- LibShared. softassert(condition, message):  Report error, then continue execution, _unlike_ assert().
LibShared.softassert = LibShared.softassert  or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end

--- LibShared. softassertf( condition, messageFormat, formatParameter...):  Report error, then continue execution, _unlike_ assert(). Formatted error message.
LibShared.softassertf = LibShared.softassertf  or  function(ok, messageFormat, ...)
	if ok then  return ok,nil  end  ;  local message = format(messageFormat, ...)  ;  _G.geterrorhandler()(message)  ;  return ok,message
end

--- LibShared. asserttype(value, typename, [messagePrefix]):  Raises error (stops execution) if value's type is not the expected `typename`.
LibShared.asserttype = LibShared.asserttype  or  function(value, typename, messagePrefix)
	if type(value)~=typename then  error( (messagePrefix or "")..typename.." expected, got "..type(value) )  end
end

--- LibShared. assertf(condition, messageFormat, formatParameter...):  Raises error (stops execution) if condition fails. Formatted error message.
LibShared.assertf = LibShared.assertf  or  function(ok, messageFormat, ...)  if not ok then  error( format(messageFormat, ...) )  end  end

-------------------------------------------------
--- LibShared. initmetatable(obj):  Make sure obj has a metatable and return it.
LibShared.initmetatable = LibShared.initmetatable or function(obj, default)
	local meta = getmetatable(obj)
	if meta == nil then
		meta = default or {}
		setmetatable(obj, meta)
	elseif type(meta)~='table' then
		meta = nil
	end
	return meta, obj
end

local softassert,softassertf,asserttype,assertf,initmetatable = LibShared.softassert,LibShared.softassertf,LibShared.asserttype,LibShared.assertf,LibShared.initmetatable



-------------------------------------------------
--- newproxy(withMeta) is and undocumented Lua 5.1 function (removed in 5.2 ;-)
-- used by FrameXML/RestrictedInfrastructure.lua and SecureHandlers.lua
-- @return  an empty userdata.  It cannot have fields. Good for a proxy, it uses less memory than a real table.
-- @param  withMeta  with a metatable.. to make a proxy using __index and __newindex.
--
-- https://scriptinghelpers.org/questions/48561/why-should-you-use-newproxytrue-over-setmetatable-mt#48825
-- Benefit:  Userdata also can't have any metamethod invocations bypassed through use of the rawset and rawget functions. Raises error.
-- In Lua 5.1 the __len metamethod only works on userdata, not tables.
-- If newproxy() is not available (Lua 5.2), an empty table will do just as good in most cases.
--
--- Fallback for Lua 5.2:
-- @return table instead of userdata. `Minor` implementation detail.
-- local newproxy = newproxy  or function(withMeta)  return  withMeta  and  setmetatable({},{})  or  {}  end
-- local newproxy = newproxy  or function(withMeta)  return  withMeta  and  setmetatable({},{})  or  function() end  end
-- @param withMeta is always true in this library.
--local
newproxy = _G.newproxy  or  function()  return setmetatable({}, {})  end




-----------------------------------------------
--- LibDataBroker:NewDataObject(name, inputFields):  Create or add a new dataobject to the registry.
--
-- Create an empty proxy (type='userdata', not 'table') that triggers LibDataBroker_AttributeChanged callbacks whenever an attribute/field is changed in it.
-- @return  (new) dataobj,  or the old one if already registered by this name.
--
-- Do not use rawset(dataobj, key, value) on it. That would disable triggers for the `key` field.
-- Since MINOR=6 dataobj is 'userdata' and raises an error for rawget, rawset.
--
function LibDataBroker:NewDataObject(name, inputFields)
	-- if self.proxystorage[name] then  return false  end
	-- Accept repeated registration:  merge fields from provided object  and return the previously registered dataobj (proxy).
	local existing = self.proxystorage[name]
	-- Save name to `dataobj.name` since MINOR = 5. Not guaranteed to remain the same, clients can change it.
	-- local attributes = existing and self.attributestorage[existing]  or  { name = name }
	local attributes = existing and getmetatable(existing).__index  or  { name = name }

	if inputFields then
		asserttype(inputFields, 'table', "Usage: LDB:NewDataObject(name, dataobject): `dataobject` - ")
		-- Move fields from the dataobject to the attributestorage:  merge(attributes, inputFields)
		for k,v in pairs(inputFields) do  attributes[k] = v  end
		wipe(inputFields)
	end

	if existing then
		-- Make inputFields a secondary proxy to the attributes of existing. Most addons will drop and garbagecollect it.
		-- Those that keep, can use it with 100% functionality. There will be two proxies, big deal.
		if inputFields then
			setmetatable(inputFields, getmetatable(existing))
			-- Keep track of inputFields that are still around. Weak-keyed map will automatically forget those garbagecollected.
			self.unreleasedInput[inputFields] = true
			-- MINOR=4 `domt` uses attributestorage.
			if use_domt then  self.attributestorage[inputFields] = attributes  end
		end

		self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, existing)
		-- Returning existing ~= inputFields. Some naughty addons ignore the return and keep using inputFields:
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
	
	-- Until MINOR=4:
	local dataobj = use_domt and setmetatable(inputFields or {}, LibDataBroker.domt)
	-- Since MINOR=5:
	if not use_domt then
		dataobj = newproxy(true)
		meta = self:InitProxyMetaTable(getmetatable(dataobj), attributes, name)

		-- Addons are expected to drop the passed object `inputFields` and leave it for the garbagecollector,
		-- but in case an addon hangs on to `inputFields` instead of the returned `dataobj`,
		-- it will work as expected and trigger listeners.
		if inputFields then
			setmetatable(inputFields, meta)
			-- Keep track of inputFields that are still around. Weak-keyed map will automatically forget those garbagecollected.
			self.unreleasedInput[inputFields] = true
		end
	end

	-- The registry of dataobjects.
	self.proxystorage[name] = dataobj
	-- namestorage and attributestorage are practically not used since MINOR = 5.
	-- Keep attributestorage for `use_domt` and any peeking addon, though have not found any.
	self.attributestorage[dataobj] = attributes
	-- self.namestorage[dataobj] = name

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
-- This method is unused.
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
	if isstring(dataobj) then  dataobj = assertf(self.proxystorage[dataobj], "LDB:pairs():  dataobject '%s' is not registered", dataobj)
	else asserttype(dataobj, 'table', "Usage: LDB:pairs(dataobject):  ")
  end

	local attributes = not use_domt  and  getmetatable(dataobj).__index
		or  assertf(self.attributestorage[dataobj], "LDB:pairs(dataobject):  '%s' is not a registered dataobject.", dataobj)
	return pairs(attributes)
end


-------------------------------------------------
-- Standard `ipairs(dataobj)` does nothing on the empty proxy tables (dataobjects).
-- Use instead:    for i,value in LibDataBroker:ipairs(dataobject) do
-- Since MINOR = 5 it adds __len to metatable. After first call  ipairs(dataobj)  also works.
--
function LibDataBroker:ipairs(dataobj)
	-- Passing name of dataobject is unused feature, can be phased out.
	if isstring(dataobj) then  dataobj = assertf(self.proxystorage[dataobj], "LDB:ipairs():  dataobject '%s' is not registered", dataobj)
	else asserttype(dataobj, 'table', "Usage: LDB:ipairs(dataobject):  ")
	end

	local attributes = not use_domt  and  getmetatable(dataobj).__index
		or  assertf(self.attributestorage[dataobj], "LDB:ipairs(dataobject):  '%s' is not a registered dataobject.", dataobj)
	return ipairs(attributes)
end




--------------------------------------------
--- Initialization and internal methods. ---
--------------------------------------------


local LDB = LibDataBroker
-- Dataobject metatables are protected from external access. `getmetatable(dataobj)()` returns an explanation:
LDB.MetaTableNote = "This is a metatable for LDB dataobjects. Not to be modified: it is necessary to update listeners (broker displays) when dataobjects change."
-- Listener registry.
LDB.callbacks = LDB.callbacks or _G.LibStub("CallbackHandler-1.0"):New(LDB)
-- Dataobject registry.
LDB.proxystorage     = LDB.proxystorage     or {}
LDB.attributestorage = LDB.attributestorage or {}
LDB.namestorage      = LDB.namestorage      or {}
LDB.unreleasedInput  = LDB.unreleasedInput  or {}
-- All are weak maps. When a dataobject is forgotten (released) LibDataBroker also drops it.
-- getmetatable(dataobj).__index  holds a reference to `attributes` (the value) so there's no point in making the values weak.
initmetatable(LDB.proxystorage)    .__mode = 'v'  -- name -> dataobj  weak valued map.
initmetatable(LDB.attributestorage).__mode = 'k'  -- dataobj -> attributes  weak keyed map.
initmetatable(LDB.namestorage)     .__mode = 'k'  -- dataobj -> name  weak keyed map.  Names (values) are strings, not working for weak maps.
initmetatable(LDB.unreleasedInput) .__mode = 'k'  -- inputFields -> true  weak keyed map.



-------------------------------------------------
-- Internal method: create individual metatable for each dataobject (since MINOR = 5)
--
function LDB:InitProxyMetaTable(meta, attributes, name)
	assert(name, "Dataobject needs a name.")
	local LDB = self  -- Make it a local upvalue for __newindex.

	-- Fields are read directly from the backend object in self.attributestorage.
	meta.__index = attributes

	-- Individual  __newindex()  closure for every dataobject upvalues `attributes` and `name`: -2 lookups
	-- for the price of as many closures as dataobjects, that is <100 for 99% of users and <1000 for addon hoarders.
	-- Upvalues:  attributes, name, LDB
	meta.__newindex = function(dataobj, field, newvalue)
		if attributes[field] == newvalue then  return  end
		attributes[field] = newvalue
		local callbacks = LDB.callbacks
		callbacks:Fire("LibDataBroker_AttributeChanged",                    name, field, newvalue, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name,             name, field, newvalue, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..field, name, field, newvalue, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged__"..field,           name, field, newvalue, dataobj)
	end,

	-- For the sake of completeness #dataobj can be introduced to make ipairs(dataobj) work as expected, but until dataobjects are used as arrays, its pointless.
	-- Lua 5.2:  http://lua-users.org/wiki/LuaFiveTwo
	-- All types except string now respect __len metamethod. Previously, __len was not respected for table.
	-- In Wow's Lua 5.1 __len only works on userdata (eg. newproxy()), not tables...
	-- __len = function(dataobj)  return #attributes  end

	-- Protect against setmetatable(dataobj, ...).
	-- getmetatable(dataobj) returns the metatable, so it can be modified, but not replaced.
	-- Until MINOR == 4 a string was returned, so no code tinkers with the metatable.
	meta.__metatable = metatable
	return meta
end




-------------------------------------------------
-- Upgrade registered dataobjects with .name and new metatables.
--
if LDB.domt then

	-- Allow overwriting metatable for dataobjects registered with 2 <= MINOR <= 4
	LDB.domt.__metatable = nil
	local namestorage = LDB.namestorage

	for dataobj,attributes in pairs(LDB.attributestorage) do
		if namestorage then
			-- Name was not set in MINOR = 4. Set it without triggering AttributeChanged event.
			local name = softassert(namestorage[dataobj], "Missing name of dataobj.") or "?"
			attributes.name = attributes.name or name
		end

		if not use_domt then
			local metatable = LDB:InitProxyMetaTable({}, attributes, name)
			-- local metatable = LDB:InitProxyMetaTableMinor4()
			local ok,message = pcall(setmetatable, dataobj, metatable)
			softassertf(ok, "LibDataBroker upgrade:  Failed to unprotect dataobject metatable, cannot upgrade it.  %s\nDataobject name='%s'", message, name)
		end
	end
	
	-- Not used anymore. Dataobjects have individual metatables.
	if not use_domt then
		LDB.domt = nil
  end
end



-------------------------------------------------
-- To use_domt  LDB:pairs(), :ipairs(), :NewDataObject() and Upgrade  had to include alternative code.
--
if use_domt then
	LDB.domt = LDB.domt or {}

	-- Since MINOR = 5  `attributestorage[dataobj]`  is never nil. It exists from :NewDataObject(name, dataobj) until :RemoveDataObject(dataobj).
	LDB.domt.__index = function(dataobj, field)  return LDB.attributestorage[dataobj][field]  end,

	LDB.domt.__newindex = function(dataobj, field, newvalue)
		local attributes = LDB.attributestorage[dataobj]
		if attributes[field] == newvalue then  return  end
		attributes[field] = newvalue

		local name = LDB.namestorage[dataobj] or "?"
		local callbacks = LDB.callbacks
		callbacks:Fire("LibDataBroker_AttributeChanged",                    name, field, newvalue, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name,             name, field, newvalue, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..field, name, field, newvalue, dataobj)
		-- This is the order since MINOR = 1, though `__field` might be preferable before `_name` as it is more generic.
		callbacks:Fire("LibDataBroker_AttributeChanged__"..field,           name, field, newvalue, dataobj)
	end

end


