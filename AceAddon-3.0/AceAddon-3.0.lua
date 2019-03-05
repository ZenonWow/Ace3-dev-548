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
local G, LibStub = _G, LibStub
local AceAddon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not AceAddon then return end -- No Upgrade needed.


-- Export to G:  AceAddon3
G.AceAddon3 = AceAddon

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


-- Export to LibShared:  AutoTablesMeta, errorhandler, softassert, safecall/safecallDispatch
local LibShared = G.LibShared or {}  ;  G.LibShared = LibShared
LibShared.istype2 = LibShared.istype2 or  function(value, t1, t2, t3)
	local t=type(value)  ;  if t==t1 or t==t2 then return value or true end  ;  return nil
end

-- AutoTablesMeta: metatable that automatically creates empty inner tables when keys are first referenced.
LibShared.AutoTablesMeta = LibShared.AutoTablesMeta or { __index = function(self, key)  if key ~= nil then  local v={} ; self[key]=v ; return v  end  end }

-- Allow hooking G.geterrorhandler(): don't cache/upvalue it or the errorhandler returned.
-- Call through errorhandler() local, thus the errorhandler() function name is printed in stacktrace, not just a line number.
-- Also avoid tailcall with select(1,...). A tailcall would show LibShared.errorhandler() function as "?" in stacktrace, making it harder to identify.
LibShared.errorhandler = LibShared.errorhandler or  function(errorMessage)  local errorhandler = G.geterrorhandler() ; return select( 1, errorhandler(errorMessage) )  end

--- LibShared. softassert(condition, message):  Report error, then continue execution, _unlike_ assert().
LibShared.softassert = LibShared.softassert  or  function(ok, message)  return ok, ok or G.geterrorhandler()(message)  end

local istype2,AutoTablesMeta,errorhandler,softassert = LibShared.istype2, LibShared.AutoTablesMeta, LibShared.errorhandler, LibShared.softassert



if  select(4, G.GetBuildInfo()) >= 80000  then

	----------------------------------------
	--- Battle For Azeroth Addon Changes
	-- https://us.battle.net/forums/en/wow/topic/20762318007
	-- • xpcall now accepts arguments like pcall does
	--
	LibShared.safecall = LibShared.safecall or  function(unsafeFunc, ...)  return xpcall(unsafeFunc, errorhandler, ...)  end

elseif not LibShared.safecallDispatch then

	-- Export  LibShared.safecallDispatch
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
		-- Pass a delegating errorhandler to avoid G.geterrorhandler() function call before any error actually happens.
		return xpcall(unsafeFunc, errorhandler)
		-- Or pass the registered errorhandler directly to avoid inserting an extra callstack frame.
		-- The errorhandler is expected to be the same at both times: callbacks usually don't change it.
		--return xpcall(unsafeFunc, G.geterrorhandler())
	end

	function LibShared.safecallDispatch(unsafeFunc, ...)
		-- we check to see if unsafeFunc is actually a function here and don't error when it isn't
		-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
		-- present execution should continue without hinderance
		if  not unsafeFunc  then  return  end
		if  type(unsafeFunc)~='function'  then
			LibShared.softassert(false, "Usage: safecall(unsafeFunc):  function expected, got "..type(unsafeFunc))
			return
		end

		local dispatcher = SafecallDispatchers[select('#',...)]
		-- Can't avoid tailcall without inefficiently packing and unpacking the multiple return values.
		return dispatcher(unsafeFunc, ...)
	end

end -- LibShared.safecallDispatch




-- Choose the safecall implementation to use.
local safecall = LibShared.safecall or LibShared.safecallDispatch
-- Forward declaration
local Embed
-- Client mixin methods refactored to AceAddon.mixin
-- local Enable, Disable, EnableModule, DisableModule, NewModule, GetModule, GetName, SetDefaultModuleState, SetDefaultModuleLibraries, SetEnabledState, SetDefaultModulePrototype



AceAddon.addons = AceAddon.addons or {}                                -- Registered addon objects:  name -> addon  map.
AceAddon.mixin  = AceAddon.mixin or {}                                -- Methods embedded in clients (registered addons).
local mixin     = AceAddon.mixin
AceAddon.embeds = setmetatable(AceAddon.embeds or {}, AutoTablesMeta)  -- AceAddon.embeds[moduleObj] == a list of libraries embedded in a module.
AceAddon.statuses = AceAddon.statuses or {} -- Module name -> enabled (boolean). true if :OnEnable() was called,  false if not, or :OnDisable() was called,  nil if module was not initialized yet.
AceAddon.enabling = AceAddon.enabling or {} -- Modules in the process of enabling/disabling.  AceAddon.enabling[moduleObj] == 'OnEnable' / 'OnDisable' when the callback is called.
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
--
function AceAddon:NewAddon(objectorname, ...)
	local firstLib,moduleObj,name
	if type(objectorname) ~= 'table'
	then  firstLib,moduleObj,name = 1, {}, objectorname
	else  firstLib,moduleObj,name = 2, objectorname, ...
	end

	if type(name)~="string" then
		error( "Usage: AceAddon:NewAddon([addon,] name, [lib, lib, lib, ...]): `name` - string expected, got "..type(name), 2 )
	end
	if self.addons[name] then 
		error( format("Usage: AceAddon:NewAddon([addon,] name, [lib, lib, lib, ...]): `name` - Addon '%s' already exists.", name), 2 )
	end

	-- Fix:  :NewAddon( { enabledState = false }, "MyAddon", ...)  overwriting enabledState with `true`.
	if moduleObj.enabledState==nil then  moduleObj.enabledState = true  end
	moduleObj.fullName = name
	moduleObj.name = name
	self:_InitModuleObj(moduleObj)
	AceAddon:EmbedLibraries(moduleObj, select(firstLib,...))
	return moduleObj
end


