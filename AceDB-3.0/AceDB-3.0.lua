--- **AceDB-3.0** manages the SavedVariables of your addon.
-- It offers profile management, smart defaults and namespaces for modules.\\
-- Data can be saved in different data-types, depending on its intended usage.
-- The most common data-type is the `profile` type, which allows the user to choose
-- the active profile, and manage the profiles of all of his characters.\\
-- The following data types are available:
-- * **char** Character-specific data. Every character has its own database.
-- * **realm** Realm-specific data. All of the players characters on the same realm share this database.
-- * **class** Class-specific data. All of the players characters of the same class share this database.
-- * **race** Race-specific data. All of the players characters of the same race share this database.
-- * **faction** Faction-specific data. All of the players characters of the same faction share this database.
-- * **factionrealm** Faction and realm specific data. All of the players characters on the same realm and of the same faction share this database.
-- * **global** Global Data. All characters on the same account share this database.
-- * **profile** Profile-specific data. All characters using the same profile share this database. The user can control which profile should be used.
--
-- Creating a new Database using the `:New` function will return a new DBObject. A database will inherit all functions
-- of the DBObjectMixin listed here. \\
-- If you create a new namespaced child-database (`:RegisterNamespace`), you'll get a DBObject as well, but note
-- that the child-databases cannot individually change their profile, and are linked to their parents profile - and because of that,
-- the profile related APIs are not available. Only `:RegisterDefaults` and `:ResetProfile` are available on child-databases.
--
-- For more details on how to use AceDB-3.0, see the [[AceDB-3.0 Tutorial]].
--
-- You may also be interested in [[libdualspec-1-0|LibDualSpec-1.0]] to do profile switching automatically when switching specs.
--
-- @usage
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("DBExample")
--
-- -- declare defaults to be used in the DB
-- local defaults = {
--   profile = {
--     setting = true,
--   }
-- }
--
-- function MyAddon:OnInitialize()
--   -- Assuming the .toc says ## SavedVariables: MyAddonDB
--   self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)
-- end
-- @class file
-- @name AceDB-3.0.lua
-- @release $Id: AceDB-3.0.lua 1115 2014-09-21 11:52:35Z kaelten $
-- @patch $Id: AceDB-3.0.lua 1115.1 2019-01 Mongusius, MINOR: 25 -> 25.1

local MAJOR, MINOR = "AceDB-3.0", 25.1
local AceDB, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceDB then return end -- No upgrade needed

-- Lua APIs
local type, pairs, next, error = type, pairs, next, error
local setmetatable, getmetatable, rawset, rawget = setmetatable, getmetatable, rawset, rawget

-- WoW APIs
local _G = _G

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: LibStub

-- AceDB.db_registry = AceDB.db_registry or {}
AceDB.registry = AceDB.registry or {}
AceDB.frame = AceDB.frame or CreateFrame("Frame")

AceDB.Global = AceDB.Global or {}
-- Default profile name if addon did not specify.
AceDB.Global.DefaultProfileKey = nil
-- Select one profile in all addons for a character. Ignored, if no such profile.
AceDB.Global.AutoSelectProfile = nil


-------------------------------------------------
-- Ordered list of profile tokens.  The first existing profile with a token selected key is used as default profile.
-- List can be overridden for a db with a similar list in  `db.ProfilePriority`.
--
AceDB.DefaultProfilePriority = { 'spec','class','dpsrole','role3','Default' }

