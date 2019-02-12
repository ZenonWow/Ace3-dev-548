--- **AceAddon-3.0** provides a template for creating addon objects.
-- It'll provide you with a set of callback functions that allow you to simplify the loading
-- process of your addon.\\
-- Callbacks provided are:\\
-- * **OnInitialize**, which is called during ADDON_LOADED event, directly after the addon's SavedVariables are fully loaded.
-- * **OnEnable** which gets called during the PLAYER_LOGIN event, when most of the data provided by the game is already present.
-- * **OnDisable**, which is only called when your addon is manually being disabled.
-- @usage
-- -- A small (but complete) addon, that doesn't do anything, 
-- -- but shows usage of the callbacks.
-- local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
-- 
-- function MyAddon:OnInitialize()
--   -- do init tasks here, like loading the Saved Variables, 
--   -- or setting up slash commands.
-- end
-- 
-- function MyAddon:OnEnable()
--   -- Do more initialization here, that really enables the use of your addon.
--   -- Register Events, Hook functions, Create Frames, Get information from 
--   -- the game that wasn't available in OnInitialize
-- end
--
-- function MyAddon:OnDisable()
--   -- Unhook, Unregister Events, Hide frames that you created.
--   -- You would probably only use an OnDisable if you want to 
--   -- build a "standby" mode, or be able to toggle modules on/off.
-- end
-- @class file
-- @name AceAddon-3.0.lua
-- @release $Id: AceAddon-3.0.lua 1084 2013-04-27 20:14:11Z nevcairiel $
-- @patch $Id: AceAddon-3.0.lua 1084.1 2019-01 Mongusius, MINOR: 12 -> 12.1
-- 12.1 moved safecall and AutoTablesMeta implementation to CallbackHandler.

local MAJOR, MINOR = "AceAddon-3.0", 12.1
local _G, LibStub = _G, LibStub
local AceAddon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not AceAddon then return end -- No Upgrade needed.


-- Export to _G:  AceAddon
_G.AceAddon = AceAddon

-- Lua APIs
local tinsert, tconcat, tremove = table.insert, table.concat, table.remove
local format, tostring, print = string.format, tostring, print
local select, pairs, next, type, unpack = select, pairs, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local setmetatable, getmetatable, rawset, rawget = setmetatable, getmetatable, rawset, rawget
local xpcall = xpcall

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: LibStub, IsLoggedIn, geterrorhandler


-- Export to LibCommon:  AutoTablesMeta, errorhandler, softassert, safecall/safecallDispatch
local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon
LibCommon.istype2 = LibCommon.istype2 or  function(value, t1, t2, t3)
	local t = type(value)  ;  if t==t1 or t==t2 or t==t3 then return value end  ;  return nil
end

-- AutoTablesMeta: metatable that automatically creates empty inner tables when keys are first referenced.
LibCommon.AutoTablesMeta = LibCommon.AutoTablesMeta or { __index = function(self, key)  if key ~= nil then  local v={} ; self[key]=v ; return v  end  end }

-- Allow hooking _G.geterrorhandler(): don't cache/upvalue it or the errorhandler returned.
-- Avoiding tailcall: errorhandler() function would show up as "?" in stacktrace, making it harder to understand.
LibCommon.errorhandler = LibCommon.errorhandler or  function(errorMessage)  return true and _G.geterrorhandler()(errorMessage)  end

local istype2,AutoTablesMeta,errorhandler = LibCommon.istype2, LibCommon.AutoTablesMeta, LibCommon.errorhandler



if  select(4, GetBuildInfo()) >= 80000  then

	----------------------------------------
	--- Battle For Azeroth Addon Changes
	-- https://us.battle.net/forums/en/wow/topic/20762318007
	-- • xpcall now accepts arguments like pcall does
	--
	LibCommon.safecall = LibCommon.safecall or  function(unsafeFunc, ...)  return xpcall(unsafeFunc, errorhandler, ...)  end

