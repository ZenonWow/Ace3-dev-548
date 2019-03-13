--[[ $Id: CallbackHandler-1.0.lua 14 2010-08-09 00:43:38Z mikk $ ]]
--[[ $Id: CallbackHandler-1.0.lua 965 2010-08-09 00:47:52Z mikk $ ]]
-- @name CallbackHandler-1.0.lua
-- @release $Id: CallbackHandler-1.0.lua 14 2010-08-09 00:43:38Z mikk $
-- @release $Id: CallbackHandler-1.0.lua 22 2018-07-21 14:17:22Z nevcairiel $
-- @patch $Id: LibStub.lua 14.1 2019-01 Mongusius, MINOR: 6 -> 8
-- @patch $Id: LibStub.lua 22.1 2019-01 Mongusius, MINOR: 7 -> 8

--- Revision 7 replaces the complex Dispatchers with BfA's xpcall(unsafeFunc, errorhandler, args...)
-- that finally passes args just like  pcall(unsafeFunc, args...)  and Lua 5.3 and Lua 5.2's xpcall().

--- Revision 8:
-- Added safecall() from AceAddon-3.0 and AceBucket-3.0 with an updated implementation
-- Added an alternative Dispatchers implementation without loadstring() (dynamic code)
-- 
--- Usage:  from the event source/producer/sender
-- local registry = CallbackHandler:New(sender, RegisterName, UnregisterName, UnregisterAllName)
-- registry:Fire(eventname, ...)

--- Usage:  from the event listener/consumer/receiver
-- sender.RegisterCallback(receiver, eventname, functionrefOrMethodname[, arg])
-- sender.UnregisterCallback(receiver, eventname)
-- sender.UnregisterAllCallbacks(...eventnames)


local MAJOR, MINOR = "CallbackHandler-1.0", 7.1
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then  return  end -- No upgrade needed

-- Upvalued Lua globals:
local G, xpcall, tconcat = _G, xpcall, table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler


-- Export to _G:  CallbackHandler, CallbackHandler.Dispatch(callbacks, args...)
G.CallbackHandler = G.CallbackHandler or CallbackHandler

-- Export to LibShared:  errorhandler
local LibShared = G.LibShared or {}  ;  G.LibShared = LibShared

--- LibShared. errorhandler(errorMessage):  Report error. Calls G.geterrorhandler(), without tailcall to generate readable stacktrace.
LibShared.errorhandler = LibShared.errorhandler or  function(errorMessage)  local errorhandler = G.geterrorhandler() ; return errorhandler(errorMessage) or errorMessage  end
local errorhandler = LibShared.errorhandler

-- Forward declaration.
local Dispatch, Dispatchers

-- 
local RegistryMixin = CallbackHandler.RegistryMixin or {}
CallbackHandler.RegistryMixin = RegistryMixin



if  select(4, GetBuildInfo()) >= 80000  then

	----------------------------------------
	--- Battle For Azeroth Addon Changes
	-- https://us.battle.net/forums/en/wow/topic/20762318007
	-- • xpcall now accepts arguments like pcall does
	--

	--[[ $Id: CallbackHandler-1.0.lua 22 2018-07-21 14:17:22Z nevcairiel $  MINOR = 7
	local function Dispatch(handlers, ...)
		local index, method = next(handlers)
		if not method then return end

		repeat
			xpcall(method, errorhandler, ...)
			index, method = next(handlers, index)
		until not method
	end
	--]]

	-- local
	function Dispatch(callbacks, ...)
		local callbacksRan, ok = 0
		-- local errorhandler = G.geterrorhandler()
		for  receiver,callback  in  next, callbacks  do
			if  type(callback) ~= 'string'
			then  ok = xpcall(callback, errorhandler, ...)
			else  ok = xpcall(receiver[callback], errorhandler, receiver, ...)
			end
			if ok then  callbacksRan = callbacksRan + 1  end
		end
		return callbacksRan
	end