--- Create a new submodule for the addon.
-- The new module can have its own embedded libraries and/or use a module prototype to be mixed into the module.\\
-- A module has the same functionality as a real addon, it can have submodules of its own, and has the same API as
-- an addon object.
-- @name //moduleObj//:NewModule
-- @paramsig name[, prototype|lib[, lib, ...]]
-- @param name unique name of the module
-- @param prototype object to derive this module from, methods and values from this table will be mixed into the module (optional)
-- @param lib List of libraries to embed into the addon
-- @usage 
-- -- Create a module with some embedded libraries
-- MyModule = MyAddon:NewModule("<ModuleName>", "AceEvent-3.0", "AceHook-3.0")
-- 
-- -- Create a module with a prototype
-- local prototype = { OnEnable = function(module) print("OnEnable called!") end }
-- MyModule = MyAddon:NewModule("<ModuleName>", prototype, "AceEvent-3.0", "AceHook-3.0")
--
function mixin.NewModule(parentModule, moduleName, ...)
	local prototype = ...
	local prototypeSet =  1 <= select('#',...)  and  type(prototype) ~= 'string'
	if type(moduleName)~='string' then
		error( "Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]): `moduleName` - string expected, got "..type(moduleName) , 2 )
	end
	if prototypeSet and not istype2(prototype, 'table', 'function') then
		error( "Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]): `prototype` - table/function/nil (prototype), string (lib) expected, got "..type(prototype) , 2 )
	end
	if parentModule.modules and parentModule.modules[moduleName] then
		error( 'Usage: MyAddon:NewModule(moduleName, [prototype, [lib, lib, lib, ...]):  Submodule "'..moduleName..'" already exists.', 2 )
	end

	local moduleObj = { moduleName = moduleName, parentModule = parentModule }
	moduleObj.enabledState = parentModule.defaultModuleState
	-- SetEnabledState(moduleObj, parentModule.defaultModuleState)
	moduleObj.fullName = (parentModule.name or tostring(parentModule)).."_"..moduleName
	-- Historically .name stores fullName.
	moduleObj.name = moduleObj.fullName

	-- Addons and modules are basically the same. Modules will be added to the initializequeue as well.
	-- NewModule can only be called after the parent addon is added thus the modules will be initialized after their parent is.
	AceAddon:_InitModuleObj(moduleObj)
	AceAddon:EmbedLibraries(moduleObj, select(prototypeSet and 2 or 1,...) )
	if parentModule.defaultModuleLibraries then
		AceAddon:EmbedLibraries(moduleObj, unpack(parentModule.defaultModuleLibraries))
	end

	-- if not prototype or type(prototype) == "string" then
	if not prototypeSet then
		prototype = parentModule.defaultModulePrototype or nil
	end

	-- if type(prototype) == "table" then
	if prototype ~= nil then
		-- meta.__index == nil after _InitModuleObj()
		local meta = getmetatable(moduleObj)
		meta.__index = prototype
		-- setmetatable(moduleObj, meta)  -- More of a Base class type feel.
	end

	-- Create submodule tables lazily when adding first module.
	parentModule.modules = parentModule.modules or {}
	parentModule.modules[moduleName] = moduleObj
	parentModule.orderedModules = parentModule.orderedModules or {}
	tinsert(parentModule.orderedModules, moduleObj)

	safecall(parentModule.OnModuleCreated, parentModule, moduleObj) -- Was in Ace2 and I think it could be a cool thing to have handy.

	return moduleObj
end




-- used in the addon metatable
local function moduleToString(moduleObj)  return moduleObj.name  end 


-- NewAddon/NewModule common part.
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
--
function AceAddon:_InitModuleObj(moduleObj)
  -- 0:_InitModuleObj, 1:NewAddon/NewModule, 2:<caller>
	local stackFramesUp = 2
	self.DetermineAddonFolder(stackFramesUp, moduleObj)

	-- Give a new metatable to the module to guarantee it is unique.
	local moduleMeta = {}
	local oldMeta = getmetatable(moduleObj)
	if oldMeta then
		for k, v in pairs(oldMeta) do moduleMeta[k] = v end
	end
	moduleMeta.__tostring = moduleToString
	setmetatable(moduleObj, moduleMeta)

	self.addons[moduleObj.fullName] = moduleObj
	-- Fix:  :NewAddon( { enabledState = false, defaultModuleState = false }, "MyAddon", ...)  overwriting enabledState, defaultModuleState with `true`.
	-- SetDefaults(moduleObj, ModuleObjDefaults)
	if moduleObj.defaultModuleState == nil then  moduleObj.defaultModuleState = true  end
	Embed(moduleObj) -- embed NewModule, GetModule methods

	-- Create submodule tables lazily when adding first module.
	-- moduleObj.modules = {}
	-- moduleObj.orderedModules = {}
	-- moduleObj.defaultModuleLibraries = {}

  -- Create queue if this is a recursively loaded addon.
	self.initializequeue = self.initializequeue or {}
	-- Add to queue of addons to be initialized upon ADDON_LOADED.
	tinsert(self.initializequeue, moduleObj)
	return moduleObj
end


function AceAddon.DetermineAddonFolder(stackFramesUp, moduleObj)
  -- 0:debugstack, 1:DetermineAddonFolder, 2:_InitModuleObj, 3:NewAddon/NewModule, 4:<caller>
	local callDepth = (stackFramesUp or 0) + 2
	local callerStack = G.debugstack(callDepth, 3, 0)  -- read 3 frames to allow for tailcails (no filepath in those)
	-- Parse the addon's folder name in  Interface\AddOns\  folder.
	local addonFolder = callerStack and callerStack:match([[Ons\(.-)\]])
	if not moduleObj then  return addonFolder  end    -- External call, no addon / module object, just return addonFolder.

	moduleObj.addonFolder = addonFolder
	if not G.DEVMODE then    -- Only report in DEVMODE.
	elseif not addonFolder then
		local AceAddonFunc =  (moduleObj.moduleName and "NewModule" or "NewAddon")
		G.geterrorhandler()("    AceAddon:"..AceAddonFunc.."(name = '"..moduleObj.name.."'):  can't determine addonFolder from debugstack("..callDepth..", 3, 0):\n"..tostring(callerStack))
	end
	return addonFolder