elseif not LibCommon.safecallDispatch then

	-- Export  LibCommon.safecallDispatch
	local SafecallDispatchers = {}
	function SafecallDispatchers:CreateDispatcher(argCount)
		local sourcecode = [===[
			local xpcall, errorhandler = ...
			local unsafeFuncUpvalue, ARGS
			local function xpcallClosure()  return unsafeFuncUpvalue(ARGS)  end

			local function dispatcher(unsafeFunc, ...)
				 unsafeFuncUpvalue, ARGS = unsafeFunc, ...
				 return xpcall(xpcallClosure, errorhandler)
				 -- return xpcall(xpcallClosure, geterrorhandler())
			end

			return dispatcher
		]===]

		local ARGS = {}
		for i = 1, argCount do ARGS[i] = "a"..i end
		sourcecode = sourcecode:gsub("ARGS", tconcat(ARGS, ","))
		local creator = assert(loadstring(sourcecode, "SafecallDispatchers[argCount="..argCount.."]"))
		local dispatcher = creator(xpcall, errorhandler)
		-- rawset(self, argCount, dispatcher)
		self[argCount] = dispatcher
		return dispatcher
	end

	setmetatable(SafecallDispatchers, { __index = SafecallDispatchers.CreateDispatcher })

	SafecallDispatchers[0] = function (unsafeFunc)
		-- Pass a delegating errorhandler to avoid _G.geterrorhandler() function call before any error actually happens.
		return xpcall(unsafeFunc, errorhandler)
		-- Or pass the registered errorhandler directly to avoid inserting an extra callstack frame.
		-- The errorhandler is expected to be the same at both times: callbacks usually don't change it.
		--return xpcall(unsafeFunc, _G.geterrorhandler())
	end

	-- softassert(condition, message):  Report error without halting.
	LibCommon.softassert = LibCommon.softassert or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end

	function LibCommon.safecallDispatch(unsafeFunc, ...)
		-- we check to see if unsafeFunc is actually a function here and don't error when it isn't
		-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
		-- present execution should continue without hinderance
		if  not unsafeFunc  then  return  end
		if  type(unsafeFunc)~='function'  then
			LibCommon.softassert(false, "Usage: safecall(unsafeFunc):  function expected, got "..type(unsafeFunc))
			return
		end

		local dispatcher = SafecallDispatchers[select('#',...)]
		-- Can't avoid tailcall without inefficiently packing and unpacking the multiple return values.
		return dispatcher(unsafeFunc, ...)
	end

end -- LibCommon.safecallDispatch



-- Choose the safecall implementation to use.
local safecall = LibCommon.safecall or LibCommon.safecallDispatch
-- Stack depth offset for error() calls.
local errorOffset = 1
-- Forward declaration
local Embed
-- Client mixins refactored to AceAddon.mixins
-- local Enable, Disable, EnableModule, DisableModule, NewModule, GetModule, GetName, SetDefaultModuleState, SetDefaultModuleLibraries, SetEnabledState, SetDefaultModulePrototype



AceAddon.addons = AceAddon.addons or {}                                -- Registered addon objects:  name -> addon  map.
AceAddon.mixins = AceAddon.mixins or {}                                -- Methods embedded in clients (registered addons).
local mixins    = AceAddon.mixins
AceAddon.embeds = setmetatable(AceAddon.embeds or {}, AutoTablesMeta)  -- contains a list of libraries embedded in an addon
AceAddon.statuses = AceAddon.statuses or {} -- statuses of addon.
AceAddon.initializequeue = AceAddon.initializequeue or {} -- addons that are new and not initialized
AceAddon.enablequeue = AceAddon.enablequeue or {} -- addons that are initialized and waiting to be enabled
AceAddon.frame = AceAddon.frame or CreateFrame("Frame", "AceAddon30Frame") -- Our very own frame



