--- **AceHook-3.0** offers safe Hooking/Unhooking of functions, methods and frame scripts.
-- Using AceHook-3.0 is recommended when you need to unhook your hooks again, so the hook chain isn't broken
-- when you manually restore the original function.
--
-- **AceHook-3.0** can be embedded into your addon, either explicitly by calling AceHook:Embed(MyAddon) or by 
-- specifying it as an embedded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceHook itself.\\
-- It is recommended to embed AceHook, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceHook.
-- @class file
-- @name AceHook-3.0
-- @release $Id: AceHook-3.0.lua 1090 2013-09-13 14:37:43Z nevcairiel $

local G, MAJOR, MINOR = _G, "AceHook-3.0", 7
local AceHook, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceHook then return end -- No upgrade needed


local LibShared = G.LibShared or {}  ;  G.LibShared = LibShared

-----------------------------
--- LibShared. InitTable():  function that looks up a path of keys in a table and auto-creates empty inner tables when the key is not initialized.
-- @return  last table on the path.
-- Usage:  InitTable(root, 'level1', 'level2', 'level3')
-- Returns  root.level1.level2.level3 , creating them as empty tables, if necessary.
--
LibShared.InitTable = LibShared.InitTable  or  function(self, ...)
	for i = 1, select('#',...) do
		local key = select(i,...)
		local subTable = self[key]
		if subTable==nil then
			subTable = {}
			self[key] = subTable
		end
		self = subTable
	end
  return self
end


-----------------------------
--- LibShared. QueryTable():  function that looks up a path of keys in a table.
-- @return  last table on the path, or ConstEmptyTable if its not initialized.
-- Usage:  InitTable(root, 'level1', 'level2', 'level3')
-- Returns  root.level1.level2.level3 , or ConstEmptyTable if one level is not created.
--
LibShared.QueryTable = LibShared.QueryTable  or  function(self, ...)
	for i = 1, select('#',...) do
		local key = select(i,...)
		self = self[key]
		if self==nil then  return ConstEmptyTable  end
	end
  return self
end


-----------------------------
--- LibShared. QueryTableMeta:  metatable that that looks up a path of keys in a table when called with the keys as arguments.
-- @return  empty table  if indexed with non-existent key.
-- Usage:  root('level1', 'level2', 'level3')
LibShared.QueryTableMeta = LibShared.QueryTableMeta or { __call = LibShared.QueryTable }



AceHook.registry = AceHook.registry or {}
setmetatable(AceHook.registry, LibShared.QueryTableMeta)
AceHook.registry.init = LibShared.InitTable

AceHook.handlers = AceHook.handlers or {}
AceHook.actives  = AceHook.actives  or {}
AceHook.scripts  = AceHook.scripts  or {}
AceHook.hooks    = AceHook.hooks    or {}

-- Renamed onceSecure -> ignoredIsSecure
AceHook.ignoredIsSecure = AceHook.ignoredIsSecure or AceHook.onceSecure or {}
setmetatable(AceHook.ignoredIsSecure, LibShared.QueryTableMeta)
AceHook.ignoredIsSecure.init = LibShared.InitTable
AceHook.onceSecure = nil

-- Renamed embeded -> embedded
AceHook.embedded = AceHook.embedded or AceHook.embeded or {}  -- Clients embedding the mixin methods.
AceHook.embeded  = nil

AceHook.mixin    = AceHook.mixin    or {}  -- Methods embedded in clients.
local mixin = AceHook.mixin

-- local upvalues
local registry = AceHook.registry
local handlers = AceHook.handlers
local actives  = AceHook.actives
local scripts  = AceHook.scripts
local ignoredIsSecure = AceHook.ignoredIsSecure

-- Lua APIs
local pairs, next, type = pairs, next, type
local format = string.format
local assert, error = assert, error

-- WoW APIs
local issecurevariable, hooksecurefunc = issecurevariable, hooksecurefunc

-- functions for later definition
local donothing, createHook, hook

local protectedScripts = {
	OnClick = true,
}