else -- if  select(4, GetBuildInfo()) < 80000  then

	--------------------------------------------------------------------------
	--- CallbackHandler. DispatchWrapped(callbacks, ...)
	--
	function CallbackHandler.DispatchWrapped(callbacks, ...)
		if  not next(callbacks)  then  return 0  end

		local wrapper, closure = CallWrapper(...)
		local callbacksRan, ok = 0
		-- local errorhandler = G.geterrorhandler()
		for  receiver,callback  in  next, callbacks  do
			if  type(callback) ~= 'string'
			then  closure = wrapper(callback)
			else  closure = wrapper(receiver[callback], receiver)
			end
			local ok = xpcall(closure, errorhandler)
			if ok then  callbacksRan = callbacksRan + 1  end
		end
		return callbacksRan
	end




	--------------------------------------------------------------------------
	--- CallbackHandler. DispatchFixedArgs(callbacks, ...)
	--
	-- local
	Dispatchers = {}
	-- Dispatchers[argNum](callbacks, arg1, arg2, ...)
	local dispatcherCreator = [===[
		local next, xpcall, errorhandler = ...

		local function dispatcher(callbacks, ...)
			if  not next(callbacks)  then  return 0  end

			-- local errorhandler = errorhandler or geterrorhandler()
			local callback, selfArg
			local ARGS = ...
			local function functionClosure()  return callback(ARGS)  end
			local function methodClosure()    return callback(selfArg, ARGS)  end

			local callbacksRan = 0
			for  receiver,method  in  next, callbacks  do
				selfArg = receiver
				if type(method) ~= 'string'
				then  callback,closure = method, functionClosure
				else  callback,closure = receiver[method], methodClosure
				end
				local ok = xpcall(closure, errorhandler)
				if ok then  callbacksRan = callbacksRan + 1  end
			end
			return callbacksRan
		end

		return dispatcher
	]===]

	function Dispatchers:CreateDispatcher(argNum)
		assert(0 < argNum)    -- argNum == 0 generates invalid lua:  local  = ...
		local ARGS = {}
		for i = 1, argNum do ARGS[i] = "a"..i end
		local sourcecode = dispatcherCreator:gsub("ARGS", tconcat(ARGS, ","))
		local creator = assert( loadstring(sourcecode, "CallbackHandler.Dispatchers[argNum="..argNum.."]") )
		local dispatcher = creator(next, xpcall, errorhandler)
		self[argNum] = dispatcher
		return dispatcher
	end

	setmetatable(Dispatchers, { __index = Dispatchers.CreateDispatcher })

	local function DispatchFixedArgs(callbacks, ...)
		-- Avoid tailcall with `true and`. Tailcalls show up as '?' in the callstack in error reports, making it hard to identify.
		-- We don't want that at an error catching hotspot.
		local dispatcher = Dispatchers[ select('#',...) ]
		return true and dispatcher(...)
	end

end -- DispatchFixedArgs




-- Choose the Dispatch implementation to use.
Dispatch = Dispatch
	or CallbackHandler.DispatchWrapped
	or CallbackHandler.DispatchFixedArgs
	or CallbackHandler.DispatchDynamic




--------------------------------------------------------------------------
-- CallbackHandler:New(sender, RegisterName, UnregisterName, UnregisterAllName)
--
--   sender            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.