--- Create a new AceAddon-3.0 addon.
-- Any libraries you specified will be embedded, and the addon will be scheduled for 
-- its OnInitialize and OnEnable callbacks.
-- The final addon object, with all libraries embedded, will be returned.
-- @paramsig [object ,]name[, lib, ...]
-- @param object Table to use as a base for the addon (optional)
-- @param name Name of the addon object to create
-- @param lib List of libraries to embed into the addon
-- @usage 
-- -- Create a simple addon object
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceEvent-3.0")
--
-- -- Create a Addon object based on the table of a frame
-- local MyFrame = CreateFrame("Frame")
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon(MyFrame, "MyAddon", "AceEvent-3.0")
function AceAddon:NewAddon(objectorname, ...)
	local firstLib,addon,name
	if type(objectorname) ~= 'table'
	then  firstLib,addon,name = 1, {}, objectorname
	else  firstLib,addon,name = 2, objectorname, ...
	end
	
	if type(name)~="string" then
		error( format("Usage: AceAddon:NewAddon([addon,] name, [lib, lib, lib, ...]): `name` - string expected got '%s'.", type(name)), 2 )
	end
	if self.addons[name] then 
		error( format("Usage: AceAddon:NewAddon([addon,] name, [lib, lib, lib, ...]): `name` - Addon '%s' already exists.", name), 2 )
	end
	
	addon.name = name
	errorOffset = 2
	self:InitObject(addon)
	AceAddon:EmbedLibraries(addon, select(firstLib,...))
	errorOffset = 1
	return addon
end


-- used in the addon metatable
local function addontostring( self ) return self.name end 

-- NewAddon/NewModule common part.
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
function AceAddon:InitObject(object)
	local callerFrame = 3  -- 1:InitObject,2:NewAddon/NewModule,3:caller
	local callerStack = _G.debugstack(callerFrame,3,0)  -- read 3 frames to allow for tailcails (no filepath in those)
	object.folderName = callerStack and callerStack:match([[AddOns\(.-)\]])
	if  not object.folderName  then
		print((object.moduleName and "NewModule" or "NewAddon").."(name="..object.name.."): folderName not found, callerStack="..tostring(callerStack))
	elseif  not object.moduleName  and  object.name ~= object.folderName  then
		print("NewAddon(name="..object.name.."): ~= folderName="..tostring(object.folderName))
	end
	
	local addonmeta = {}
	local oldmeta = getmetatable(object)
	if oldmeta then
		for k, v in pairs(oldmeta) do addonmeta[k] = v end
	end
	addonmeta.__tostring = addontostring
	
	setmetatable( object, addonmeta )
	self.addons[object.name] = object
	object.modules = {}
	object.orderedModules = {}
	object.defaultModuleLibraries = {}
	Embed( object ) -- embed NewModule, GetModule methods
	-- errorOffset = errorOffset + 1    -- 3
	-- self:EmbedLibraries(object, ...)
	-- errorOffset = 1
	
	-- add to queue of addons to be initialized upon ADDON_LOADED
	tinsert(self.initializequeue, object)
	return object
end


--- Get the addon object by its name from the internal AceAddon registry.
-- Throws an error if the addon object cannot be found (except if silent is set).
-- @param name unique name of the addon object
-- @param silent if true, the addon is optional, silently return nil if its not found
-- @usage 
-- -- Get the Addon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
function AceAddon:GetAddon(name, silent)
	if not silent and not self.addons[name] then
		error( format("Usage: GetAddon(name): `name` - Cannot find an AceAddon '%s'.", tostring(name)), 2 )
	end
	return self.addons[name]
end


-- Global shorthand to access addons, similar to LibStub's. Examples:
-- _G.AceAddon('Prat-3.0'), _G.AceAddon('Dominos'), etc.
-- _G.AceAddon.Dominos, etc.
setmetatable(AceAddon, { __call = AceAddon.GetAddon, __index = AceAddon.addons })

-- - Embed a list of libraries into the specified addon.
-- This function will try to embed all of the listed libraries into the addon
-- and error if a single one fails.
--
-- **Note:** This function is for internal use by :NewAddon/:NewModule
-- @paramsig addonOrModule, [lib, ...]
-- @param addonOrModule object to embed the libs in
-- @param lib List of libraries to embed into the addon
function AceAddon:EmbedLibraries(addonOrModule, ...)
	for i = 1,select('#',...) do
		local libname = select(i, ...)
		self:EmbedLibrary(addonOrModule, libname, false, errorOffset+1)
	end
end