--[[
-- upgrading of embedded is done at the bottom of the file
local mixins = {
	"Hook", "SecureHook",
	"HookScript", "SecureHookScript",
	"Unhook", "UnhookAll",
	"IsHooked",
	"RawHook", "RawHookScript"
}--]]


-- Embeds AceHook into the target object making the functions from the mixin table available on target:..
-- @param target target object to embed AceHook in
function AceHook:Embed( target )
	self.embedded[target] = true
	for name,method in pairs(self.mixin) do
		target[name] = method
	end
	-- inject the hooks table safely
	target.hooks = target.hooks or {}
	return target
end

-- AceHook:OnEmbedDisable( target )
-- target (object) - target object that is being disabled
--
-- Unhooks all hooks when the target disables.
-- this method should be called by the target manually or by an addon framework
function AceHook:OnEmbedDisable( target )
	target:UnhookAll()
end



-- Confused, contorted, contrived, ambiguous.
function createHook(self, handler, orig, secure, prehook)
	local hookedF
	local method = type(handler) == "string"
	if prehook then
		-- prehook creation
		hookedF = function(...)
			if actives[hookedF] then
				if method then
					self[handler](self, ...)
				else
					handler(...)
				end
			end
			-- call orig after prehook
			return orig(...)
		end
		-- /prehook
	else
		-- all other hooks
		hookedF = function(...)
			if actives[hookedF] then
				if method then
					return self[handler](self, ...)
				else
					return handler(...)
				end
			elseif not secure then
				-- rawhook calls the orig if the hook is inactive
				return orig(...)
			end
		end
		-- /hook
	end
	return hookedF
end



function donothing() end

function hook(self, obj, method, handler, script, secure, replace, ignoreIsSecure, usage)
	if not handler then handler = method end
	
	-- These asserts make sure AceHooks's devs play by the rules.
	assert(not script or type(script) == "boolean")
	assert(not secure or type(secure) == "boolean")
	assert(not replace or type(replace) == "boolean")
	assert(not ignoreIsSecure or type(ignoreIsSecure) == "boolean")
	assert(usage)
	
	-- Error checking Battery!
	if obj and type(obj) ~= "table" then
		error(usage..": 'object' - nil or table expected, got "..type(obj), 3)
	end
	if type(method) ~= "string" then
		error(usage..": 'method' - string expected, got "..type(method), 3)
	end
	if type(handler) ~= "string" and type(handler) ~= "function" then
		error(usage..": 'handler' - nil, string, or function expected, got "..type(handler), 3)
	end
	if type(handler) == "string" and type(self[handler]) ~= "function" then
		error(usage..": 'handler' - Handler specified does not exist at self[handler]", 3)
	end
	local objOrG = obj or G

	if script then
		if not obj or not obj.GetScript or not obj.HasScript then
			error( usage..": You can only hook a script on a frame object", 3)
		elseif not obj:HasScript(method) then
			error( usage..format(": %s does not support script type '%s'.", (obj.GetObjectType and obj:GetObjectType() or 'object'), method), 3)
		end
		if not secure and obj.IsProtected and obj:IsProtected() and protectedScripts[method] then
			error(format("Cannot hook secure script %q; Use SecureHookScript(obj, method, [handler]) instead.", method), 3)
		end
	else
		local issecure = ignoredIsSecure(objOrG)[method] or issecurevariable(objOrG, method)
		-- TODO:  test if  issecurevariable(method) === issecurevariable(_G, method)
		-- issecure = ignoredIsSecure[method] or issecurevariable(method)
		if issecure then
			if ignoreIsSecure then
				-- ignoredIsSecure(true,objOrG)[method] = true
				ignoredIsSecure:init(objOrG)[method] = true
			elseif not secure then
				error(format("%s: Attempt to hook secure function %s. Use `SecureHook' or add `true' to the argument list to override.", usage, method), 3)
			end
		end
	end
	
	local hookedF = registry(self, objOrG)[method]
	
	if hookedF then
		if actives[hookedF] then
			-- Only two sane choices exist here.  We either a) error 100% of the time or b) always unhook and then hook
			-- choice b would likely lead to odd debuging conditions or other mysteries so we're going with a.
			error( "Attempting to rehook already active hook "..method, 3 )
		end
		
		if handlers[hookedF] == handler then -- turn on a deactivated hook, note each closure has a new identity, the old one cannot be identified: small memory leak
			actives[hookedF] = true
			return
		else
			-- is there any reason not to call unhook instead of doing the following several lines?
			if self.hooks and self.hooks[objOrG] then
				self.hooks[objOrG][method] = nil
			end
			registry[self][objOrG][method] = nil
		end
		handlers[hookedF], actives[hookedF], scripts[hookedF] = nil, nil, nil
		hookedF = nil
	end
	
	local orig
	if script then
		orig = objOrG:GetScript(method) or donothing
	else
		orig = objOrG[method]
	end
	
	if  not orig  and  not script  then
		error( usage..": Attempting to hook a non existing target", 3 )
	end
	
	local prehook =  not replace  and  not secure
	hookedF = createHook(self, handler, orig, secure, prehook)
	
	-- if obj then
	do
		-- registry[self][objOrG] = registry[self][objOrG] or {}
		-- registry(true, self, objOrG)[method] = hookedF
		registry:init(self, objOrG)[method] = hookedF

		if not secure then
			-- .hooks should be called... original(s)
			self.hooks[objOrG] = self.hooks[objOrG]  or  objOrG == G and self.hooks  or  {}
			self.hooks[objOrG][method] = orig
		end
		
		if script then
			if not secure then
				objOrG:SetScript(method, hookedF)
			elseif secure then
				objOrG:HookScript(method, hookedF)
			end
		else
			if not secure then
				objOrG[method] = hookedF
			else
				hooksecurefunc(objOrG, method, hookedF)
			end
		end
	end
	
	actives[hookedF], handlers[hookedF], scripts[hookedF] = true, handler, script and true or nil	