end


--- Usage:  local addonName = MyAddon:GetRealAddonName()
-- @return  the addonName recognized by bliz apis like GetAddOnInfo(), IsAddOnLoaded()
--
function mixin:GetRealAddonName()
	-- Earlier revisions set only .baseName based on ADDON_LOADED event's parameter.
  return  self.realAddonName or self.folderName or self.baseName
end

--- Usage:  local <Name> = MyAddon:NewAddon("<Name>", libs...):SetRealAddonName(ADDON_NAME)    -- Chainable.
--- Usage:  local <ModuleName> = MyAddon:NewModule("<ModuleName>", libs...):SetRealAddonName(ADDON_NAME)    -- Chainable.
--
function mixin:SetRealAddonName(realAddonName)
  self.realAddonName = realAddonName
	-- Historically the parameter of ADDON_LOADED event is saved to baseName. Have seen only one addon using it: Prat-3.0.
	-- Deprecated, use :GetRealAddonName() instead.
	self.baseName = realAddonName
	return self
end


--- Get the addon/module object by its fullName from the AceAddon registry.
-- Throws an error if the addon object cannot be found (except if silent is set).
-- @param fullName  name of the addon object set by :NewAddon(),  or for submodules:  name of parentModule + '_' + name of module set by :NewModule()
-- @param silent if true, the addon is optional, silently return nil if its not found
-- @usage 
-- -- Get the Addon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- -- Short version:
-- MyAddon = G.AceAddon3('MyAddon')
-- -- Short silent version (returns nil if not found):
-- MyAddon = G.AceAddon3.MyAddon
--
function AceAddon:GetAddon(fullName, silent)
	if not silent and not self.addons[fullName] then
		error( "Usage: GetAddon(fullName): `fullName` - Cannot find the module '"..tostring(fullName).."'.", 2 )
	end
	return self.addons[fullName]
end


--- Global shorthand to access addons, similar to LibStub's. Examples:
-- G.AceAddon3('Prat-3.0'), G.AceAddon3('Dominos'), etc.
-- G.AceAddon3.Dominos, etc.
--
setmetatable(AceAddon, { __call = AceAddon.GetAddon, __index = AceAddon.addons })

--- Embed a list of libraries into the specified addon.
-- This function will try to embed all of the listed libraries into the addon
-- and error if a single one fails.
--
-- **Note:** This function is for internal use by :NewAddon/:NewModule
-- @paramsig moduleObj, [lib, ...]
-- @param moduleObj object to embed the libs in
-- @param lib List of libraries to embed into the addon
--
function AceAddon:EmbedLibraries(moduleObj, ...)
	for i = 1,select('#',...) do
		local libname = select(i, ...)
		-- -2:error(), -1:EmbedLibrary, 0:EmbedLibraries, 1:NewAddon/NewModule, 2:caller
		self:EmbedLibrary(moduleObj, libname, false, 2)
	end
end


--- Embed a library into the addon object.
-- This function will check if the specified library is registered with LibStub
-- and if it has a :Embed function to call. It'll error if any of those conditions
-- fails.
--
-- **Note:** This function is for internal use by :EmbedLibraries
-- @paramsig addon, libname[, silent[, offset]]
-- @param addon addon object to embed the library in
-- @param libname name of the library to embed
-- @param silent marks an embed to fail silently if the library doesn't exist (optional)
-- @param callDepth will push the error messages back to said offset, defaults to 0 (optional)
--
function AceAddon:EmbedLibrary(moduleObj, libname, silent, callDepth)
	local lib = LibStub:GetLibrary(libname, true)
	if not lib and not silent then
		-- 0:error(), 1:EmbedLibrary, 2:EmbedLibraries/caller, 3:NewAddon/NewModule, 4:caller
		error( format("Usage: EmbedLibrary(moduleObj, libname, silent, offset): `libname` - Cannot find a library instance of %q.", tostring(libname)), (callDepth or 0)+2 )
	elseif lib and type(lib.Embed) == "function" then
		lib:Embed(moduleObj)
		tinsert(self.embeds[moduleObj], libname)
		return true
	elseif lib then
		error( "Usage: EmbedLibrary(moduleObj, libname, silent, offset): `libname` - Library '"..tostring(libname).."' is not Embed capable", (callDepth or 0)+2 )
	end
end




--- Return the specified submodule from an addon object.
-- Throws an error if the addon object cannot be found (except if silent is set)
-- @name //moduleObj//:GetModule
-- @paramsig name[, silent]
-- @param name unique name of the module
-- @param silent if true, the module is optional, silently return nil if its not found (optional)
-- @usage 
-- -- Get the Addon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- -- Get the Module
-- MyModule = MyAddon:GetModule("<ModuleName>")
--
function mixin.GetModule(parentModule, moduleName, silent)
	if not parentModule.modules[moduleName] and not silent then
		error( "Usage: MyAddon:GetModule(moduleName, silent): `moduleName` - Cannot find submodule '"..tostring(name).."'.", 2 )
	end
	return parentModule.modules[moduleName]
end


--- Returns the name of the submodule in parent module's namespace (or name of root module): without prefixing parentModule's name.
-- @name //moduleObj//:GetName
-- @usage 
-- print(MyAddon:GetName())
-- -- prints "MyAddon"
function mixin.GetName(moduleObj)
	return moduleObj.moduleName or moduleObj.name
end