-- - Embed a library into the addon object.
-- This function will check if the specified library is registered with LibStub
-- and if it has a :Embed function to call. It'll error if any of those conditions
-- fails.
--
-- **Note:** This function is for internal use by :EmbedLibraries
-- @paramsig addon, libname[, silent[, offset]]
-- @param addon addon object to embed the library in
-- @param libname name of the library to embed
-- @param silent marks an embed to fail silently if the library doesn't exist (optional)
-- @param offset will push the error messages back to said offset, defaults to 2 (optional)
function AceAddon:EmbedLibrary(addonOrModule, libname, silent, offset)
	local lib = LibStub:GetLibrary(libname, true)
	if not lib and not silent then
		error( format("Usage: EmbedLibrary(addonOrModule, libname, silent, offset): `libname` - Cannot find a library instance of %q.", tostring(libname)), (offset or 1)+1 )
	elseif lib and type(lib.Embed) == "function" then
		lib:Embed(addonOrModule)
		tinsert(self.embeds[addonOrModule], libname)
		return true
	elseif lib then
		error( format("Usage: EmbedLibrary(addonOrModule, libname, silent, offset): `libname` - Library '%s' is not Embed capable", libname), (offset or 1)+1 )
	end
end


--- Return the specified module from an addon object.
-- Throws an error if the addon object cannot be found (except if silent is set)
-- @name //addon//:GetModule
-- @paramsig name[, silent]
-- @param name unique name of the module
-- @param silent if true, the module is optional, silently return nil if its not found (optional)
-- @usage 
-- -- Get the Addon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- -- Get the Module
-- MyModule = MyAddon:GetModule("MyModule")
function mixins.GetModule(addon, name, silent)
	if not addon.modules[name] and not silent then
		error( format("Usage: MyAddon:GetModule(name, silent): `name` - Cannot find module '%s'.", tostring(name)), 2 )
	end
	return addon.modules[name]
end


local function ReturnFalse() return false end
local function ReturnTrue() return true end

--- Create a new module for the addon.
-- The new module can have its own embedded libraries and/or use a module prototype to be mixed into the module.\\
-- A module has the same functionality as a real addon, it can have modules of its own, and has the same API as
-- an addon object.
-- @name //addon//:NewModule
-- @paramsig name[, prototype|lib[, lib, ...]]
-- @param name unique name of the module
-- @param prototype object to derive this module from, methods and values from this table will be mixed into the module (optional)
-- @param lib List of libraries to embed into the addon
-- @usage 
-- -- Create a module with some embedded libraries
-- MyModule = MyAddon:NewModule("MyModule", "AceEvent-3.0", "AceHook-3.0")
-- 
-- -- Create a module with a prototype
-- local prototype = { OnEnable = function(module) print("OnEnable called!") end }
-- MyModule = MyAddon:NewModule("MyModule", prototype, "AceEvent-3.0", "AceHook-3.0")
function mixins.NewModule(addon, moduleName, ...)
	local prototype = ...
	local prototypeSet =  1 <= select('#',...)  and  type(prototype) ~= 'string'
	if type(moduleName)~='string' then
		error( "Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]): `moduleName` - string expected, got "..type(moduleName) , 2 )
	end
	if prototypeSet and not istype2(prototype, 'table', 'function') then
		error( "Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]): `prototype` - table/function/nil (prototype), string (lib) expected, got "..type(prototype) , 2 )
	end
	if addon.modules[moduleName] then
		error( 'Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]):  Module "'..moduleName..'" already exists.', 2 )
	end
	
	local module = { IsModule = ReturnTrue, moduleName = moduleName }
	-- SetEnabledState(module, addon.defaultModuleState)
	module.enabledState = addon.defaultModuleState
	module.name = (addon.name or tostring(addon)).."_"..moduleName
	
	-- modules are basically addons. We treat them as such. They will be added to the initializequeue properly as well.
	-- NewModule can only be called after the parent addon is present thus the modules will be initialized after their parent is.
	errorOffset = 2
	AceAddon:InitObject(module)
	AceAddon:EmbedLibraries(module, select(prototypeSet and 2 or 1,...) )
	AceAddon:EmbedLibraries(module, unpack(addon.defaultModuleLibraries))
	errorOffset = 1

	-- if not prototype or type(prototype) == "string" then
	if  not prototypeSet  then
		prototype = addon.defaultModulePrototype or nil
	end
	
	-- if type(prototype) == "table" then
	if prototype ~= nil then
		-- meta.__index == nil after InitObject()
		local meta = getmetatable(module)
		meta.__index = prototype
		-- setmetatable(module, meta)  -- More of a Base class type feel.
	end
	
	safecall(addon.OnModuleCreated, addon, module) -- Was in Ace2 and I think it could be a cool thing to have handy.
	addon.modules[moduleName] = module
	tinsert(addon.orderedModules, module)
	
	return module