end



--- Pre-Hook a function or a method on an object.  This should be called :PreHook().
-- The hook created will be a "Pre-Hook", that means that your handler will be called
-- before the hooked function, and you don't have to call the original function yourself,
-- however you cannot stop the execution of the function, or modify any of the arguments/return values.\\
-- This type of hook is typically used if you need to know if some function got called, and don't want to modify it.
-- @paramsig [object], method, [handler], [ignoreIsSecure]
-- @param object The object to hook a method from
-- @param method If object was specified, the name of the method, or the name of the function to hook.
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked function)
-- @param ignoreIsSecure If true, AceHook will allow hooking of secure functions.
-- @usage
-- -- create an addon with AceHook embedded
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("HookDemo", "AceHook-3.0")
-- 
-- function MyAddon:OnEnable()
--   -- Hook ActionButton_UpdateHotkeys, overwriting the secure status
--   self:Hook("ActionButton_UpdateHotkeys", true)
-- end
--
-- function MyAddon:ActionButton_UpdateHotkeys(button, type)
--   print(button:GetName() .. " is updating its HotKey")
-- end
function mixin:Hook(object, method, handler, ignoreIsSecure)
	if type(object) == "string" then
		object, method, handler, ignoreIsSecure = nil, object, method, handler
	end
	
	if handler == true then
		handler, ignoreIsSecure = nil, true
	end

	hook(self, object, method, handler, false, false, false, ignoreIsSecure or false, "Usage: Hook([object], method, [handler], [ignoreIsSecure])")	
end