function CallbackHandler:New(sender, RegisterName, UnregisterName, UnregisterAllName, OnUsed, OnUnused)
	RegisterName   = RegisterName   or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the `sender` parameter, etc


	-- Create the registry object
	local registry = { recurse = 0, events = {} }
	-- registry.events = setmetatable({}, LibShared.QueryTableMeta)
	for k,v in pairs(RegistryMixin) do  registry[k] = v  end


	--------------------------------------------------------------------------
	-- registry:Fire(eventname, ...) - fires the given event/message into the registry
	--
	-- Event trigger part of internal registry API:
	-- self is abused on :Fire(), so make a closure that sets self.
	function registry:Fire(eventname, ...)  RegistryMixin.Fire(registry, eventname, ...)  end


	--------------------------------------------------------------------------
	-- Register a callback
	-- sender[RegisterName](receiver, eventname, functionrefOrMethodname[, arg])
	-- default:
	-- sender.RegisterCallback(receiver, eventname, functionrefOrMethodname[, arg])
	-- embedded:
	-- receiver:[RegisterName](eventname, functionrefOrMethodname[, arg])
	-- receiver:RegisterEvent(eventname, functionrefOrMethodname[, arg])
	-- receiver:RegisterMessage(eventname, functionrefOrMethodname[, arg])
	--
	-- eventname  is the event to listen for
	-- receiver  is a table or a string ("addonId") that identifies the event handler
	-- functionrefOrMethodname  is the function or name of method on receiver to call
	--   "methodname" calls:  receiver["methodname"](receiver, [arg,] ...eventparameters)
	--   functionref calls:  functionref([arg,] ...eventparameters)
	--   with functionref receiver can be a table or "addonId"
	-- all with an optional arg, which, if present, gets passed as first argument (after self if calling method)

	sender[RegisterName] = function(receiver, eventname, method, ... --[[actually just a single arg]])
		if type(eventname) ~= "string" then
			error("Usage: receiver:"..RegisterName.."(eventname, method[, arg]): `eventname` - string expected, but '"..type(unsafeFunc).."' received.", 2)
		end

		method = method or eventname

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: receiver:"..RegisterName.."(eventname, methodname[, arg]): `methodname` - string or function expected, but '"..type(unsafeFunc).."' received.", 2)
		end

		local callback

		if type(method) == "string" then
			-- receiver["method"] calling style
			if type(receiver) ~= "table" then
				error("Usage: receiver:"..RegisterName.."(`eventname`, `methodname`): receiver was not a table?", 2)
			elseif receiver == sender then
				error("Usage: receiver:"..RegisterName.."(`eventname`, `methodname`): do not use Library:"..RegisterName.."(), use your own object as self/`receiver`", 2)
			elseif type(receiver[method]) ~= "function" then
				error("Usage: receiver:"..RegisterName.."(`eventname`, `methodname`): `methodname` - method '"..tostring(method).."' not found on self/`receiver`.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg = ...
				callback = function(...)  receiver[method](receiver,arg,...)  end
			else
				-- This is the fast path used most commonly with  self:RegisterEvent(method). Calls method directly, without an additional call thunk.
				callback = method
				-- callback = function(...)  receiver[method](receiver,...)  end
			end
		else
			-- function ref with receiver=object or receiver="addonId" or receiver=thread
			if type(receiver)~="table" and type(receiver)~="string" and type(receiver)~="thread" then
				error("Usage: sender."..RegisterName.."(receiver or 'addonId', eventname, method):  `receiver`: table or string or thread expected.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg = ...
				callback = function(...)  method(arg,...)  end
			else
				-- callback = function(...)  method(...)  end
				callback = method
			end
		end

		registry:AddCallback(eventname, receiver, callback)
	end


	--------------------------------------------------------------------------
	-- Unregister a callback
	-- sender[UnregisterName](receiver, eventname)
	-- default:
	-- sender.UnregisterCallback(receiver, eventname)
	--
	-- eventname  is the event the handler is registered for
	-- receiver  is the table or a string ("addonId") that identifies the event handler

	sender[UnregisterName] = function(receiver, eventname)
		if not receiver or receiver == sender then
			error("Usage: receiver:"..UnregisterName.."(eventname): use your own object as `receiver`/self", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: receiver:"..UnregisterName.."(eventname): `eventname` - string expected.", 2)
		end
		local callbacks = registry.events[eventname]
		if callbacks and callbacks[receiver] then
			callbacks[receiver] = nil
			-- Fire OnUnused callback?
			if registry.OnUnused and not next(callbacks) then
				registry:OnUnused(sender, eventname)
			end
		end

		LibShared.removeIf(registry.insertQueue, function(newcb)  return newcb[1] == eventname and newcb[2] == receiver  end)
	end


	--------------------------------------------------------------------------
	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	-- sender[UnregisterAllName](...receivers)
	-- default:
	-- sender.UnregisterAllCallbacks(...receivers)
	--
	-- receivers  objects or "addonId"s that unregister all callbacks

	if UnregisterAllName then
		sender[UnregisterAllName] = function(...)
			local last = select("#",...)
			if last < 1 then
				error("Usage: sender."..UnregisterAllName.."(receiver*/addonId*): missing `receiver` or 'addonId' to unregister events for.", 2)
			end
			if last == 1 and ... == sender then
				error("Usage: receiver:"..UnregisterAllName.."(): use your own object as self/`receiver`", 2)
			end

			local count = 0
			for i=1,last do
				local receiver = select(i,...)
				count = count + LibShared.removeIf(registry.insertQueue, function(newcb)  return newcb[2] == receiver  end)

				for eventname, callbacks in pairs(registry.events) do
					if callbacks[receiver] then
						callbacks[receiver] = nil
						count = count + 1
						-- Fire OnUnused callback?
						if registry.OnUnused and not next(callbacks) then
							registry:OnUnused(sender, eventname)
						end
					end
				end
			end
			return count
		end
	end

	--[[
	if sender.mixin then
		sender.mixin[RegisterName]   = sender[RegisterName]
		sender.mixin[UnregisterName] = sender[UnregisterName]
		if UnregisterAllName then  sender.mixin[UnregisterAllName] = sender[UnregisterAllName]  end
	end
	--]]

	return registry
end




function RegistryMixin:Fire(eventname, ...)
	local callbacks = self.events[eventname]
	if not callbacks or not next(callbacks) then return nil end

	local oldrecurse = self.recurse
	self.recurse = oldrecurse + 1

	local Dispatch =  Dispatchers and Dispatchers[1 + select('#',...)]  or  Dispatch
	local callbacksRan = Dispatch(callbacks, eventname, ...)

	self.recurse = oldrecurse


	-- A callback handler registered another callback while :Fire() was iterating the callbacks. Adding it was delayed until finished iterating.
	if self.insertQueue and oldrecurse==0 then
		local queue = self.insertQueue
		self.insertQueue = nil
		for i,newcb in ipairs(queue) do
			self:AddCallback( unpack(newcb) )
		end
	end
	
	-- Return number of successful callbacks.
	return callbacksRan
end



function RegistryMixin:AddCallback(eventname, receiver, callback)
	local callbacks = self.events[eventname]
	if not callbacks then  callbacks = {}  ;  self.events[eventname] = callbacks  end

	if callbacks[receiver] or self.recurse<1 then
		local first = not next(callbacks)	-- test for empty before. not test for one member after. that one member may have been overwritten.
		-- Overwriting or removing a field is safe even while :Fire() is iterating over the table. Lua ensures the order of iteration remains the same.
		callbacks[receiver] = callback
		-- Fire OnUsed callback?
		if self.OnUsed and first then
			self:OnUsed(sender, eventname)
		end
	else
		-- Adding a new item to the callbacks table while it is iterated would change the order of iteration, causing some callbacks to be called twice, some not at all.
		-- To avoid this delay adding the callback until all handlers are iterated.
		local queue = self.insertQueue or {}
		self.insertQueue = queue
		queue[#queue+1] = { eventname, receiver, callback }
	end
end




-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.


---------------------------------------------------------
-- Export CallbackHandler.Dispatch(callbacks, args...)
--
CallbackHandler.Dispatch = Dispatch