end

--- Returns the real name of the addon or module, without any prefix.
-- @name //addon//:GetName
-- @paramsig 
-- @usage 
-- print(MyAddon:GetName())
-- -- prints "MyAddon"
function mixins.GetName(addonOrModule)
	return addonOrModule.moduleName or addonOrModule.name
end


-- Check if the addon is queued for initialization
local function queuedForInitialization(addon)
	for i = 1, #AceAddon.initializequeue do
		if AceAddon.initializequeue[i] == addon then
			return true
		end
	end
	return false
end

--- Enables the Addon, if possible, return true or false depending on success.
-- This internally calls AceAddon:EnableAddon(), thus dispatching a OnEnable callback
-- and enabling all modules of the addon (unless explicitly disabled).\\
-- :Enable() also sets the internal `enabledState` variable to true
-- @name //addon//:Enable
-- @paramsig 
-- @usage 
-- -- Enable MyModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("MyModule")
-- MyModule:Enable()
function mixins.Enable(addonOrModule)
	addonOrModule:SetEnabledState(true)

	-- nevcairiel 2013-04-27: don't enable an addon/module if its queued for init still
	-- it'll be enabled after the init process
	if not queuedForInitialization(addonOrModule) then
		return AceAddon:EnableAddon(addonOrModule)
	end
end

--- Disables the Addon, if possible, return true or false depending on success.
-- This internally calls AceAddon:DisableAddon(), thus dispatching a OnDisable callback
-- and disabling all modules of the addon.\\
-- :Disable() also sets the internal `enabledState` variable to false
-- @name //addon//:Disable
-- @paramsig 
-- @usage 
-- -- Disable MyAddon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:Disable()
function mixins.Disable(addonOrModule)
	addonOrModule:SetEnabledState(false)
	return AceAddon:DisableAddon(addonOrModule)
end

--- Enables the Module, if possible, return true or false depending on success.
-- Short-hand function that retrieves the module via `:GetModule` and calls `:Enable` on the module object.
-- @name //addon//:EnableModule
-- @paramsig name
-- @usage 
-- -- Enable MyModule using :GetModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("MyModule")
-- MyModule:Enable()
--
-- -- Enable MyModule using the short-hand
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:EnableModule("MyModule")
function mixins.EnableModule(addon, name)
	local module = addon:GetModule( name )
	return module:Enable()
end

--- Disables the Module, if possible, return true or false depending on success.
-- Short-hand function that retrieves the module via `:GetModule` and calls `:Disable` on the module object.
-- @name //addon//:DisableModule
-- @paramsig name
-- @usage 
-- -- Disable MyModule using :GetModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("MyModule")
-- MyModule:Disable()
--
-- -- Disable MyModule using the short-hand
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:DisableModule("MyModule")
function mixins.DisableModule(addon, name)
	local module = addon:GetModule( name )
	return module:Disable()
end

--- Set the default libraries to be mixed into all modules created by this object.
-- Note that you can only change the default module libraries before any module is created.
-- @name //addon//:SetDefaultModuleLibraries
-- @paramsig lib[, lib, ...]
-- @param lib List of libraries to embed into the addon
-- @usage 
-- -- Create the addon object
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
-- -- Configure default libraries for modules (all modules need AceEvent-3.0)
-- MyAddon:SetDefaultModuleLibraries("AceEvent-3.0")
-- -- Create a module
-- MyModule = MyAddon:NewModule("MyModule")
function mixins.SetDefaultModuleLibraries(addon, ...)
	if next(addon.modules) then
		error("Usage: SetDefaultModuleLibraries(...): cannot change the module defaults after a module has been registered.", 2)
	end
	addon.defaultModuleLibraries = {...}
end