--[[ Tokens in this list select:
spec     -- Specialization, key='<CLASS>-<specIndex>'  specIndex = 1..4
class    -- '<CLASS>'  --  Uppercase English, one word:  	
dpsrole  -- 'Melee/Ranged'/nil -- Distinguish for role quadrinity.
role3    -- 'Damage/Tank/Healer'  -- For role trinity. Translated to English from `blizrole` returned by GetSpecializationRole(specIndex) which would be 'DAMAGER/TANK/HEALER'.
role     -- 'Melee/Ranged/Tank/Healer' already covered by dpsrole and role3.  Note: same keywords as in LUI_Dynamics addon.
-- Ranged and Magic (https://wow.gamepedia.com/Specialization) are not distinguished in this taxonomy. Only hunter would be Ranged.
Default  -- Profile key 'Default'.
-- For the tokens that can be used, search for:  sectionKeys['  and  tokenKeys['
realm               -- "<Realm Name>"
faction             -- 'Alliance/Horde'  --  English, UnitFactionGroup('player')
factionrealm        -- "<Faction> - <Realm>"
factionrealmregion  -- "<Faction> - <Realm> - <Region>"
locale              -- GetLocale():lower()
race                -- English
gender              -- 'Male/Female'
racegender          -- "<Race>-<Gender>"
-- Custom tokens can be specified in  AceDB.ProfileTokenKeys.
--]]




local DBObjectMixin = {}

local CallbackHandler
local CallbackDummy = { Fire = function() end }
DBObjectMixin.callbacks = CallbackDummy

function DBObjectMixin:RegisterCallback(...)
	CallbackHandler = CallbackHandler or LibStub("CallbackHandler-1.0")

	self.callbacks = CallbackHandler:New(self)
	-- Safety check to avoid infinite recursion by programming error.
	assert(self.RegisterCallback ~= DBObjectMixin.RegisterCallback, "Failed to do CallbackHandler:New()")
	-- Call the real RegisterCallback() created by CallbackHandler.
	self:RegisterCallback(...)
end


--[[-------------------------------------------------------------------------
  Metaprogramming functions
---------------------------------------------------------------------------]]

local LibShared = _G.LibShared or {}  ;  _G.LibShared = LibShared

-------------------------------------------------
--- LibShared. softassert(condition, message):  Report error, then continue execution, _unlike_ assert().
LibShared.softassert = LibShared.softassert  or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end

-------------------------------------------------
--- LibShared. softassertf( condition, messageFormat, formatParameter...):  Report error, then continue execution, _unlike_ assert(). Formatted error message.
LibShared.softassertf = LibShared.softassertf  or  function(ok, messageFormat, ...)
	if ok then  return ok,nil  end  ;  local message = format(messageFormat, ...)  ;  _G.geterrorhandler()(message)  ;  return ok,message
end

-------------------------------------------------
--- LibShared. asserttype(value, typename, [messagePrefix]):  Raises error (stops execution) if value's type is not the expected `typename`.
LibShared.asserttype = LibShared.asserttype  or  function(value, typename, messagePrefix, calldepth)
	if type(value)~=typename then  error( (messagePrefix or "")..typename.." expected, got "..type(value), (calldepth or 1)+1 )  end
end

-----------------------------
--- LibShared. asserttypeOrNil(value, typename, [messagePrefix]):  Raises error (stops execution) if value's type is not the expected `typename` and value is not nil.
LibShared.asserttypeOrNil = LibShared.asserttypeOrNil  or  function(value, typename, messagePrefix, calldepth)
	if nil~=value and type(value)~=typename then  error( (messagePrefix or "")..typename.." expected, got "..type(value), (calldepth or 1)+1 )  end
end

-- Type-check shorthands.  @return value  if its type is as expected,  false otherwise.
LibShared.isstring  = LibShared.isstring  or function(value)  return  type(value)=='string'   and value  end
LibShared.istable   = LibShared.istable   or function(value)  return  type(value)=='table'    and value  end

--- LibShared.istype3(value, t1, t2, t3):  Test if value is one of 3 types.
LibShared.istype3 = LibShared.istype3 or  function(value, t1, t2, t3)
	local t=type(value)  ;  if t==t1 or t==t2 or t==t3 then return value end  ;  return nil
end

local softassert,softassertf,asserttype,isstring,istable,istype3 = LibShared.softassert,LibShared.softassertf,LibShared.asserttype,LibShared.isstring,LibShared.istable,LibShared.istype3

-------------------------------------------------
--- LibShared. AutoTablesMeta:  metatable that auto-creates empty inner tables when first referenced.
-- LibShared.AutoTablesMeta = LibShared.AutoTablesMeta or { __index = function(self, key)  if key ~= nil then  local v={} ; self[key]=v ; return v  end  end }

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


-----------------------------
LibShared.nonext = LibShared.nonext  or  function(t,i)  return nil,nil  end
local nonext = LibShared.nonext
-----------------------------
--- LibShared. pairsOrNil(t):   Iterate `t` if it's a table, like pairs(t), skip otherwise. Won't raise halting error.
-- Report (not raise) error if `t` is unexpected type (true/number/string/function/thread). Continue execution.
--
LibShared.pairsOrNil = LibShared.pairsOrNil  or  function(t)
  if type(t)=='table' then  return next ,t,nil
  elseif t then _G.geterrorhandler()("pairsOrNil(t) expected table or nil, got "..type(t))
	end
  return nonext,t,nil
end

local pairsOrNil = LibShared.pairsOrNil




-------------------------------------------------
-- Simple deep copy for copying profiles.
--
local DeepCopy, DeepCopyRevision = LibShared.DeepCopy, 1
if LibShared.Revisions.DeepCopy < DeepCopyRevision then

	function DeepCopy(dest, src)
		if type(src)~='table' then  return src  end

		if type(dest)~='table' then  dest={}  end
		for field,value in pairs(src) do
			if type(value)=='table' then
				-- Index the dest field first so the metatable copies the defaults, if any, and use the table created in that process.
				value = DeepCopy(dest[field], value)
			end
			dest[field] = value
		end
		return dest
	end
	LibShared.Upgrade.DeepCopy[DeepCopyRevision] = DeepCopy

end



--[[-------------------------------------------------------------------------
	Awesome AceDB defaults propagating, multiplicating metaprogramming magic
---------------------------------------------------------------------------]]


-- Called to add defaults to a section of the database
--
-- When a ["*"] default section is indexed with a new key, a table is returned
-- and set in the host table.  These tables must be cleaned up by AceDB.RemoveDefaults
-- in order to ensure we don't write empty default tables.
local function copyDefaults0(dest, src)
	-- this happens if some value in the SV overwrites our default value with a non-table
	--if type(dest)~='table' then return end
	for field,value in pairs(src) do
		if field == "*" or field == "**" then
			-- If both ['*'] and ['**'] are set then only one is copied to newly created subtables.
			-- It's undefined/random which one will take effect later, overriding the other's metatable.
			if type(value)=='table' then
				-- This is a metatable used for table defaults
				local mt = {
					-- This handles the lookup and creation of new subtables
					__index = function(dest,field)
						if field == nil then return nil end
						local dbTable = {}
						-- `value` is upvalued, == src['*'] or src['**'], depending on the order of iteration.
						AceDB.ApplyDefaults(dbTable, value)
						dest[field] = dbTable
						return dbTable
					end,
				}
				setmetatable(dest, mt)
				-- handle already existing tables in the SV
				for dbField,dbValue in pairs(dest) do
					if not rawget(src, dbField) and type(dbValue)=='table' then
						AceDB.ApplyDefaults(dbValue, value)
					end
				end
			else
				-- ['*'] = non-table defaults all fields to one value.
				local mt = {__index = function(dest,field) return field~=nil and value or nil end}
				setmetatable(dest, mt)
			end
		elseif type(value)=='table' then
			local dbValue = rawget(dest, field)
			-- This overwrites dest[field] == false  with  the table in  src[field].
			-- if not rawget(dest, field) then rawset(dest, field, {}) end
			if dbValue==nil then  dbValue={} ; rawset(dest, field, dbValue)  end
			if type(dbValue)=='table' then
				AceDB.ApplyDefaults(dbValue, value)
				-- src['**'] == non-table crashes AceDB.ApplyDefaults()
				-- if src['**'] then
				if type(src['**']) == 'table' then
					AceDB.ApplyDefaults(dbValue, src['**'])
				end
			end
		else
			if rawget(dest, field) == nil then
				rawset(dest, field, value)
			end
		end
	end
	return dest
end




-- Map  tables in active db  to ['*'] tables in defaults.
local defaultsAsteriskMap = setmetatable({}, { __mode = 'k' })


-- Use one metatable for subtable creation with defaults.
local asteriskMeta1 = {
	__index = function(dest,field)
		if field == nil then return nil end
		local defValue, copy = defaultsAsteriskMap[t]
		copy = AceDB.ApplyDefaults({}, defValue)
		dest[field] = copy
		return copy
	end,
}
local asteriskMeta2 = {
	__index = function(t,field)
		return  field ~= nil  and  defaultsAsteriskMap[t]
	end,
}

local function copyDefaults1(dest, src)
	-- this happens if some value in the SV overwrites our default value with a non-table
	--if type(dest)~='table' then return end
	for field,defValue in pairs(src) do
		if field == "*" or field == "**" then
			-- If both ['*'] and ['**'] are set then only one is copied to newly created subtables.
			-- It's undefined/random which one will take effect later, overriding the other.
			defaultsAsteriskMap[dest] = defValue
			if type(defValue)=='table' then
				-- This is a metatable used for table defaults
				setmetatable(dest, asteriskMeta1)
				-- handle already existing tables in the SV
				for dbField,dbValue in pairs(dest) do
					if not rawget(src, dbField) and type(dbValue)=='table' then
						AceDB.ApplyDefaults(dbValue, defValue)
					end
				end
			else
				-- ['*'] = non-table:  defaults all keys to one value.
				setmetatable(dest, asteriskMeta2)
			end
		elseif type(defValue)=='table' then
			local dbValue = rawget(dest, field)
			-- This overwrites dest[field] == false  with  the table in  src[field].
			-- if not rawget(dest, field) then rawset(dest, field, {}) end
			if dbValue==nil then  dbValue={} ; rawset(dest, field, dbValue)  end
			if type(dbValue)=='table' then
				AceDB.ApplyDefaults(dbValue, defValue)
				-- src['**'] == non-table crashes copyDefaults0()
				-- if src['**'] then
				if type(src['**']) == 'table' then
					AceDB.ApplyDefaults(dbValue, src['**'])
				end
			end
		else
			if rawget(dest, field) == nil then
				rawset(dest, field, defValue)
			end
		end
	end
	return dest
end




-- Experiment:  inherit default values from defaults with metatable inheritence.  
local asteriskMeta = {
	copyDefault = function(meta, dbTable, field, newvalue)
		local defValue = meta.asterisk
		if defValue == nil then  defValue = meta.asterisk2 end
		if type(defValue)=='table' then
			newvalue = AceDB.ApplyDefaults(newvalue, defValue)
			if  meta.asterisk2  and  meta.asterisk2 ~= defValue  then  AceDB.ApplyDefaults(newvalue, meta.asterisk2)  end
		end
		return newvalue, newvalue or defValue
	end,
	__index = function(dbTable, field)
		if field == nil then  return nil  end
		local meta = getmetatable(dbTable)
		local copy, value = meta:copyDefault(dbTable, field, nil)
		-- Basic default values are not copied to dbTable.
		if copy then  rawset(dbTable, field, copy)  end
		return value
	end,
	__newindex = function(dbTable, field, newvalue)
		rawset(dbTable, field, newvalue)
		if type(newvalue)~='table' then  return  end
		local meta = getmetatable(dbTable)
		meta:copyDefault(dbTable, field, newvalue)
	end,
}

-- Map tables in active db  to  tables in defaults tree.
local defaultsMap = setmetatable({}, { __mode = 'k' })

local asteriskLazySubtablesMeta = {
	copyDefault = function(meta, dbTable, field, newvalue)
		local defValue = meta.defaults[field]
		if defValue == nil then  defValue = meta.asterisk end
		if defValue == nil then  defValue = meta.asterisk2 end
		if type(defValue)=='table' then
			newvalue = AceDB.ApplyDefaults(newvalue, defValue)
			if  meta.asterisk2  and  meta.asterisk2 ~= defValue  then  AceDB.ApplyDefaults(newvalue, meta.asterisk2)  end
		end
		return newvalue, newvalue or defValue
	end,
	__index = asteriskMeta.__index,
	__newindex = asteriskMeta.__newindex,
}

local lazySubtablesMeta = {
	-- Without '*' lookup
	copyDefault = function(meta, dbTable, field, newvalue)
		local defValue = meta.defaults[field]
		if type(defValue)=='table' then
			newvalue = AceDB.ApplyDefaults(newvalue, defValue)
		end
		return newvalue, newvalue or defValue
	end,
	__index = asteriskMeta.__index,
	__newindex = asteriskMeta.__newindex,
}



local function replacemetatable(dest, newmeta)
	local oldmeta = getmetatable(dest)
	if  nil ~= oldmeta  and  type(oldmeta)~='table'  then  return false, oldmeta  end
	-- Unprotect replaced oldmeta.
	local wasProtected = oldmeta and oldmeta.__metatable
	if nil ~= wasProtected then
		-- Metatable can be hidden with fake table in __metatable, in which case getmetatable() returns the fake table.
		-- Check if this table was protecting itself, otherwise it's not the real metatable.
		if oldmeta ~= wasProtected then  return false, oldmeta  end
		oldmeta.__metatable = wasProtected
	end
	-- The metatable can still be a fake with  oldmeta.__metatable == oldmeta. This will cause an error in setmetatable().
	pcall(setmetatable, dest, newmeta)
	-- If the caller made such trickery, let's raise an error.
	-- setmetatable(dest, newmeta)
	-- Reenable protection for other users of the old metatable.
	if nil ~= wasProtected then  oldmeta.__metatable = wasProtected  end
	-- if meta then  meta.__metatable = wasProtected  end
	return true, oldmeta
end


local inheritValues, lazySubtables, asteriskLazySubtables = true, true, true

local function copyDefaults2(dest, src)
	-- softassert(not getmetatable(src), "A defaults table has a metatable. Not supposed to.")
	-- softassert(not getmetatable(dest), "A savedvariable table has a metatable. Not supposed to.")
	-- this happens if some value in the SV overwrites our default value with a non-table
	--if type(dest)~='table' then return end
	if dest == nil then  dest={}  end

	local fieldDefaults, defaultDefaults = src['*'], src['**']
	local newFieldDefaults = fieldDefaults or defaultDefaults
	-- Non-table default values (fieldDefaults) do not apply to existing fields.
	local tableDefaults = istable(fieldDefaults)
	asserttypeOrNil(defaultDefaults, 'table', "AceDB:ApplyDefaults(): ['**'] = ")    -- Defaults can have defaults as well...

	-- Inherit contents of ['**'] to every neighbour/sibling, including ['*'] if present.
	-- If not inheritValues then the contents are copied later directly to dbValue.
	if defaultDefaults and inheritValues then    -- ['**']
		for field,defTable in pairs(src) do
			if field~='**' and istable(defTable) then  AceDB.ApplyDefaults(defTable, defaultDefaults)  end
		end
		-- If no ['*'] then ['**'] is inherited by dbTable(s) instead of ['*'].
		if not tableDefaults then  tableDefaults = defaultDefaults   end
		-- If ['*'] exists then it inherited ['**'], so don't apply ['**'] below.
		defaultDefaults = nil
	end

	-- Apply to subtables already created.
	for dbField,dbTable in pairs(dest) do
		if istable(dbTable) then
			-- Apply src[field], if table _or_ src['*'].
			local srcTable =  istable(src[dbField])  or  tableDefaults
			if srcTable then  AceDB.ApplyDefaults(dbTable, srcTable)  end
			-- Apply ['**'], if not inherited by src[field] or src['*'].
			if defaultDefaults then  AceDB.ApplyDefaults(dbTable, defaultDefaults)  end
		end
	end

	-- Tables containing ['*'] (fieldDefaults) are usually iterated with pairs(),
	-- for which all default subtables has to be directly present, not inherited (until Lua 5.2 introduces __ipairs).
	local hasLazySubtable
	local subtablesMeta = lazySubtables  and  not newFieldDefaults  and  lazySubtablesMeta
		or  asteriskLazySubtables and asteriskLazySubtablesMeta
	
	-- Copy fields:  tables in any case,  values only if not inheritValues.
	for field,defValue in pairs(src) do
		if field ~= '*' and field ~= '**' and nil==rawget(dest, field) then
			-- Already applied src[field] or src['*'] and src['**'] to existing dbTable(s).
			if istable(defValue) then
				if subtablesMeta then  hasLazySubtable = true    -- Copy table in lazySubtablesMeta/asteriskLazySubtablesMeta.
				else  rawset(dest, field, AceDB.ApplyDefaults({}, srcValue))    -- Copy table and copy/inherit contents.
				end
			elseif not inheritValues then
				-- Copy basic (primitive) value.
				rawset(dest, field, defValue)
			end
		end
	end

	defaultsMap[dest] = hasLazySubtable and src or nil
	defaultsAsteriskMap[dest] = newFieldDefaults
	local meta

	-- Handle asterisk: default for all fields in dest.
	-- Can't handle both, just like copyDefaults0(), but prioritizes ['*']
	if newFieldDefaults then
		-- The metatable used to auto-create subtables for ['*'] and ['**'].
		meta = AceDB.applyMetatable(dest, src, not hasLazySubtable and asteriskMeta or subtablesMeta)
		meta.asterisk = fieldDefaults
		meta.asterisk2 = defaultDefaults
	elseif hasLazySubtable then
		meta = AceDB.applyMetatable(dest, src, subtablesMeta)
	else
		local srcMeta = getmetatable(src)
		local srcHasContent =  nil~=next(src)  or  srcMeta and srcMeta.__index and true
		meta = AceDB.applyMetatable(dest, src)
		meta.copyDefault = nil
		meta.__newindex = nil
		meta.__index = srcHasContent and src or nil
		-- Without asterisk field it's possible to efficiently inherit values
		-- from the table in the defaults tree (one lookup: metatable->defaults).
		-- This saves memory proportional to the number of entities in the addon.
		-- These can be all the dataobjects, spells, etc. processed,
		-- possibly growing to hundreds or thousands of objects, with measurable savings.
	end
	return dest
end


-- Weak keyed map  defaults -> meta. Allows garbage collection of defaults, tho seldom happens.
local defaultsMetas = setmetatable({}, { __mode = 'k' })

function AceDB.applyMetatable(dest, defaults, metaPrototype)
	-- TODO: Check if ApplyDefaults() is called when the DB already has metatables (defaults applied).
	local meta = getmetatable(dest)
	if not meta then
		-- Mark for identification. 8 fields are preallocated, this takes no extra memory.
		meta = defaultsMetas[defaults]  or  { AceDBmetatable = 'onePerDefaultTable' }
		defaultsMetas[defaults] = meta
		setmetatable(dest, meta)
	elseif not istable(meta) then
		error("AceDB.ApplyDefaults():  table in SavedVariable has incompatible protected metatable, that cannot be overridden.", 2)
	elseif not meta.AceDBmetatable then
		meta = LibShared.merge({}, meta)    -- Copy oldmeta.
		meta.AceDBmetatable = 'uniqueForDBTable'
		local replaced = replacemetatable(dest, meta)
		assert(replaced, "AceDB.ApplyDefaults():  table in SavedVariable has incompatible protected metatable, that cannot be overridden.")
	else
		softassert(meta.defaults == defaults, "AceDB.applyMetatable(): metatable used for different default tables, should be used for one only.")
	end

	-- Protect from setmetatable(dbTable, ..), while allowing  getmetatable(dbTable).
	meta.__metatable = meta
	-- Save the inherited defaults table.
	meta.defaults = defaults
	-- Set __index.
	LibShared.merge(meta, metaPrototype)

	return meta
end


----------------------------
-- Choose implementation.
--
AceDB.ApplyDefaults = copyDefaults0




-- Called to remove all defaults in the default table from the database.
function AceDB.RemoveDefaults(db, defaults, blocker)
	-- if not defaults then  return  end
	-- remove all metatables from the db, so we don't accidentally create new sub-tables through them
	setmetatable(db, nil)

	local fieldDefaults, defaultDefaults = defaults['*'], defaults['**']
	fieldDefaults = fieldDefaults or defaultDefaults

	if fieldDefaults then
		if type(fieldDefaults)=='table' then
			-- Loop through all the actual field,dbValue pairs and remove.
			for field,dbValue in pairs(db) do
				if type(dbValue)=='table' then
					local subTableDef = defaults[field]
					-- If the field was not explicitly specified in the defaults table, just strip everything from * and ** tables.
					if  subTableDef==nil  and  (not blocker or blocker[field]==nil)  then
						AceDB.RemoveDefaults(dbValue, fieldDefaults)
					end
					-- If it was specified, only strip ** content, but block values which were set in the defaults for the subtable.
					if defaultDefaults then    -- if key == "**" then
						AceDB.RemoveDefaults(dbValue, defaultDefaults, subTableDef)
					end
					-- If the table is empty afterwards, remove it.
					if nil==next(dbValue) then
						db[field] = nil
					end
				end
			end
		else  -- if key == "*" then
			-- Check for fields having this non-table default value.
			for field,dbValue in pairs(db) do
				if defaults[field] == nil and dbValue == fieldDefaults then
					db[field] = nil
				end
			end
		end
	end

	-- Loop through the defaults and remove their content.
	for field,defValue in pairs(defaults) do
		local dbValue = db[field]
		if field=='*' or field=='**' then
			-- Ignore fieldDefaults and defaultDefaults, already handled.

		elseif type(defValue)=='table' and type(dbValue)=='table' then
			-- if a blocker was set, dive into it, to allow multi-level defaults
			AceDB.RemoveDefaults(dbValue, defValue, blocker and blocker[field])
			if nil==next(dbValue) then
				db[field] = nil
			end

		else
			-- check if the current dbValue matches the default, and that its not blocked by another defaults table
			if dbValue == defValue and (not blocker or blocker[field] == nil) then
				db[field] = nil
			end
		end
	end
end




-- This table contains the keys to select the actual section instance used.
-- The keys are specific to the character, but global to all databases (addons, generally).
-- There's one key (profile) specific to databases, therefore
-- `db.keys` inherits this table and overriddes 'profile'.
--
-- General rule/invariant:
--   db[section] == db.sv[section][ db.keys[section] ]
-- 
-- sectionKeys.global is special as there are no keys in 'global',
-- all characters share the same db.global.
--
-- These sections can all have their defaults (provided by the addon),
-- except proxy fields marked with `false`.
--
local sectionKeys = {
	['global']  = true,    -- No keys in 'global'
	['profile'] = true,    -- Overridden in each db's individual `db.keys`
	-- Proxy fields copied from `sv` when used:
	profiles     = false,
	profileKeys  = false,
}

-- Metatable to inherit sectionKeys in `db.keys`
local keysMeta = { __index = sectionKeys }


local tokenLocale = {}
tokenLocale['class'],sectionKeys['class']  =  UnitClass('player')
tokenLocale['race'], sectionKeys['race']   =  UnitRace('player')

local regionKey  =  _G.GetCurrentRegion and ({"US","KR","EU","TW","CN"})[_G.GetCurrentRegion()]
	or  string.sub(GetCVar('realmList'), 1, 2):upper()

sectionKeys['char']   =  UnitName('player')..' - '..sectionKeys.realm
sectionKeys['realm']  =  GetRealmName()

sectionKeys['faction'],tokenLocale['faction']  =  UnitFactionGroup('player')
sectionKeys['factionrealm']        =  sectionKeys.faction.." - "..sectionKeys.realm
sectionKeys['factionrealmregion']  =  sectionKeys.factionrealm.." - "..regionKey
sectionKeys['locale']              =  GetLocale():lower()

tokenLocale['factionrealm']        =  tokenLocale.faction.." - "..sectionKeys.realm
tokenLocale['factionrealmregion']  =  tokenLocale.factionrealm.." - "..regionKey



local DefaultProfileKey = 'Default'

-- The tokens are not valid as profile names.
-- Token is mapped through tokenKeys[] to get actual value, then mapped through profileKeys[] to get human-readable profile name used in profile[].
local tokenKeys = {
	-- role and spec aren't straightforward -> SpecsNRoles.UpdateSpec() initializes it.
	-- ['role']     = 'Melee',            -- 'Melee/Ranged/Tank/Healer'  --  role quadrinity.
	-- ['role3']    = 'Damage',           -- 'Damage/Tank/Healer'  --  role trinity, but readable, instead of builtin blizrole 'DAMAGER/TANK/HEALER'.
	-- ['dpsrole']  = 'Melee',            -- 'Melee/Ranged'/nil    --  two kinds of 'Damage':  'Melee/Ranged', nil when role3 ~= 'Damage'
	-- ['spec']     = sectionKeys.class,  -- '<CLASS>-<specIndex>', default is '<CLASS>' when not specialized,
	-- Map the addon-provided `addonDefaultToken`
	[false]      = sectionKeys.char,   -- Map `false` to character profile.
	[true]       = DefaultProfileKey,  -- Map `true`  to 'Default' profile.
	Default      = DefaultProfileKey,  -- Used in AceDB.DefaultProfilePriority, clearer than using `true`.
	-- Disable fields not valid as token, but inherited from sectionKeys.
	global       = false,              -- The equivalent of a 'global' section is a shared profile, useless as token.
	profile      = false,              -- .profile==true is meaningless here.
}
tokenLocale.Default = _G.DEFAULT

tokenKeys['gender']     = ({ "Neutral","Male","Female" })[UnitSex('player')]  -- 2 = Male, 3 = Female
tokenKeys['racegender'] = sectionKeys.race.."-"..tokenKeys.gender

-- tokenLocale['gender']      = _G[tokenKeys.gender:upper()]
-- tokenLocale['gender']      = _G[ ({ nil, 'MALE', 'FEMALE' })[UnitSex('player')] ]
tokenLocale['gender']      = _({ nil, _G.MALE, _G.FEMALE })[UnitSex('player')]
tokenLocale['racegender']  = tokenLocale.race.."-"..tokenLocale.gender


function AceDB.SetTokenKey(tokenKeys, token, newvalue)
	local oldvalue = tokenDynamic[token]
	tokenDynamic[token] = newvalue
	tokenLocale[token]    = keyLocale[token]
	getmetatable(tokenKeys)._callbacks:Fire(token, newvalue, oldvalue)
end

-- Make tokenKeys a proxy for tokenDynamic. Dynamic keys are stored there, to capture their modification with __newindex and notify observers of the key change.
setmetatable(tokenDynamic, { __index = sectionKeys })
-- LibObservable:MakeObservable(tokenKeys, tokenDynamic, 2)
setmetatable(tokenKeys, { __index = tokenDynamic, __newindex = AceDB.SetTokenKey, _callbacks = CallbackDummy })

--[[
function getmetatable(tokenKeys):RegisterCallback(...)
	CallbackHandler = CallbackHandler or LibStub("CallbackHandler-1.0")
	local was = self.RegisterCallback
	self._callbacks = CallbackHandler:New(self)
	-- Safety check to avoid infinite recursion by programming error.
	assert(self.RegisterCallback ~= was, "Failed to do CallbackHandler:New()")
	-- Call the real RegisterCallback() created by CallbackHandler.
	self:RegisterCallback(...)
end
--]]

function tokenKeys:RegisterCallback(...)
	CallbackHandler = CallbackHandler or LibStub("CallbackHandler-1.0")
	local was = self.RegisterCallback
	getmetatable(self)._callbacks = CallbackHandler:New(self)
	-- Safety check to avoid infinite recursion by programming error.
	assert(self.RegisterCallback ~= was, "Failed to do CallbackHandler:New()")
	-- Call the real RegisterCallback() created by CallbackHandler.
	self:RegisterCallback(...)
end


-- Translations of keys, exported for addons and AceDB-Options:  AceDB.keyLocale
-- keyLocale (maps key -> translation) is different from tokenLocale (maps token -> translation)
local keyLocale = {}
local keyGlobale = {}

-- keyLocale[DefaultProfileKey] = _G.DEFAULT
-- keyGlobale[_G.DEFAULT] = DefaultProfileKey

for token,translated in tokenLocale do
	local englishKey = sectionKeys[token]
	keyLocale[englishKey] = translated
	keyGlobale[translated] = englishKey
end

-- Add further additions to keyLocale as well.
setmetatable(tokenLocale, {
	__newindex = function(tokenLocale, token, translated)
		rawset(tokenLocale, token, translated)
		local englishKey = sectionKeys[token]
		local wasTranslated = keyLocale[englishKey]
		if nil==wasTranslated then  keyLocale[englishKey] = translated
		else  softassertf(wasTranslated == translated, "tokenLocale[%q] = %q is different from keyLocale[%q] = %q", token, translated, englishKey, wasTranslated)
		end
	end
})

-- Add to keyGlobale too.
setmetatable(keyLocale, {
	__newindex = function(keyLocale, englishKey, translated)
		rawset(keyLocale, englishKey, translated)
		keyGlobale[translated] = keyGlobale[translated] or englishKey
	end
})



-- Check if the name matches any of the translated token keys,
-- and save the English -> translated key mapping.
-- This will be used to identify as class/spec/role/etc. profile.
function AceDB.CheckTranslatedProfileName(profileKeys, name)
	local englishKey = keyGlobale[name]
	-- Not a key translation.
	if not englishKey then  return nil  end

	-- Key already mapped to a translation.
	local differentName = profileKeys[englishKey]
	if nil~=differentName then  return englishKey, name == differentName  end

	-- Save this mapping.
	profileKeys[englishKey] = name
	return englishKey, true
end




-- This is called when a db section is first accessed, to set up the defaults.
local function initSection(sv, section, key, defaults)
	-- local sv = db.sv

	-- 'profile' section is stored in  sv.profiles  for historical reasons.
	local svField =  section=='profile' and 'profiles'  or  section
	local svSection = sv[svField]
	if not svSection then  svSection = {} ; sv[svField] = svSection  end

	-- No keys in 'global' section.
	local sectionDB, isNew =  svField == 'global' and svSection  or  svSection[key]
	if not sectionDB then
		sectionDB, isNew  =  {}, true
		svSection[key] = sectionDB
	end

	if defaults then
		AceDB.ApplyDefaults(sectionDB, defaults)
	end
	-- rawset(db, section, sectionDB)

	return sectionDB, isNew
end




-- Metatable to handle the dynamic creation of sections and copying of sections.
AceDB.dbmt = AceDB.dbmt or {}
-- Possible to get previous revision's dbmt:  getmetatable(next(AceDB.db_registry) or {})  or {}
-- But might be altered by addon, rather just replace it.
local dbmt = AceDB.dbmt


-- Internal fields in `db`
-- Fields marked with `true`˛must not be set to nil.  dbmt.__index() will raise an error if that happens.
-- Fields marked `false` are set to false in dbmt.__index()
local mandatoryFields = {
	-- Musthave fields:
	sv         = true,
	keys       = true,
	parent     = true,
	-- Fields possibly initialized in  initdb():
	children   = false,
	name       = false,
	defaults   = false,
	defaultProfileKey = false,
	-- Fields initialized by db:RegisterCallback():
	callbacks  = false,
	RegisterCallback       = false,
	UnregisterCallback     = false,
	UnregisterAllCallbacks = false,
}


dbmt.__index = function(db, field)
	-- local keys = rawget(db, "keys")
	-- __index() is only hit if  db[field] == nil.
	-- `db.keys`  would call __index() causing infinite recursion, if it was reset to nil by accident.
	if field == 'keys' then  return error("AceDB:  db.keys was set to nil.")  end
	local key = db.keys[field]

	if key then
		local sectionDefaults = rawget(db, 'defaults') and db.defaults[field]
		local sectionDB,new = initSection(db.sv, field, key, sectionDefaults)

		if _G.DEVMODE then  softassert(not getmetatable(db).__newindex, "Some addon set  getmetatable(db).__newindex.  rawset() might be necessary.")  end
		db[field] = sectionDB

		if new and field == 'profile' then
			-- This fires only after `initdb()` if the chosen (default) profile is non-existent when the db is initialized.
			-- Calling db:SetProfile() fires OnNewProfile before `dbmt.__index()`
			-- Callback: OnNewProfile(database, profileName)
			db.callbacks:Fire("OnNewProfile", db, key)
		end
		return sectionDB

  -- if not key then
	elseif key == false then
		local value = sv[field]
		-- These fields in sv are now initialized by initdb() until logoutHandler() cleans the empties.
		-- Cache it, or go through __index() on each access?  Few addons use it,
		-- not much to save on memory, and those use it a few times, so cache.
		db[field] = value
		return value

	else

		local mixinMethod = DBObjectMixin[field]
		if mixinMethod then
			if  not db.parent  or  field=='RegisterDefaults'  or  field=='ResetProfile'  then
				return mixinMethod
			else
				error("AceDB:  db:"..tostring(field).."() method is not available for child-databases aka. namespaces.")
			end
		end

		local mustHave = mandatoryFields[field]
		if mustHave then
			-- sv, keys
			error("AceDB:  db."..tostring(field).." was set to nil.")
		elseif mustHave == nil then
			softassert(false, "AceDB:  unexpected field  db."..tostring(field).." (=nil)  was accessed.")
		else
			-- defaults, name, parent, children, callbacks,	RegisterCallback,	UnregisterCallback,	UnregisterAllCallbacks
		end

		-- Stop triggering __index()
		db[field] = false
		return false
	end
end




local function profileName(sv, key)
	-- Get the human-readable (localized or user-provided) profile name.
	return  sv.profileKeys[key]  or  key
end

local function profileExists(sv, key)
	-- Get the human-readable name of an existing profile selected for this profile `key`.
	local name =  sv.profileKeys[key]  or  key
	return  sv.profiles[name]  and  name
end


--- AceDB.GetDefaultProfileName()
-- Can be overridden by addon as db:GetDefaultProfileName()
-- or hooked/replaced globally as AceDB.DBObjectMixin:GetDefaultProfileName()
--
function DBObjectMixin:GetDefaultProfileName()
	local sv, prio, profileName = self.sv, self.ProfilePriority or AceDB.DefaultProfilePriority
	for i,token in ipairs(prio) do
		profileName = profileExists(sv, tokenKeys[token])
		if profileName then  return profileName  end
	end

	return  nil
		-- or  sv.profileKeys[DefaultProfileKey]     -- If `profileKeys.Default` is set then create profile with that name.
		or  profileName(sv, self.defaultProfileKey)  -- Addon provided default, or globally set AceDB.Global.DefaultProfileKey. Will be created if not existing.
		or  tokenKeys.char
end	


--- DBObjectMixin:GetSelectedProfileName()
-- Get the character's selected profile.
-- @return  profileName  or  nil  if that profile does not exist.
-- Can be overridden by addon as db:GetSelectedProfileName()
-- or hooked/replaced globally as AceDB.DBObjectMixin:GetSelectedProfileName()
--
function DBObjectMixin:GetSelectedProfileName()
	local sv = self.sv
	return  nil
		or  profileExists(sv, AceDB.Global.AutoSelectProfile)  -- Select one profile in all addons for a character. Ignored, if no such profile.
		or  profileExists(sv, sectionKeys.char)
end




local function validateDefaults(defaults, sectionKeys, offset)
	if not defaults then  return  end
	for section in pairs(defaults) do
		if not sectionKeys[section] then
			error("Usage: AceDBObject:RegisterDefaults(defaults): '"..tostring(section).."' is not a valid section.", 3 + (offset or 0))
		end
	end
end



local preserveFields = {
	sv         = nil,
	keys       = nil,
	parent     = true,
	children   = true,
	name       = true,
	defaults   = nil,
	defaultProfileKey = nil,
	callbacks  = true,
	RegisterCallback       = true,
	UnregisterCallback     = true,
	UnregisterAllCallbacks = true,
}

-- Actual database initialization function
local function initdb(sv, defaults, defaultProfileToken, oldDB, parentDB)

	validateDefaults(defaults, sectionKeys, 1)

	-- This allows us to use this function to reset an entire database
	-- Clear out the old database
	if type(oldDB)=='string' then
		oldDB = { name = oldDB }
	elseif oldDB then
		for k,v in pairs(oldDB) do if not preserveFields[k] then oldDB[k] = nil end end
	end

	-- Give this database the metatable so it initializes dynamically
	local db = setmetatable(oldDB or {}, dbmt)
	db.sv = sv
	db.defaults = defaults or false    -- default to false to avoid __index() lookup
	parentDB    = parentDB or db.parent
	db.parent   = parentDB or false
	if parentDB then
		-- Namespaces don't need profileKeys.
		sv.profileKeys = nil
	else
		sv.profileKeys = sv.profileKeys or {}
	end
	sv.profiles     = sv.profiles or {}
	-- db.profiles     = sv.profiles  -- initialized on demand

	local defaultProfile, profileName

	if parentDB then
		-- If this is a namespace then use parent DB's profileName.
		profileName = parentDB.keys.profile
	else
		-- Get the profileName from profileKeys.
		profileName = db:GetSelectedProfileName()
		local profileKeys = sv.profileKeys

		-- Check if the profileName is a translated tokenKey.
		AceDB.CheckTranslatedProfileName(profileKeys, profileName)

		-- Addon defaultProfileToken overrides. Can be 'role'/'class'/'spec'/etc.
		--[[ Preferable to create a role/class/spec -named profile. It will be used as default.
		local AddonDefaultProfile = AceDB.Global.AddonDefaultProfile
		defaultProfileToken = AddonDefaultProfile and AddonDefaultProfile[db.name]  or defaultProfileToken
		--]]
		-- Map true->'Default' and tokens 'role/class/spec/char/realm/etc.' to the active, non-localized (always English) role/class/specialization/etc.
		-- Plain profile key/name is also accepted.
		db.defaultProfileKey = tokenKeys[defaultProfileToken]  or defaultProfileToken  or AceDB.Global.DefaultProfileKey
		defaultProfile = db:GetDefaultProfileName()
		profileKeys[charKey] =  profileName ~= defaultProfile  and  profileName  or  nil

		if  not profileName  and  profileKeys.Default ~= nil  and  profileKeys.Default ~= defaultProfile  then
			print('AceDB["'..db.name..'"] default profile changed: ', profileKeys.Default, ' -> ', defaultProfile)
			-- Any characters that had the defaultProfile chosen,
			-- will follow the change and use the new defaultProfile.
		end

		profileKeys.Default = defaultProfile
		-- profileKeys.Shared  = sharedProfile
	end

	db.keys = setmetatable({ profile = profileName or defaultProfile }, keysMeta)
	-- Garbage collection:  Remove identity and default mappings from sv.profileKeys
	if not parentDB then  AceDB.CleanProfileKeys(sv)  end

	--[[ db.callbacks are created by DBObjectMixin:RegisterCallback() on demand: when the addon first registers a callback.
	if not db.callbacks then
		-- try to load CallbackHandler-1.0 if it loaded after our library
		if not CallbackHandler then CallbackHandler = LibStub("CallbackHandler-1.0", true) end
		db.callbacks = CallbackHandler and CallbackHandler:New(db) or CallbackDummy
	end
	--]]

	--[[ Handled by inheritance in  dbmt.__index()
	-- Copy methods locally into the database object, to avoid hitting
	-- the metatable when calling methods
	if not parentDB then
		for name,method in pairs(DBObjectMixin) do
			db[name] = method
		end
	else
		-- Hack this one in for namespaces.
		db.RegisterDefaults = DBObjectMixin.RegisterDefaults
		db.ResetProfile = DBObjectMixin.ResetProfile
	end
	--]]

	-- store the DB in the registry
	local registry = AceDB.registry
	AceDB.db_registry[db] = true    -- deprecated
	registry[#registry+1] = db
	registry[sv] = db
	registry[db.name] = db

	return db
end




-- handle PLAYER_LOGOUT
-- strip all defaults from all databases
-- and cleans up empty sections
local function logoutHandler(frame, event)
	if event == "PLAYER_LOGOUT" then
		for i,db in ipairs(AceDB.registry) do
			db.callbacks:Fire("OnDatabaseShutdown", db)
			db:RegisterDefaults(nil)

			-- cleanup sections that are empty without defaults
			local sv, deleteEmptyProfiles = db.sv, db.parent
			for section,valid in pairs(sectionKeys) do
				-- 'profile' section is stored in  sv.profiles  for historical reasons.
				if section=='profile' then  section = 'profiles'  end

				local svSection = valid and rawget(sv, section)
				if svSection then
					-- global is special, all other sections have sub-entrys
					-- also don't delete empty profiles on main dbs, only on namespaces
					if  section~='global'  and  (section~='profiles' or deleteEmptyProfiles)  then
						for key,sectionDB in pairs(svSection) do
							if nil==next(sectionDB) then
								svSection[key] = nil
							end
						end
					end
					if nil==next(svSection) then
						sv[section] = nil
					end
				end
			end

			-- Remove profileKeys if empty.
			if  nil==next(sv.profiles)      then  sv.profiles = nil      end
			if  nil==next(sv.profileKeys)   then  sv.profileKeys  = nil  end
		end
	end
end

AceDB.frame:RegisterEvent("PLAYER_LOGOUT")
AceDB.frame:SetScript("OnEvent", logoutHandler)




--[[-------------------------------------------------------------------------
	AceDB Object Method Definitions
---------------------------------------------------------------------------]]

--- Sets the defaults table for the given database object by clearing any
-- that are currently set, and then setting the new defaults.
-- @param defaults A table of defaults for this database
function DBObjectMixin:RegisterDefaults(defaults)
	if defaults then
		asserttype(defaults, 'table', "Usage: AceDBObject:RegisterDefaults(defaults): 'defaults' -", 2)
	end

	validateDefaults(defaults, sectionKeys)

	-- Remove any currently set defaults
	if self.defaults then
		-- pairs(self) iterates the created sections and a few other fields filtered out by sectionKeys[]
		for section,sectionDB in pairs(self) do
			local sectionDefaults =  sectionKeys[section]  and  defaults[section]
			if sectionDefaults then
				AceDB.RemoveDefaults(sectionDB, sectionDefaults)
			end
		end
	end

	-- Set the DBObject.defaults table
	self.defaults = defaults

	-- Copy in any defaults, only touching those sections already created
	if defaults then
		for section,sectionDB in pairs(self) do
			local sectionDefaults =  sectionKeys[section]  and  defaults[section]
			if sectionDefaults then
				AceDB.ApplyDefaults(sectionDB, sectionDefaults)
			end
		end
	end
end




-- Garbage collection, can be hooked/replaced.
function AceDB.CleanProfileKeys(sv)
	if not sv.profileKeys then  return  end
	
	for  key, profileName  in pairs(sv.profileKeys) do
		-- Remove identity mappings ([charKey] = charKey) from profileKeys.
		if key == profileName then  sv.profileKeys[key] = nil  end
	end
end


--- Returns a table with the names of the existing profiles in the database.
-- You can optionally supply a table to re-use for this purpose.
-- @param list A table to store the profile names in (optional)
function DBObjectMixin:GetProfiles(list)
	assert(not list or type(list)=='table', "Usage: AceDBObject:GetProfiles(list): 'list' - table or nil expected.", 2)
	-- Clear the container table
	list =  list and wipe(list)  or  {}

	local curProfile = self.keys.profile

	for profileName in pairs(self.sv.profiles) do
		list[#list] = profileName
		if curProfile and profileName == curProfile then curProfile = nil end
	end

	-- Add the current profile, if it hasn't been created yet
	if curProfile then  list[#list+1] = curProfile  end

	return list, #list
end


--- Returns the current profile name used by the database
function DBObjectMixin:GetCurrentProfile()
	return self.keys.profile
end



--- Changes the profile of the database and all of it's namespaces to the
-- supplied named profile
-- @param name The name of the profile to set as the current profile
function DBObjectMixin:SetProfile(name)
	asserttype(name, 'string', "Usage: AceDBObject:SetProfile(name): 'name' -", 2)

	-- changing to the same profile, dont do anything
	if name == self.keys.profile then return end

	local oldProfile = self.profile
	local defaults = self.defaults and self.defaults.profile

	-- Callback: OnProfileShutdown, database
	self.callbacks:Fire("OnProfileShutdown", self)

	if oldProfile and defaults then
		-- Remove the defaults from the old profile
		AceDB.RemoveDefaults(oldProfile, defaults)
	end

	self.profile = nil
	self.keys.profile = name

	local profiles = self.sv.profiles
	local new = not profiles[name]
	-- Create empty self.sv.profiles[name]:  GetDefaultProfileName() only looks for existing profiles.
	if new then  profiles[name] = {}  end
	
		-- Check if the name is a translated tokenKey.
	AceDB.CheckTranslatedProfileName(self.sv.profileKeys, name)
	
	-- Save or cleanup new profileKey mapping.
	local defaultProfile = self:GetDefaultProfileName()
	self.sv.profileKeys[charKey] =  name ~= defaultProfile  and  name  or  nil

	-- populate to child namespaces
	for _,db in pairsOrNil(self.children) do
		DBObjectMixin.SetProfile(db, name)
	end

	if new then
		-- Send OnNewProfile() earlier than `dbmt.__index()` would,
		-- if  self.sv.profiles[name]  was not initialized above.
		-- Callback: OnNewProfile(database, profileName)
		db.callbacks:Fire("OnNewProfile", db, name)
		-- It is possible `db.profile` was not referenced in the callbacks, and is still uninitialized.
		-- `db.profile` is not evaluated yet, therefore initSection() did not ApplyDefaults()
	end

	-- Callback: OnProfileChanged, database, newProfileKey
	self.callbacks:Fire("OnProfileChanged", self, name)
end



--- Rename a named profile. Character `profileKeys` are updated to link to the new name.
-- Class/spec/etc. profiles can be renamed as well, keeping it's special role.
-- @param oldname  The previous name of the profile.
-- @param newname  The next name of the profile.
-- @param silent If true, do not raise an error when the profile does not exist
function DBObjectMixin:RenameProfile(oldname, newname, silent)
	asserttype(oldname, 'string', "Usage: AceDBObject:DeleteProfile(oldname): 'oldname' -", 2)
	asserttype(newname, 'string', "Usage: AceDBObject:DeleteProfile(newname): 'newname' -", 2)

	-- populate to child namespaces
	for namespace,namespaceDB in pairsOrNil(self.children) do
		DBObjectMixin.RenameProfile(namespaceDB, oldname, newname, true)
	end

	-- switch all characters that use this profile to the newname
	-- including token key mappings, like profileKeys.Default and profileKeys['<CLASS>'], etc.
	-- Way to rename class, spec, etc. profiles.
	local profileKeys = self.sv.profileKeys
	for key, profileName in pairsOrNil(profileKeys) do
		if profileName == oldname then
			profileKeys[key] = newname
		end
	end
	
	-- rename: reference by newname in profiles
	local profiles = self.sv.profiles
	profiles[newname] = profiles[oldname]
	profiles[oldname] = nil

		-- Check if the  name is a translated tokenKey.
	AceDB.CheckTranslatedProfileName(profileKeys, name)
	
	-- Callback: OnProfileRenamed, database, profileKey
	self.callbacks:Fire("OnProfileRenamed", self, name)
end



--- Deletes a named profile.
-- @param name The name of the profile to be deleted
-- @param silent If true, do not raise an error when the profile does not exist
function DBObjectMixin:DeleteProfile(name, silent)
	asserttype(name, 'string', "Usage: AceDBObject:DeleteProfile(name): 'name' -", 2)

	if self.keys.profile == name then
		-- error("Cannot delete the active profile in an AceDBObject.", 2)
		self.profile = nil
		local defaultProfile = self:GetDefaultProfileName()
		self:SetProfile(defaultProfile)
	else
		assert(silent or rawget(self.sv.profiles, name), "Cannot delete non-existent profile.", 2)
	end


	-- delete from profiles
	self.sv.profiles[name] = nil

	-- populate to child namespaces
	for namespace,namespaceDB in pairsOrNil(self.children) do
		DBObjectMixin.DeleteProfile(namespaceDB, name, true)
	end

	-- switch all characters that use this profile back to the default
	-- including token key mappings, like profileKeys.Default and profileKeys['<CLASS>'], etc.
	local profileKeys = self.sv.profileKeys
	for key, profileName in pairsOrNil(profileKeys) do
		if profileName == name then
			profileKeys[key] = nil
		end
	end

	-- Callback: OnProfileDeleted, database, profileKey
	self.callbacks:Fire("OnProfileDeleted", self, name)
end



--- Copies a named profile into the current profile, overwriting any conflicting
-- settings.
-- @param name The name of the profile to be copied into the current profile
-- @param silent If true, do not raise an error when the profile does not exist
function DBObjectMixin:CopyProfile(name, silent)
	asserttype(name, 'string', "Usage: AceDBObject:CopyProfile(name): 'name' -", 2)
	assert(name ~= self.keys.profile, "Cannot have the same source and destination profiles.", 2)
	assert(silent or rawget(self.sv.profiles, name), "Cannot copy non-existent profile.", 2)

	-- Reset the profile before copying
	DBObjectMixin.ResetProfile(self, nil, true)

	local profile = self.profile
	local source = self.sv.profiles[name]

	DeepCopy(profile, source)
	-- AceDB.ApplyDefaults(profile, self.defaults)

	-- populate to child namespaces
	for _, db in pairsOrNil(self.children) do
		DBObjectMixin.CopyProfile(db, name, true)
	end

	-- Check if the name is a translated tokenKey.
	AceDB.CheckTranslatedProfileName(self.sv.profileKeys, name)
	
	-- Callback: OnProfileCopied(database, sourceProfileKey)
	self.callbacks:Fire("OnProfileCopied", self, name)
end



--- Resets the current profile to the default values (if specified).
-- @param noChildren if set to true, the reset will not be populated to the child namespaces of this DB object
-- @param noCallbacks if set to true, won't fire the OnProfileReset callback
function DBObjectMixin:ResetProfile(noChildren, noCallbacks)
	local profile = self.profile

	-- wipe preserves the metatable.
	wipe(profile)

	local defaults = self.defaults and self.defaults.profile
	if defaults then
		AceDB.ApplyDefaults(profile, defaults)
	end

	-- populate to child namespaces
	if self.children and not noChildren then
		for _, db in pairs(self.children) do
			DBObjectMixin.ResetProfile(db, nil, noCallbacks)
		end
	end

	-- Callback: OnProfileReset, database
	if not noCallbacks then
		self.callbacks:Fire("OnProfileReset", self)
	end
end

--- Resets the entire database, using the string defaultProfile as the new default
-- profile.
-- @param defaultProfileToken  The profile name to use as the default
function DBObjectMixin:ResetDB(defaultProfileToken)
	if defaultProfileToken then
		asserttype(defaultProfileToken, 'string', "Usage: AceDBObject:ResetDB(defaultProfileToken): 'defaultProfileToken' -", 2)
	end

	local sv = wipe(self.sv)
	initdb(sv, self.defaults, defaultProfileToken, self, self.parent)    -- TODO: self.parent was not passed?

	-- fix the child namespaces
	if self.children then
		local spaces = sv.namespaces or {}
		sv.namespaces = spaces
		for name, childdb in pairs(self.children) do
			if not spaces[name] then spaces[name] = {} end
			initdb(spaces[name], childdb.defaults, self.keys.profile, childdb, self)
		end
	end

	-- Callback: OnDatabaseReset, database
	self.callbacks:Fire("OnDatabaseReset", self)
	-- Callback: OnProfileChanged, database, profileKey
	self.callbacks:Fire("OnProfileChanged", self, self.keys.profile)

	return self
end



--- Creates a new database namespace, directly tied to the database.  This
-- is a full scale database in it's own rights other than the fact that
-- it cannot control its profile individually
-- @param name The name of the new namespace
-- @param defaults A table of values to use as defaults
function DBObjectMixin:RegisterNamespace(name, defaults)
	asserttype(name, 'string', "Usage: AceDBObject:RegisterNamespace(name, defaults): 'name' -", 2)
	if defaults then
		asserttype(defaults, 'table', "Usage: AceDBObject:RegisterNamespace(name, defaults): 'defaults' -", 2)
	end
	if self.children and self.children[name] then
		error ("Usage: AceDBObject:RegisterNamespace(name, defaults): 'name' - a namespace with that name already exists.", 2)
	end

	local sv, spaces = self.sv, self.sv.namespaces or {}
	sv.namespaces = spaces
	spaces[name] = spaces[name] or {}

	local childname = self.name.."/"..name
	local newDB = initdb(spaces[name], defaults, self.keys.profile, childname, self)

	if not self.children then self.children = {} end
	self.children[name] = newDB
	return newDB
end



--- Returns an already existing namespace from the database object.
-- @param name The name of the new namespace
-- @param silent if true, the addon is optional, silently return nil if its not found
-- @usage
-- local namespace = self.db:GetNamespace('namespace')
-- @return the namespace object if found
function DBObjectMixin:GetNamespace(name, silent)
	asserttype(name, 'string', "Usage: AceDBObject:GetNamespace(name): 'name' - string expected.", 2)
	assert(silent or (self.children and self.children[name]), "Usage: AceDBObject:GetNamespace(name): 'name' - namespace does not exist.", 2)
	if not self.children then self.children = {} end
	return self.children[name]
end




--[[-------------------------------------------------------------------------
	AceDB Exposed Methods
---------------------------------------------------------------------------]]

--- Creates a new database object that can be used to handle database settings and profiles.
-- By default, an empty DB is created, using a character specific profile.
--
-- You can override the default profile used by passing any profile name as the third argument,
-- or by passing //true// as the third argument to use a globally shared profile called "Default".
--
-- Token replacement is back in the default profile name. Following tokens:
-- 
-- will use a profile named "char", and not a character-specific profile.
-- @param savedVariable The name of variable, or table to use for the database
-- @param defaults A table of database defaults
-- @param defaultProfile The name of the default profile. If not set, a character specific profile will be used as the default.
-- You can also pass //true// to use a shared global profile called "Default".
-- @usage
-- -- Create an empty DB using a character-specific default profile.
-- self.db = LibStub("AceDB-3.0"):New("MyAddonDB")
-- @usage
-- -- Create a DB using defaults and using a shared default profile
-- self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)
--
function AceDB:New(savedVariable, defaults, defaultProfileToken)
	local sv, name = savedVariable
	if type(savedVariable) == "string" then
		sv = _G[savedVariable] or {}
		_G[savedVariable], name = sv, savedVariable
	else
		name = tostring(sv)
		name = sv:match("table: (.*)") or name
	end

	asserttype(savedVariable, 'table', "Usage: AceDB:New(savedVariable, defaults, defaultProfileToken): 'savedVariable' -", 2)
	if defaults then
		asserttype(defaults, 'table', "Usage: AceDB:New(savedVariable, defaults, defaultProfileToken): 'defaults' -", 2)
	end
	assert(istype3(defaultProfileToken, 'string', 'boolean', 'nil'), "Usage: AceDB:New(savedVariable, defaults, defaultProfileToken): 'defaultProfileToken' - string or boolean expected.", 2)

	return initdb(sv, defaults, defaultProfileToken, name, nil)
end




-- Migrate registry to  sv -> db  mapping.  Also indexed + db.name -> db.
local registry = AceDB.registry
if not registry then
	registry = {}
	AceDB.registry = registry
	for db in pairs(AceDB.db_registry) do
		registry[#registry+1] = db
		registry[db.sv] = db
		if db.name then  registry[db.name] = db  end
	end
end

-- Upgrade existing databases.
for i,db in ipairs(registry) do
	-- DBObjectMixin is inherited now instead of embedded. Methods are returned by  dbmt.__index(db, methodName)
	-- Caching the methods in db[methodName] is unnecessary, these are called a few times or less in a session.
	for name,method in pairs(DBObjectMixin) do
		db[name] = nil
	end
	--[[
	if not rawget(db, 'parent') then
		for name,method in pairs(DBObjectMixin) do
			db[name] = method
		end
	else
		db.RegisterDefaults = DBObjectMixin.RegisterDefaults
		db.ResetProfile = DBObjectMixin.ResetProfile
	end
	--]]
end


-- Export for addons.
AceDB.DBObjectMixin    = DBObjectMixin
AceDB.ProfileTokenKeys = tokenKeys    -- token -> key
AceDB.keyLocale        = keyLocale    -- key -> translation
AceDB.keyGlobale       = keyGlobale   -- translation -> key
AceDB.tokenLocale      = tokenLocale  -- token -> translation