--- Query the enabledState of a module. True, if you want the module to be active.
-- Returning enabledState has confused some addon developers:
--   Bazooka:OnEnable(), :profileChanged() -> self:init() -> self:applySettings()
--     ->  if not self:IsEnabled() then  self:OnDisable() ; return  end  -- Disable if not enabled... dead code, actually:
--         OnEnable() is only called when state and status are both true, profileChanged() checks `.enabled`.
--
-- Checking status[moduleObj.name] would be preferable for:  -> use moduleObj:HasBeenEnabled()
--   Bazooka:OnEnable() tracks self.enabled,  this is redundant with  status[moduleObj.name].
--   Chatter/Modules/EditboxHistory.lua -> prefers AceAddon.statuses[moduleObj.fullName] = true _after_ OnEnable()
--   Prat/addon/addon.lua:  addon:UpdateProfileDelayed() -> should use moduleObj:ReEnable()
--   Bartender4:  If  Bartender4:UpdateModuleConfigs()  ran before PLAYER_LOGIN then it would call :ApplyConfig() on not-yet enabled modules.
--
-- Addons that use it after PLAYER_LOGIN enabled addons, therefore there is no difference, enabledState == status[moduleObj.name].
--   AdiBags, Chatter:UpdateConfig(), InspectEquip, Watcher
--   TellMeWhen/../Announcements.lua ?
--   Prat/addon/modules.lua # prototype.IsDisabled() - not used.
--
-- Addons that expect it to return enabledState:
--   Bartender4:  modulePrototype:ToggleOptions() expects :IsEnabled() == false in :OnDisable()
--   Bartender4:  modules' :SetupOptions() expects :IsEnabled() == true in Bartender4:OnInitialize()
--   Quartz/modules/* # :ApplySettings() expects :IsEnabled() == true in :OnEnable()
--
-- @usage 
-- if MyAddon:IsEnabled() then
--     MyAddon:Disable()
-- end
-- 
function mixin.IsEnabled(moduleObj)  return moduleObj.enabledState  end


--- Query the actual status of a module.
-- @return  true  if the module was actually enabled: OnEnable() was called.
-- @return  false  if OnEnable() was not called yet,  or OnDisable() was called last.
-- @return  nil  if it was not initialized yet.
-- @name //moduleObj//:HasBeenEnabled
-- Do not confuse with IsEnabled():  common practice calls this IsEnabled() and that GetEnabledState(). For compatibility this has been named HasBeenEnabled(). Or for the rhimes.
function mixin.HasBeenEnabled(moduleObj)  return AceAddon.statuses[moduleObj.fullName]  end


--- Returns true if this is a submodule of another (parent) module.
-- @name //moduleObj//:GetName
-- @usage 
-- print(MyAddon:GetName())
-- -- prints "MyAddon"
function mixin.IsModule(moduleObj)
	return nil~=moduleObj.parentModule
end


--- Sets the `moduleObj.enabledState` variable to `enable`, then enables/disables the module,
-- calling the :OnEnable() / :OnDisable() callback on it and its submodules.
--
-- Safe to call :Enable(false) from :OnEnable() to abort/reject enabling the module.
-- :Enable(true) is safe too, it avoids infinite recursion and returns after setting
-- .enabledState to the provided value which can be a string, or number to mark a specific enabledState.
--
-- @return  true  if the disabled->enabled / enabled->disabled transition actually happened.
-- If the module was not initialized yet, enabling will happen later, in response to PLAYER_LOGIN event.
-- DoInitQueue() queues it for enabling after ADDON_LOADED event.
--
-- @name //moduleObj//:Enable
-- @usage 
-- -- Enable MyModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("<ModuleName>")
-- MyModule:Enable()
--
function mixin.Enable(moduleObj, enable)
	enable =  enable==nil  and  true  or  not not enable	-- Make it strictly boolean.
	moduleObj:SetEnabledState(enable)
	return AceAddon:EnableAddon(moduleObj, enable)
end


--- Disables the module, if possible. Returns true if the enabled -> disabled transition actually happened.
-- This internally calls AceAddon:DisableAddon(), thus dispatching the :OnDisable() callback.
-- and then disabling all modules of the addon.
-- :Disable() also sets the internal `enabledState` variable to false
-- @name //moduleObj//:Disable
-- @usage 
-- -- Disable MyAddon
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:Disable()
--
function mixin.Disable(moduleObj)
	return mixin.Enable(moduleObj, false)
end


--- Disables then enables the module, without changing `.enabledState`. Calls :OnDisable(), then :OnEnable() on the module and its submodules.
-- @return  false  if the module was not enabled,  true  if it has been reenabled.
-- @name //moduleObj//:ReEnable
--
function mixin.ReEnable(moduleObj)
	local wasEnabled = AceAddon.statuses[moduleObj.fullName]
	if not wasEnabled then  return false  end

	AceAddon:EnableAddon(moduleObj, false)
	-- wasEnabled can be non-boolean.
	AceAddon:EnableAddon(moduleObj, wasEnabled)
	return true
end


--- Enables the submodule, if possible, return true or false depending on success.
-- Short-hand function that :Enable()s a module by name.
-- @name //moduleObj//:EnableModule
-- @paramsig name, enable
-- @param enable  false to disable,  truthy value to enable
-- @usage 
-- -- Enable MyModule using :GetModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("<ModuleName>")
-- MyModule:Enable()
--
-- -- Enable MyModule using the short-hand
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:EnableModule("<ModuleName>")
--
function mixin.EnableModule(parentModule, name, enable)
	local submoduleObj = parentModule:GetModule(name)
	return submoduleObj:Enable(enable)
end


--- Disables the submodule, if possible, return true or false depending on success.
-- Short-hand function that :Disable()s a module by name.
-- @name //moduleObj//:DisableModule
-- @paramsig name
-- @usage 
-- -- Disable MyModule using :GetModule
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyModule = MyAddon:GetModule("<ModuleName>")
-- MyModule:Disable()
--
-- -- Disable MyModule using the short-hand
-- MyAddon = LibStub("AceAddon-3.0"):GetAddon("MyAddon")
-- MyAddon:DisableModule("<ModuleName>")
--
function mixin.DisableModule(parentModule, name)
	return mixin.EnableModule(parentModule, name, false)
end


--- Set the default libraries to be mixed into all modules created by this object.
-- Note that you can only change the default module libraries before any module is created.
-- @name //moduleObj//:SetDefaultModuleLibraries
-- @paramsig lib[, lib, ...]
-- @param lib List of libraries to embed into the addon
-- @usage 
-- -- Create the addon object
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
-- -- Configure default libraries for modules (all modules need AceEvent-3.0)
-- MyAddon:SetDefaultModuleLibraries("AceEvent-3.0")
-- -- Create a module
-- MyModule = MyAddon:NewModule("<ModuleName>")
--
function mixin.SetDefaultModuleLibraries(parentModule, ...)
	if parentModule.modules and next(parentModule.modules) then
		error("Usage: SetDefaultModuleLibraries(...): cannot change the module defaults after a module has been registered.", 2)
	end
	parentModule.defaultModuleLibraries = {...}
end


--- Set the default state in which new modules are being created.
-- Note that you can only change the default state before any module is created.
-- @name //moduleObj//:SetDefaultModuleState
-- @paramsig state
-- @param state Default state for new modules, true for enabled, false for disabled
-- @usage 
-- -- Create the addon object
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon")
-- -- Set the default state to "disabled"
-- MyAddon:SetDefaultModuleState(false)
-- -- Create a module and explicitly enable it
-- MyModule = MyAddon:NewModule("<ModuleName>")
-- MyModule:Enable()
--
function mixin.SetDefaultModuleState(parentModule, state)
	if parentModule.modules and next(parentModule.modules) then
		error("Usage: SetDefaultModuleState(state): cannot change the module defaults after a module has been registered.", 2)
	end
	parentModule.defaultModuleState = state
end


--- Set the default prototype to use for new modules on creation.
-- Note that you can only change the default prototype before any module is created.
-- @name //moduleObj//:SetDefaultModulePrototype
-- @paramsig prototype
-- @param prototype Default prototype for the new modules (table)
-- @usage 
-- -- Define a prototype
-- local prototype = { OnEnable = function(module) print("OnEnable called!") end }
-- -- Set the default prototype
-- MyAddon:SetDefaultModulePrototype(prototype)
-- -- Create a module and explicitly Enable it
-- MyModule = MyAddon:NewModule("<ModuleName>")
-- MyModule:Enable()
-- -- should print "OnEnable called!" now
-- @see NewModule
--
function mixin.SetDefaultModulePrototype(parentModule, prototype)
	if parentModule.modules and next(parentModule.modules) then
		error("Usage: SetDefaultModulePrototype(prototype): cannot change the module defaults after a module has been registered.", 2)
	end
	if prototype and type(prototype) ~= 'table' and type(prototype) ~= 'function' then
		error( format("Usage: SetDefaultModulePrototype(prototype): `prototype` - table expected got '%s'.", type(prototype)), 2 )
	end
	parentModule.defaultModulePrototype = prototype
end


--- Set the state of an addon or module. Does not actually enable the module.
-- This should only be called before any enabling actually happend, e.g. in/before OnInitialize.
-- It is safe to use :Enable() / :Enable(false) instead. Enabling will be done after the module is initialized.
-- @name //moduleObj//:SetEnabledState
-- @paramsig state
-- @param state the state of an addon or module  (enabled=true, disabled=false)
--
function mixin.SetEnabledState(moduleObj, state)
	moduleObj.enabledState = state
end


--- Return an iterator of all submodules of the module.
-- @name //moduleObj//:IterateModules
-- @paramsig 
-- @usage 
-- -- Enable all modules
-- for name, module in MyAddon:IterateModules() do
--    module:Enable()
-- end
--
function mixin.IterateModules(parentModule)  return pairs(parentModule.modules or {})  end

--- Return an iterator of all embedded libraries in the module.
-- @name //moduleObj//:IterateEmbeds
-- @paramsig 
--
function mixin.IterateEmbeds(moduleObj)  return pairs(AceAddon.embeds[moduleObj])  end



-- Embed( target )
-- target (object) - target object to embed aceaddon in
--
-- this is a local function specifically since it's meant to be only called internally
function Embed(target)
	for k, v in pairs(mixin) do
		target[k] = v
	end
end

--[[
local ModuleObjDefaults = {
	defaultModuleState = true,
}
function SetDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if target[k]==nil then  target[k] = v  end
	end
end
--]]




--- Initialize the addon after creation.
-- This function is only used internally during the ADDON_LOADED event
-- It will call the **OnInitialize** function on the addon object (if present), 
-- and the **OnEmbedInitialize** function on all embedded libraries.
-- 
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
-- @param addon addon object to intialize
--
function AceAddon:InitializeAddon(moduleObj)
	local fullName = moduleObj.name
	-- If module is uninitialized then  self.statuses[fullName] == nil. This guarantees modules are initialized only once.
	-- Simpler, therefore more reliable than scanning initializequeue for the module.
	LibShared.softassert(self.statuses[fullName] == nil, "AceAddon:InitializeAddon('"..fullName.."') called repeatedly.")
	if  self.statuses[fullName] ~= nil  then  return  end

  -- Initialized, but not enabled status. Set before OnInitialize() so calling :Enable() will actually enable the module.
	self.statuses[fullName] = false
	safecall(moduleObj.OnInitialize, moduleObj)
	
	local embeds = self.embeds[moduleObj]
	for i = 1, #embeds do
		local lib = LibStub:GetLibrary(embeds[i], true)
		if lib then safecall(lib.OnEmbedInitialize, lib, moduleObj) end
	end
	
	-- we don't call InitializeAddon on modules specifically, this is handled
	-- from the event handler and only done _once_
end


--- Enable the addon or module after creation.
-- Note: This function is only used internally during the PLAYER_LOGIN event, or during ADDON_LOADED,
-- if IsLoggedIn() already returns true at that point, e.g. for LoD Addons.
-- It will call the **OnEnable** function on the addon object (if present), 
-- and the **OnEmbedEnable** function on all embedded libraries.\\
-- This function does not toggle the enable state of the addon itself, and will return early if the addon is disabled.
--
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing.
-- Use :Enable on the addon itself instead.
-- @param moduleObj  addon or module object to enable.
--
function AceAddon:EnableAddon(moduleObj, enable, temp)
	-- enable =  enable==nil  and  true  or  not not enable	-- Make it strictly boolean.
	enable =  enable==nil  and  true  or  enable	-- Allow non-boolean enabledState.

	if type(moduleObj) == "string" then  moduleObj = AceAddon:GetAddon(moduleObj)  end
	-- fullName is the name set by AceAddon:NewAddon(). Might be different from moduleObj.realAddonName / moduleObj.folderName) set by :SetRealAddonName() or DetermineAddonFolder().
	local fullName = moduleObj.name

	-- nevcairiel 2013-04-27: don't enable an addon/module if its queued for init still
	-- it'll be enabled after the init process
	-- If module is uninitialized then  self.statuses[fullName] == nil. This guarantees modules aren't enabled before initialized.
	if  self.statuses[fullName] == nil  then  return false  end
	if  self.statuses[fullName] == enable  then  return false  end

	-- Check if the user really wants to enable this module. Should be done by caller.
	if  not temp  and  moduleObj.enabledState ~= enable  then  return false  end

	-- Mark moment for addon developer.
	if  DEVMODE and DEVMODE[fullName]  then  print( "AceAddon:EnableAddon('"..fullName.."', "..tostring(enable)..")" )  end

	-- set the statuses first, before calling the OnEnable. this allows for Disabling of the addon in OnEnable.
	-- self.statuses[fullName] = true / enable
	-- This results in recursively calling :OnDisable() if an addon tries to :Disable() in OnEnable():
	-- EnableAddon() -> statuses[fullName] = true, :OnEnable() -> :Disable() -> DisableAddon(), statuses[fullName] == true -> statuses[fullName] = false, :OnDisable()
	-- If :OnDisable() does :Enable() for some reason, then this is infinite recursion.
	-- Note:  Addons don't use this feature, nor set the internal self.statuses[fullName], thus it's safe to change this behaviour.

	-- The expected flow is:  EnableAddon() -> statuses[fullName] remains `false` -> :OnEnable() -> :Disable() -> moduleObj.enabledState = false,
	-- statuses[fullName] == false -> DisableAddon() does nothing, EnableAddon() aborts as moduleObj.enabledState == false.
	
	local ModuleCallback = enable and 'OnEnable' or 'OnDisable'

	-- self.statuses[fullName] = true  protected from one kind of infinite recursion: EnableAddon() -> :OnEnable() -> Enable() -> EnableAddon()
	self.enabling[moduleObj] = ModuleCallback
	-- self.enabling[moduleObj] = enable or 'Disable'
	
	-- If called by TemporaryDisable()
	moduleObj.enabledState = enable

	-- Call :OnEnable() / :OnDisable()
	safecall(moduleObj[ModuleCallback], moduleObj)

	-- The module is considered enabled/disabled after :OnEnable() / :OnDisable().
	-- submodule:OnEnable() will see self.parentModule:IsEnabled() == enable
	-- submodule:OnDisable() will see self.parentModule:IsEnabled() == false
	self.statuses[fullName] = moduleObj.enabledState

	-- Stop protecting against recursion.
	-- A submodule can :Disable() the parent in :OnEnable()  /  or :Enable() in :OnDisable().
	-- In this rare circumstance those submodules that finished enabling will be disabled...
	self.enabling[moduleObj] = nil

	-- Make sure module is still enabled/disabled before iterating embedded libraries and submodules.
	-- Both enable and enabledState are allowed to be non-boolean, thus the not-not check:
	-- different enabledState(s) carry meaning only for the module, here it's truthy or falsy.
	if not moduleObj.enabledState == not enable  then
		local embeds = self.embeds[moduleObj]
		local OnEmbedCallback = enable and 'OnEmbedEnable' or 'OnEmbedDisable'
		for i = 1, #embeds do
			local lib = LibStub:GetLibrary(embeds[i], true)
			if lib then safecall(lib[OnEmbedCallback], lib, moduleObj) end
		end

		-- Enable/disable submodules.
		local submodules = moduleObj.orderedModules
		for i = 1, (submodules and #submodules or 0) do
			self:EnableAddon(submodules[i], moduleObj.enabledState)
		end
	end

	-- Return true if the resulting state is the expected one.
	-- :OnEnable() / :OnDisable(), even submodules could have changed it.
	-- Change between specific truthy enabledStates (eg. true -> 1 / 'somestate' / etc.) does not matter,
	-- all count as enabled, thus the not-not check.
	return not self.statuses[fullName] == not enable
end


--- Disable the addon or module.
-- Note: This function is only used internally.
-- It will call the **OnDisable** function on the addon object (if present), 
-- and the **OnEmbedDisable** function on all embedded libraries.\\
-- This function does not toggle the enable state of the addon itself, and will return early if the addon is still enabled.
--
-- **Note:** Do not call this function manually, unless you're absolutely sure that you know what you are doing. 
-- Use :Disable on the addon itself instead.
-- @param moduleObj  addon or module object to disable.
--
function AceAddon:DisableAddon(moduleObj)
	-- Deprecated. Kept for backward-compatibility with addons using this internal AceAddon api, if there are any.
	return self:EnableAddon(moduleObj, false)
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
function AceAddon:IterateModulesOfAddon(addon) return pairs(addon.modules or {}) end




-- Event Handling
local function OnEvent(frame, event, addonName)
	if  event == "ADDON_LOADED"  then
		-- 2011-08-17 nevcairiel - ignore the load event of Blizzard_DebugTools, so a potential startup error isn't swallowed up
		-- if  addonName == "Blizzard_DebugTools"  then  return  end
		if  addonName:sub(1,9) == "Blizzard_"  then  return  end
		-- If an addon does LoadAddOn() in its main chunk (not from an event handler) then the ADDON_LOADED event
		-- for the latter addon comes before LoadAddOn() returns, when the former addon did not finish loading, and
		-- its SavedVariables are not available yet. This possibility is hard to detect, therefore ignored.
		-- OnInitialize will be called for the first addon too, before its SavedVariables are loaded. The addon author will notice this soon.
		-- There is no issue if LoadAddOn() is called in OnInitialize(), or later.
		-- Options for detection:
		-- 1. checking ADDON_LOADED's addonName. Problem: detecting the real addonName is unreliable.
		--    DetermineAddonFolder() works only if the filepath is not too long, in which case the lua runtime cuts of the beginning part of the path:
		--    "Interface\AddOns\<addonName>\<subfolders>\<filename>.lua" -- If "AddOns\" is touched, pattern matching fails. This often happens to modules in 2 subfolders.
		-- 2. Rawhooking (pre-hook is necessary) LoadAddOn(). This would taint the execution path after UIParentLoadAddOn(), *_LoadUI(), _ERRORMESSAGE() - the default geterrorhandler(), UIParent_OnEvent('LUA_WARNING') - until end of eventhandler
		--    TODO: Test if KeyBindingFrame survives the tainting of KeyBindingFrame_LoadUI() in GameMenuFrame.lua, or bye-bye incombat binding changes.
		--    RaidFrame_Update() after RaidFrame_LoadUI()? in RaidFrame.lua
		--    UIParent.lua:  ReforgingFrame_Show(), PlayerTalentFrame_Toggle(), GlyphFrame_Toggle(), PetJournalParent_SetTab(), ToggleFrame(PetJournalParent), PVPUIFrame_ToggleFrame(),
		--    TradeSkillFrame_Show(), ItemSocketingFrame_Update(), ReforgingFrame_Show(), ArchaeologyFrame_Show(), TransmogrifyFrame_Show(), VoidStorageFrame_Show(), ItemUpgradeFrame_Show()
	end

	if event=='ADDON_LOADED' then
		AceAddon:DoInitQueue(addonName)
	end
	-- if event=='PLAYER_LOGIN' then
	if G.IsLoggedIn() then
		AceAddon:DoInitQueue()
		AceAddon:DoEnableQueue()
	end
end

function AceAddon:DoInitQueue(addonName)
	if not self.startedInit then
		self.startedInit = date("%H:%M:%S")
		print("AceAddon:  start initializing addons at ["..self.startedInit.."]")
	end

	local timeLog = AceAddon.addonInitTimeLog
	local times = AceAddon.addonInitTimes
	local before = debugprofilestop()

	local queue = self.initializequeue
	-- InitializeAddon() might load another addon, calling this function recursively. The recursive invocation will have its own initializequeue,
	-- so it does not init the modules left for this addon, which might depend on the currently initialized module (`moduleObj` in this block).
	self.initializequeue = nil

	local index, skipped = 0, nil
	-- initializequeue is nilled, therefore not accessible from elsewhere,
	-- so there will be no additions to this queue, the length remains constant.
	while index < #queue do
		index = index + 1    -- Started at zero.
		local moduleObj = queue[index]

		local skip =  addonName  and  moduleObj.realAddonName  and  moduleObj.realAddonName ~= addonName
		if  addonName  and  not moduleObj.realAddonName  then
			-- moduleObj.addonFolder == moduleObj.baseName == addonName expected
			if  moduleObj.addonFolder  and  moduleObj.addonFolder ~= addonName  then
				G.geterrorhandler()( event.."('"..addonName.."'):  event fired for possibly different addon. Initializing moduleObj.addonFolder = '"..moduleObj.addonFolder.."'" )
			end
			if  G.DEVMODE  and  not moduleObj.moduleName  and  moduleObj.addonFolder  and  moduleObj.addonFolder ~= moduleObj.name  then
				print("AceAddon('"..moduleObj.name.."'):  name different from moduleObj.addonFolder = '"..moduleObj.addonFolder.."'. Use:   if addon.SetRealAddonName then  addon:SetRealAddonName(...)  end   (or ADDON_NAME instead of ...) to explicitly set the real addon name.")
			end

			-- Historically the parameter of ADDON_LOADED event is saved to baseName. Have seen only one addon using it: Prat-3.0.
			-- Deprecated, use :GetRealAddonName() instead.
			moduleObj.baseName = addonName
		end

		if skip then
			skipped = skipped or {}
			skipped[#skipped+1] = moduleObj
			if G.DEVMODE then  print("AceAddon('"..moduleObj.name.."'):  delaying :InitializeAddon(). This is ADDON_LOADED event for recursively loaded addon '"..addonName.."'.")  end
		else
			-- tremove(queue, i)
			-- Remove from queue without moving the rest.
			queue[index] = false
			self:InitializeAddon(moduleObj)
			tinsert(self.enablequeue, moduleObj)

			local subqueue = self.initializequeue
			if subqueue then
				-- InitializeAddon() added new module(s). Append those to the parent context's queue.
				-- If InitializeAddon() loaded another addon, and wow fired the ADDON_LOADED event,
				-- then those modules were inited in a recursive call to this event handler, resulting in an empty subqueue.
				for i = 1,#subqueue do  queue[#queue+1] = subqueue[i]  end
				self.initializequeue = nil
			end

			if not addonName then
				local after = debugprofilestop()
				local spent = after - before
				before = after

				local fullName = moduleObj.name
				local msg = format("  at [%s]  %s: %.1f ms", date("%H:%M:%S"), fullName, spent)
				if  times  then  times[fullName] = spent  end
				if  timeLog  then  timeLog[#timeLog+1] = msg  end
				print(msg)
			end
		end
	end

	wipe(queue)
	-- Restore this level of recursion. Keep only the skipped addons in the queue.
	self.initializequeue = skipped or queue

	local after = debugprofilestop()
	local spent = after - before

	if addonName and 0.2 <= spent then
		local fullName = addonName
		local msg = format("  at [%s]  %s: %.1f ms", date("%H:%M:%S"), fullName, spent)
		if  times  then  times[fullName] = spent  end
		if  timeLog  then  timeLog[#timeLog+1] = msg  end
		print(msg)
	end
end



function AceAddon:DoEnableQueue()
	print("AceAddon:  start enabling addons at ["..date("%H:%M:%S").."] - IsLoggedIn, IsPlayerInWorld:", G.IsLoggedIn(), G.IsPlayerInWorld())

	local timeLog = AceAddon.addonEnableTimeLog
	local times = AceAddon.addonEnableTimes
	local before = debugprofilestop()

	local queue, first = AceAddon.enablequeue, 1
	while  first <= #queue  do
		-- local moduleObj = tremove(queue, 1)
		-- Remove from queue without moving the rest.
		local moduleObj = queue[first]
		queue[first] = false
		first = first + 1

		local didEnable = AceAddon:EnableAddon(moduleObj)
		local after = debugprofilestop()
		local spent = after - before
		before = after

		if didEnable then
			local fullName = moduleObj.name
			local msg = format("  at [%s]  %s: %.1f ms", date("%H:%M:%S"), fullName, spent)
			if  times  then  times[fullName] = spent  end
			if  timeLog  then  timeLog[#timeLog+1] = msg  end
			print(msg)
		end
	end

	wipe(queue)
end



--[[
local GetTime, debugprofilestop, strjoin = GetTime, debugprofilestop, strjoin

-- Throttled enabling of addons.
local function OnUpdate(frame, elapsed)
	frame.minElapsed = min(elapsed, frame.minElapsed or elapsed)
	frame.maxElapsed = max(elapsed, frame.maxElapsed or elapsed)
	frame.totalElapsed = (frame.totalElapsed or 0) + elapsed
	if  not G.IsLoggedIn()  then  return  end
	frame.frameCount = (frame.frameCount or 0) + 1
	if  frame.frameCount < 10  then  return  end

	local timeLog = AceAddon.addonEnableTimeLog
	local times = AceAddon.addonEnableTimes
	local frameStart = debugprofilestop()
	local thisRound = {}

	if  not frame.batchStart  then
		frame.batchStart = frameStart
		frame.batchFrame = frame.frameCount
		print("AceAddon started enabling addons at "..date("%H:%M:%S") )
	end

	local queue = AceAddon.enablequeue
	queue.first = queue.first or 1
	-- Skip `false` at start of queue.
	while  queue.first <= #queue  do
		local before = debugprofilestop()
		-- local moduleObj = tremove(queue, 1)
		-- Remove from queue without moving the rest.
		local moduleObj = queue[queue.first]
		queue[queue.first] = false
		queue.first = queue.first + 1

		local fullName = moduleObj.name
		local didEnable = AceAddon:EnableAddon(moduleObj)
		-- Avoid listing submodules if the parentModule enabled them earlier.
		if didEnable then  thisRound[#thisRound+1] = fullName  end
		
		local after = debugprofilestop()
		if  timeLog  then  timeLog[#timeLog+1] = format("%s: %.1f ms", fullName, after - before)  end
		if  times  then  times[fullName] = after - before  end
		
		-- 30 fps = 33.3 ms/f
		local timeLimit = 0.5  -- milisec
		-- local timeLimit = frame.minElapsed/32
		if  after - frameStart > timeLimit  then
			print(format( "AceAddon enabled in one frame, %.1f ms:  %s", after - frameStart, strjoin(",", unpack(thisRound)) ))
			return
		end
	end

	local msg = format("AceAddon.enablequeue finished after %.3f seconds, %d frames", debugprofilestop()/1000 - frame.batchStart/1000, frame.frameCount - frame.batchFrame)
	frame.batchStart, frame.batchFrame, frame.frameCount = nil,nil,nil
	if timeLog then  timeLog[#timeLog+1] = msg  end
	print(msg)

	-- Stop receiving OnUpdate.
	wipe(queue)
	frame:Hide()
end
--]]


AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
AceAddon.frame:SetScript("OnEvent", OnEvent)
AceAddon.frame:SetScript("OnUpdate", OnUpdate)
AceAddon.frame:Show()    -- Measure frame time(s) before PLAYER_LOGIN. Addon loading is one loooooong frame, no OnUpdate between addons.


-- Upgrade embedded.
for name, moduleObj in pairs(AceAddon.addons) do
	Embed(moduleObj, true)
	-- Garbage collect modules' empty submodule tables.
	if moduleObj.modules and nil==next(moduleObj.modules) then  moduleObj.modules = nil  end
	if moduleObj.orderedModules and nil==next(moduleObj.orderedModules) then  moduleObj.orderedModules = nil  end
	if moduleObj.defaultModuleLibraries and nil==next(moduleObj.defaultModuleLibraries) then  moduleObj.defaultModuleLibraries = nil  end
end

-- 2010-10-27 nevcairiel - add new "orderedModules" table
if oldminor and oldminor < 10 then
	for name, parentModule in pairs(AceAddon.addons) do  if parentModule.modules and next(parentModule.modules) then
		parentModule.orderedModules = {}
		for moduleName, submodule in pairs(parentModule.modules) do
			tinsert(parentModule.orderedModules, submodule)
		end
	end end -- for if
end