--- Set the default state in which new modules are being created.
-- Note that you can only change the default state before any module is created.
-- @name //addon//:SetDefaultModuleState
-- @paramsig state
-- @param state Default state for new modules, true for enabled, false for disabled
-- @usage 
-- -- Create the addon object
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
-- -- Set the default state to "disabled"
-- MyAddon:SetDefaultModuleState(false)
-- -- Create a module and explicilty enable it
-- MyModule = MyAddon:NewModule("MyModule")
-- MyModule:Enable()
function mixins.SetDefaultModuleState(addon, state)
	if next(addon.modules) then
		error("Usage: SetDefaultModuleState(state): cannot change the module defaults after a module has been registered.", 2)
	end
	addon.defaultModuleState = state
end

--- Set the default prototype to use for new modules on creation.
-- Note that you can only change the default prototype before any module is created.
-- @name //addon//:SetDefaultModulePrototype
-- @paramsig prototype
-- @param prototype Default prototype for the new modules (table)
-- @usage 
-- -- Define a prototype
-- local prototype = { OnEnable = function(module) print("OnEnable called!") end }
-- -- Set the default prototype
-- MyAddon:SetDefaultModulePrototype(prototype)
-- -- Create a module and explicitly Enable it
-- MyModule = MyAddon:NewModule("MyModule")
-- MyModule:Enable()
-- -- should print "OnEnable called!" now
-- @see NewModule
function mixins.SetDefaultModulePrototype(addon, prototype)
	if next(addon.modules) then
		error("Usage: SetDefaultModulePrototype(prototype): cannot change the module defaults after a module has been registered.", 2)
	end
	if prototype and type(prototype) ~= 'table' and type(prototype) ~= 'function' then
		error( format("Usage: SetDefaultModulePrototype(prototype): `prototype` - table expected got '%s'.", type(prototype)), 2 )
	end
	addon.defaultModulePrototype = prototype
end

--- Set the state of an addon or module
-- This should only be called before any enabling actually happend, e.g. in/before OnInitialize.
-- @name //addon//:SetEnabledState
-- @paramsig state
-- @param state the state of an addon or module  (enabled=true, disabled=false)
function mixins.SetEnabledState(addonOrModule, state)
	addonOrModule.enabledState = state
end


--- Return an iterator of all modules associated to the addon.
-- @name //addon//:IterateModules
-- @paramsig 
-- @usage 
-- -- Enable all modules
-- for name, module in MyAddon:IterateModules() do
--    module:Enable()
-- end
function mixins.IterateModules(addon) return pairs(addon.modules) end

-- Returns an iterator of all embeds in the addon
-- @name //addon//:IterateEmbeds
-- @paramsig 
function mixins.IterateEmbeds(addonOrModule) return pairs(AceAddon.embeds[addonOrModule]) end

--- Query the enabledState of an addon.
-- @name //addon//:IsEnabled
-- @paramsig 
-- @usage 
-- if MyAddon:IsEnabled() then
--     MyAddon:Disable()
-- end
function mixins.IsEnabled(addonOrModule) return addonOrModule.enabledState end

function mixins.SetAddonEnv(addonOrModule, addonName, env)
	addonOrModule.folderName = addonName
	addonOrModule._ENV = env
	return addonOrModule    -- for method chaining
end



local pmixins = {
	defaultModuleState = true,
	enabledState = true,
	IsModule = ReturnFalse,
}
-- Embed( target )
-- target (object) - target object to embed aceaddon in
--
-- this is a local function specifically since it's meant to be only called internally
function Embed(target, skipPMixins)
	for k, v in pairs(mixins) do
		target[k] = v
	end
	if not skipPMixins then
		for k, v in pairs(pmixins) do
			target[k] = target[k] or v
		end
	end
end


-- - Initialize the addon after creation.
-- This function is only used internally during the ADDON_LOADED event
-- It will call the **OnInitialize** function on the addon object (if present), 
-- and the **OnEmbedInitialize** function on all embedded libraries.
-- 
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
-- @param addon addon object to intialize
function AceAddon:InitializeAddon(addon)
	safecall(addon.OnInitialize, addon)
	
	local embeds = self.embeds[addon]
	for i = 1, #embeds do
		local lib = LibStub:GetLibrary(embeds[i], true)
		if lib then safecall(lib.OnEmbedInitialize, lib, addon) end
	end
	
	-- we don't call InitializeAddon on modules specifically, this is handled
	-- from the event handler and only done _once_
end