--- RawHook a function or a method on an object.  This should be called :Replace()
-- The hook created will be a "raw hook", that means that your handler will completely replace
-- the original function, and your handler has to call the original function (or not, depending on your intentions).\\
-- The original function will be stored in `self.hooks[object][method]` or `self.hooks[functionName]` respectively.\\
-- This type of hook can be used for all purposes, and is usually the most common case when you need to modify arguments
-- or want to control execution of the original function.
-- @paramsig [object], method, [handler], [ignoreIsSecure]
-- @param object The object to hook a method from
-- @param method If object was specified, the name of the method, or the name of the function to hook.
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked function)
-- @param ignoreIsSecure If true, AceHook will allow hooking of secure functions.
-- @usage
-- -- create an addon with AceHook embedded
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("HookDemo", "AceHook-3.0")
-- 
-- function MyAddon:OnEnable()
--   -- Hook ActionButton_UpdateHotkeys, overwriting the secure status
--   self:RawHook("ActionButton_UpdateHotkeys", true)
-- end
--
-- function MyAddon:ActionButton_UpdateHotkeys(button, type)
--   if button:GetName() == "MyButton" then
--     -- do stuff here
--   else
--     self.hooks.ActionButton_UpdateHotkeys(button, type)
--   end
-- end
function mixin:RawHook(object, method, handler, ignoreIsSecure)
	if type(object) == "string" then
		method, handler, ignoreIsSecure, object = object, method, handler, nil
	end
	
	if handler == true then
		handler, ignoreIsSecure = nil, true
	end
	
	hook(self, object, method, handler, false, false, true, ignoreIsSecure or false,  "Usage: RawHook([object], method, [handler], [ignoreIsSecure])")
end

--- SecureHook a function or a method on an object.  This should be called PostHook(), but SecureHook() is fine in the context of the contrived wow secure api.
-- This function is a wrapper around the `hooksecurefunc` function in the WoW API. Using AceHook
-- extends the functionality of secure hooks, and adds the ability to unhook once the hook isn't
-- required anymore, or the addon is being disabled.\\
-- Secure Hooks should be used if the secure-status of the function is vital to its function,
-- and taint would block execution. Secure Hooks are always called after the original function was called
-- ("Post Hook"), and you cannot modify the arguments, return values or control the execution.
-- @paramsig [object], method, [handler]
-- @param object The object to hook a method from
-- @param method If object was specified, the name of the method, or the name of the function to hook.
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked function)
function mixin:SecureHook(object, method, handler)
	if type(object) == "string" then
		method, handler, object = object, method, nil
	end
	
	hook(self, object, method, handler, false, true, false, false,  "Usage: SecureHook([object], method, [handler])")
end

--- Hook a script handler on a frame.  Should be called PreHookScript(). As it taints, calling like the secure Frame.HookScript() method is nefariously confusing.
-- The hook created will be a "Pre-Hook", that means that your handler will be called
-- before the hooked script, and you don't have to call the original function yourself,
-- however you cannot stop the execution of the function, or modify any of the arguments/return values.\\
-- This is the frame script equivalent of the :Hook safe-hook. It would typically be used to be notified
-- when a certain event happens to a frame.
-- @paramsig frame, script, [handler]
-- @param frame The Frame to hook the script on
-- @param script The script to hook
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked script)
-- @usage
-- -- create an addon with AceHook embedded
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("HookDemo", "AceHook-3.0")
-- 
-- function MyAddon:OnEnable()
--   -- Hook the OnShow of FriendsFrame 
--   self:HookScript(FriendsFrame, "OnShow", "FriendsFrameOnShow")
-- end
--
-- function MyAddon:FriendsFrameOnShow(frame)
--   print("The FriendsFrame was shown!")
-- end
function mixin:HookScript(frame, script, handler)
	hook(self, frame, script, handler, true, false, false, false,  "Usage: HookScript(object, method, [handler])")
end

--- RawHook a script handler on a frame.  Should be called ReplaceScript().
-- The hook created will be a "raw hook", that means that your handler will completly replace
-- the original script, and your handler has to call the original script (or not, depending on your intentions).\\
-- The original script will be stored in `self.hooks[frame][script]`.\\
-- This type of hook can be used for all purposes, and is usually the most common case when you need to modify arguments
-- or want to control execution of the original script.
-- @paramsig frame, script, [handler]
-- @param frame The Frame to hook the script on
-- @param script The script to hook
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked script)
-- @usage
-- -- create an addon with AceHook embedded
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("HookDemo", "AceHook-3.0")
-- 
-- function MyAddon:OnEnable()
--   -- Hook the OnShow of FriendsFrame 
--   self:RawHookScript(FriendsFrame, "OnShow", "FriendsFrameOnShow")
-- end
--
-- function MyAddon:FriendsFrameOnShow(frame)
--   -- Call the original function
--   self.hooks[frame].OnShow(frame)
--   -- Do our processing
--   -- .. stuff
-- end
function mixin:RawHookScript(frame, script, handler)
	hook(self, frame, script, handler, true, false, true, false, "Usage: RawHookScript(object, method, [handler])")