-- - Enable the addon after creation.
-- Note: This function is only used internally during the PLAYER_LOGIN event, or during ADDON_LOADED,
-- if IsLoggedIn() already returns true at that point, e.g. for LoD Addons.
-- It will call the **OnEnable** function on the addon object (if present), 
-- and the **OnEmbedEnable** function on all embedded libraries.\\
-- This function does not toggle the enable state of the addon itself, and will return early if the addon is disabled.
--
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
-- Use :Enable on the addon itself instead.
-- @param addon addon object to enable
function AceAddon:EnableAddon(addon)
	if type(addon) == "string" then addon = AceAddon:GetAddon(addon) end
	local addonName = addon.name
	if  DEBUG and DEBUG[addonName]  then  print( "AceAddon:EnableAddon("..addonName.."): status="..tostring(self.statuses[addonName]).." enabledState="..tostring(addon.enabledState) )  end
	if self.statuses[addonName] or not addon.enabledState then return false end
	
	-- set the statuses first, before calling the OnEnable. this allows for Disabling of the addon in OnEnable.
	self.statuses[addonName] = true
	
	safecall(addon.OnEnable, addon)
	
	-- make sure we're still enabled before continueing
	if self.statuses[addonName] then
		local embeds = self.embeds[addon]
		for i = 1, #embeds do
			local lib = LibStub:GetLibrary(embeds[i], true)
			if lib then safecall(lib.OnEmbedEnable, lib, addon) end
		end
	
		-- enable possible modules.
		local modules = addon.orderedModules
		for i = 1, #modules do
			self:EnableAddon(modules[i])
		end
	end
	return self.statuses[addonName] -- return false if we're disabled
end

-- - Disable the addon
-- Note: This function is only used internally.
-- It will call the **OnDisable** function on the addon object (if present), 
-- and the **OnEmbedDisable** function on all embedded libraries.\\
-- This function does not toggle the enable state of the addon itself, and will return early if the addon is still enabled.
--
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing. 
-- Use :Disable on the addon itself instead.
-- @param addon addon object to enable
function AceAddon:DisableAddon(addon)
	if type(addon) == "string" then addon = AceAddon:GetAddon(addon) end
	local addonName = addon.name
	if not self.statuses[addonName] then return false end
	
	-- set statuses first before calling OnDisable, this allows for aborting the disable in OnDisable.
	self.statuses[addonName] = false
	
	safecall( addon.OnDisable, addon )
	
	-- make sure we're still disabling...
	if not self.statuses[addonName] then 
		local embeds = self.embeds[addon]
		for i = 1, #embeds do
			local lib = LibStub:GetLibrary(embeds[i], true)
			if lib then safecall(lib.OnEmbedDisable, lib, addon) end
		end
		-- disable possible modules.
		local modules = addon.orderedModules
		for i = 1, #modules do
			self:DisableAddon(modules[i])
		end
	end
	
	return not self.statuses[addonName] -- return true if we're disabled
end

--- Get an iterator over all registered addons.
-- @usage 
-- -- Print a list of all installed AceAddon's
-- for name, addon in AceAddon:IterateAddons() do
--   print("Addon: " .. name)
-- end
function AceAddon:IterateAddons() return pairs(self.addons) end

--- Get an iterator over the internal status registry.
-- @usage 
-- -- Print a list of all enabled addons
-- for name, status in AceAddon:IterateAddonStatus() do
--   if status then
--     print("EnabledAddon: " .. name)
--   end
-- end
function AceAddon:IterateAddonStatus() return pairs(self.statuses) end

-- Following Iterators are deprecated, and their addon specific versions should be used
-- e.g. addon:IterateEmbeds() instead of :IterateEmbedsOnAddon(addon)
function AceAddon:IterateEmbedsOnAddon(addon) return pairs(self.embeds[addon]) end
function AceAddon:IterateModulesOfAddon(addon) return pairs(addon.modules) end