end

--- SecureHook a script handler on a frame. Out of the alternatives PostHookScript / SecureHookScript / HookScript the current one is maybe the best.
-- This function is a wrapper around the `frame:HookScript` function in the WoW API. Using AceHook
-- extends the functionality of secure hooks, and adds the ability to unhook once the hook isn't
-- required anymore, or the addon is being disabled.\\
-- Secure Hooks should be used if the secure-status of the function is vital to its function,
-- and taint would block execution. Secure Hooks are always called after the original function was called
-- ("Post Hook"), and you cannot modify the arguments, return values or control the execution.
-- @paramsig frame, script, [handler]
-- @param frame The Frame to hook the script on
-- @param script The script to hook
-- @param handler The handler for the hook, a funcref or a method name. (Defaults to the name of the hooked script)
function mixin:SecureHookScript(frame, script, handler)
	hook(self, frame, script, handler, true, true, false, false, "Usage: SecureHookScript(object, method, [handler])")
end

--- Unhook from the specified function, method or script.
-- @paramsig [obj], method
-- @param obj The object or frame to unhook from
-- @param method The name of the method, function or script to unhook from.
function mixin:Unhook(obj, method)
	local usage = "Usage: Unhook([obj], method)"
	if type(obj) == "string" then
		method, obj = obj, nil
	end
		
	if obj and type(obj) ~= "table" then
		error(format("%s: 'obj' - expected nil or table, got %s", usage, type(obj)), 2)
	end
	if type(method) ~= "string" then
		error(format("%s: 'method' - expected string, got %s", usage, type(method)), 2)
	end
	
	local objOrG = obj or G
	local hookedF = registry(self, objOrG)[method]
	
	if not hookedF or not actives[hookedF] then
		-- Declining to error on an unneeded unhook since the end effect is the same and this would just be annoying.
		return false
	end
	
	actives[hookedF], handlers[hookedF] = nil, nil
	
	-- if obj then
	do
		registry[self][objOrG][method] = nil
		if not next(registry[self][objOrG]) then  registry[self][objOrG] = nil  end
		
		-- if the hook reference doesnt exist, then its a secure hook, just bail out and dont do any unhooking
		local original = self.hooks[objOrG] and self.hooks[objOrG][method]
		if not original then  return true  end
		
		if scripts[hookedF] and objOrG:GetScript(method) == hookedF then  -- unhooks scripts
			objOrG:SetScript(method, original ~= donothing and original or nil)	
			scripts[hookedF] = nil
		elseif objOrG[method] == hookedF then -- unhooks methods
			objOrG[method] = original
		end
		
		self.hooks[objOrG][method] = nil
		if not next(self.hooks[objOrG]) then  self.hooks[objOrG] = nil  end
	end
	return true
end


--- Unhook all existing hooks for this addon.
function mixin:UnhookAll()
	for objOrG, hookedFs in pairs(registry(self)) do
		for method,hookedF in pairs(hookedFs) do
			self:Unhook(objOrG, method)
		end
	end
end

--- Check if the specific function, method or script is already hooked.
-- @paramsig [obj], method
-- @param obj The object or frame that owns the method.
-- @param method The name of the method, function or script to check.
function mixin:IsHooked(objOrG, method)
	-- we don't check if registry[self] exists, this is done by evil magicks in the metatable
	if type(objOrG) == "string" then  objOrG, method = G, objOrG  end

	local hookedF = registry(self, objOrG)[method]
	if hookedF and actives[hookedF] then
		return true, handlers[hookedF]
	end
	
	return false, nil
end



-- Serpent biting its own tail.
AceHook.embedded[AceHook] = true

-- Upgrade our embedded mixin methods from previous revision.
for target, v in pairs( AceHook.embedded ) do
	AceHook:Embed( target )
end