-- Event Handling
local function OnEvent(frame, event, addonName)
	if  event == "ADDON_LOADED"  then
		-- 2011-08-17 nevcairiel - ignore the load event of Blizzard_DebugTools, so a potential startup error isn't swallowed up
		-- if  addonName == "Blizzard_DebugTools"  then  return  end
		if  addonName:sub(1,9) == "Blizzard_"  then  return  end
		-- If an addon loads another addon, recursion could happen here, so we need to validate the table on every iteration.
		-- If another addon is loaded in main chunk (not from an event handler) then  initializequeue = { NewAddon()s before LoadAddOn(), otheraddon's NewAddon()s }
		-- addonName == 'otheraddon' as the other addon finished loading before the first one.
		-- Now initializequeue will initialize the first addon too, although its SavedVariables are not loaded yet.
		-- This could be detected only by rawhooking LoadAddOn(). There is no issue with LoadAddOn() in OnInitialize().
	end
	
	if  event == "ADDON_LOADED"  or  event == "PLAYER_LOGIN"  then
		while(#AceAddon.initializequeue > 0) do
			local addon = tremove(AceAddon.initializequeue, 1)
			-- this might be an issue with recursion - TODO: validate
			
			if event == "ADDON_LOADED" then
				-- addon.folderName == addon.baseName == addonName expected
				if  addonName ~= addon.folderName  and   addon.folderName  then
					print(event.."("..addonName.."): addon.folderName="..addon.folderName)
				end
				addon.baseName = addonName
			end
			
			AceAddon:InitializeAddon(addon)
			
			if  _G.IsLoggedIn()  and  #AceAddon.enablequeue == 0  then  frame:Show()  end
			tinsert(AceAddon.enablequeue, addon)
		end
	end
	
	-- Start processing enablequeue.
	if  event == "PLAYER_LOGIN"  then  frame:Show()  end
	
end

local GetTime, debugprofilestop, strjoin = GetTime, debugprofilestop, strjoin

-- Throttled enabling of addons.
local function OnUpdate(frame, elapsed)
	frame.minElapsed = min(elapsed, frame.minElapsed or elapsed)
	frame.maxElapsed = max(elapsed, frame.maxElapsed or elapsed)
	frame.totalElapsed = (frame.totalElapsed or 0) + elapsed
	if  not _G.IsLoggedIn()  then  return  end
	frame.frameCount = (frame.frameCount or 0) + 1
	if  frame.frameCount < 10  then  return  end
	
	local timeLog = AceAddon.addonEnableTimeLog
	local times = AceAddon.addonEnableTimes
	local frameStart = debugprofilestop()
	local thisRound = {}
	
	if  not frame.batchStart  then
		frame.batchStart = frameStart
		frame.batchFrame = frame.frameCount
		print(format("AceAddon started processing enablequeue at %.3f", GetTime()))
	end
	
	while  0 < #AceAddon.enablequeue  do
		local before = debugprofilestop()
		local addon = tremove(AceAddon.enablequeue, 1)
		local addonName = addon.name
		thisRound[#thisRound+1] = addonName
		AceAddon:EnableAddon(addon)
		
		local after = debugprofilestop()
		if  timeLog  then  timeLog[#timeLog+1] = format("%s: %.1f ms", addonName, after - before)  end
		if  times  then  times[addonName] = after - before  end
		
		-- 30 fps = 33.3 ms/f
		local timeLimit = 0.5  -- milisec
		-- local timeLimit = frame.minElapsed/32
		if  after - frameStart > timeLimit  then
			print(format( "AceAddon enabled addons in one frame, %.1f ms:  %s", after - frameStart, strjoin(",", unpack(thisRound)) ))
			return
		end
	end
	
  -- Stop receiving OnUpdate.
	local msg = format("AceAddon.enablequeue finished at %.3f after %.3f seconds, %d frames", GetTime(), debugprofilestop()/1000 - frame.batchStart/1000, frame.frameCount - frame.batchFrame)
	if  timeLog  then  timeLog[#timeLog+1] = msg  end
	print(msg)
	frame:Hide()
end


AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
AceAddon.frame:SetScript("OnEvent", OnEvent)
AceAddon.frame:SetScript("OnUpdate", OnUpdate)
AceAddon.frame:Show()

-- upgrade embedded
for name, addon in pairs(AceAddon.addons) do
	Embed(addon, true)
end

-- 2010-10-27 nevcairiel - add new "orderedModules" table
if oldminor and oldminor < 10 then
	for name, addon in pairs(AceAddon.addons) do
		addon.orderedModules = {}
		for module_name, module in pairs(addon.modules) do
			tinsert(addon.orderedModules, module)
		end
	end
end


