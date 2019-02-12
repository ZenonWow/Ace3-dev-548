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
-- Exports LibCommon.AutoTablesMeta for AceAddon, AceHook
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
local _G, xpcall, tconcat = _G, xpcall, table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler


-- Export to _G:  CallbackHandler, CallbackHandler.Dispatch(callbacks, args...)
_G.CallbackHandler = _G.CallbackHandler or CallbackHandler

-- Export to LibCommon:  AutoTablesMeta, errorhandler
local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon

-- AutoTablesMeta: metatable that automatically creates empty inner tables when keys are first referenced.
LibCommon.AutoTablesMeta = LibCommon.AutoTablesMeta or { __index = function(self, key)  if key ~= nil then  local v={} ; self[key]=v ; return v  end  end }
local AutoTablesMeta = LibCommon.AutoTablesMeta

-- Allow hooking _G.geterrorhandler(): don't cache/upvalue it or the errorhandler returned.
-- Avoiding tailcall: errorhandler() function would show up as "?" in stacktrace, making it harder to understand.
LibCommon.errorhandler = LibCommon.errorhandler or  function(errorMessage)  return true and _G.geterrorhandler()(errorMessage)  end
local errorhandler = LibCommon.errorhandler

-- Forward declaration.
local Dispatch, Dispatchers



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
		-- local errorhandler = _G.geterrorhandler()
		for  key, callback  in  next, callbacks  do
			ok = xpcall(callback, errorhandler, ...)
			if  ok  then  callbacksRan = callbacksRan + 1  end
		end
		return callbacksRan
	end

	--[[
	-- local
	function Dispatch(callbacks, ...)
		local callbacksRan, ok = 0
		-- local errorhandler = _G.geterrorhandler()
		for  receiver, callback  in  next, callbacks  do
			if  type(callback) == 'function'  then
				ok = xpcall(callback, errorhandler, ...)
			else
				ok = xpcall(receiver[callback], errorhandler, receiver, ...)
			end
			if  ok  then  callbacksRan = callbacksRan + 1  end
		end
		return callbacksRan
	end
	--]]



else  -- if  select(4, GetBuildInfo()) < 80000  then

	--------------------------------------------------------------------------
	-- Dispatchers[argCount](callbacks, arg1, arg2, ...)

	-- local
	Dispatchers = {}
	function Dispatchers:CreateDispatcher(argCount)
		local sourcecode = [===[
			local next, xpcall, errorhandler = ...

			local function dispatcher(callbacks, ...)
				if  not next(callbacks)  then  return 0  end

				-- local errorhandler = errorhandler or geterrorhandler()
				local unsafeFunc, ARGS = nil, ...
				local function xpcallClosure()  return unsafeFunc(ARGS)  end

				local callbacksRan = 0
				for  key, callback  in  next, callbacks  do
					unsafeFunc = callback
					local ok = xpcall(xpcallClosure, errorhandler)
					if  ok  then  callbacksRan = callbacksRan + 1  end
				end
				return callbacksRan
			end

			return dispatcher
		]===]

		local ARGS = {}
		for i = 1, argCount do ARGS[i] = "a"..i end
		sourcecode = sourcecode:gsub("ARGS", tconcat(ARGS, ","))
		local creator = assert(loadstring(sourcecode, "CallbackHandler.Dispatchers[argCount="..argCount.."]"))
		local dispatcher = creator(next, xpcall, errorhandler)
		rawset(self, argCount, dispatcher)
		return dispatcher
	end

	--[[
	local function Dispatchers:CreateDispatcher(argCount)
		local sourcecode = [===[
			local next, xpcall, errorhandler = ...
			
			local unsafeFunc, ARGS
			local function xpcallClosure()  return unsafeFunc(ARGS)  end

			local function dispatcher(callbacks, ...)
				local index
				index, unsafeFunc = next(callbacks)
				if  not unsafeFunc  then  return 0  end

				-- local errorhandler = errorhandler or geterrorhandler()
				local SAVED = ARGS
				ARGS = ...

				local callbacksRan = 0
				repeat
					local ok = xpcall(xpcallClosure, errorhandler)
					if  ok  then  callbacksRan = callbacksRan + 1  end
					index, unsafeFunc = next(callbacks, index)
				until not unsafeFunc

				ARGS = SAVED
				return callbacksRan
			end

			return dispatcher
		]===]

		local ARGS, SAVED = {}, {}
		for i = 1, argCount do ARGS[i], SAVED[i] = "a"..i, "s"..i end
		sourcecode = sourcecode:gsub("SAVED", tconcat(SAVED, ",")):gsub("ARGS", tconcat(ARGS, ","))
		local creator = assert(loadstring(sourcecode, "SafecallDispatchers[argCount="..argCount.."]"))
		local dispatcher = creator(next, xpcall, errorhandler)
		rawset(self, argCount, dispatcher)
		return dispatcher
	end
	--]]

	setmetatable(Dispatchers, { __index = Dispatchers.CreateDispatcher })

	--------------------------------------------------------------------------
	-- DispatchFixedArgs(callbacks, ...)
	--
	local function DispatchFixedArgs(callbacks, ...)
		-- Avoid tailcall with `true and`. Tailcalls show up as '?' in the callstack in error reports, making it hard to identify.
		-- We don't want that at an error catching hotspot.
		return true and Dispatchers[select('#',...)](...)
	end



	--------------------------------------------------------------------------
	-- DispatchDynamic(callbacks, ...)
	--
	-- local EMPTYTABLE = setmetatable({}, { __newindex = false })
	--
	local function DispatchDynamic(callbacks, ...)
		if  not next(callbacks)  then  return 0  end

		local argsCount, unsafeFunc, xpcallClosure = select('#',...)
		-- local receiver,methodClosure
		-- local receiver,args,universalClosure
		-- local receiver,args,universalClosure = nil, EMPTYTABLE, function()  if receiver then  receiver[unsafeFunc]( receiver, unpack(args,1,argsCount) )  else  unsafeFunc( unpack(args,1,argsCount) )  end
		-- local receiver,args,universalClosure = nil, {...}, function()  if args[0] then  args[0][unsafeFunc]( unpack(args,0,argsCount) )  else  unsafeFunc( unpack(args,1,argsCount) )  end
		if  0 < argsCount  then
			-- Pack the parameters in a closure to pass to the actual function.
			local args = {...}
			-- Unpack the parameters in the closure.
			xpcallClosure = function()  unsafeFunc( unpack(args,1,argsCount) )  end
			-- methodClosure = function()  receiver[unsafeFunc]( receiver, unpack(args,1,argsCount) )  end
			-- universalClosure = function()  if receiver then  receiver[unsafeFunc]( receiver, unpack(args,1,argsCount) )  else  unsafeFunc( unpack(args,1,argsCount) )  end
		-- else
			-- methodClosure = function()  receiver[unsafeFunc]( receiver )  end
			-- universalClosure = function()  if receiver then  receiver[unsafeFunc]( receiver )  else  unsafeFunc()  end
		end

		local callbacksRan = 0
		-- local errorhandler = _G.geterrorhandler()
		for  key, callback  in  next, callbacks  do
			unsafeFunc = callback
			--[[
			receiver =  type(unsafeFunc) ~= 'function'  and  key
			local closure =  argsCount == 0 and not receiver  and  unsafeFunc  or  xpcallClosure
			local closure =  receiver and methodClosure  or  xpcallClosure or unsafeFunc
			local ok = xpcall(closure, errorhandler)
			--]]
			local ok = xpcall(xpcallClosure or unsafeFunc, errorhandler)
			if  ok  then  callbacksRan = callbacksRan + 1  end
		end
		return callbacksRan
	end


	-- Choose the Dispatch implementation to use.
	Dispatch = DispatchFixedArgs

end  -- if  select(4, GetBuildInfo()) < 80000




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
	-- local events = setmetatable({}, AutoTablesMeta)
	local events = {}
	local registry = { recurse=0, events=events }


	--------------------------------------------------------------------------
	-- registry:Fire(eventname, ...) - fires the given event/message into the registry
	--
	-- Event trigger part of internal registry API:

	function registry:Fire(eventname, ...)
	-- function registry.Fire(registry, eventname, ...)
		-- local events = self.events
		local callbacks = events[eventname]
		if not callbacks or not next(callbacks) then return nil end

		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		local dispatcher =  Dispatchers and Dispatchers[1 + select('#',...)]  or  Dispatch
		local callbacksRan = dispatcher(callbacks, eventname, ...)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,newcallbacks in pairs(registry.insertQueue) do
				local callbacks = events[eventname]
				local first = not callbacks or not next(callbacks)	-- test for empty before. not test for one member after. that one member may have been overwritten.
				if not callbacks then  callbacks = {}  ;  events[eventname] = callbacks  end

				for receiver,callback in pairs(newcallbacks) do
					callbacks[receiver] = callback
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, sender, eventname)
						first = nil
					end
				end
			end
			registry.insertQueue = nil
		end
		
		-- Return number of successful callbacks.
		return callbacksRan
	end


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

		local regfunc

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
				regfunc = function(...) receiver[method](receiver,arg,...) end
			else
				regfunc = function(...) receiver[method](receiver,...) end
			end
		else
			-- function ref with receiver=object or receiver="addonId" or receiver=thread
			if type(receiver)~="table" and type(receiver)~="string" and type(receiver)~="thread" then
				error("Usage: sender."..RegisterName.."(receiver or 'addonId', eventname, method):  `receiver`: table or string or thread expected.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg = ...
				regfunc = function(...) method(arg,...) end
			else
				regfunc = method
			end
		end

		local callbacks = events[eventname]
		local first = not callbacks or not next(callbacks)	-- test for empty before. not test for one member after. that one member may have been overwritten.
		if not callbacks then  callbacks = {}  ;  events[eventname] = callbacks  end

		if callbacks[receiver] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			callbacks[receiver] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, sender, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable({}, AutoTablesMeta)
			registry.insertQueue[eventname][receiver] = regfunc
		end
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
		local callbacks = events[eventname]
		if callbacks and callbacks[receiver] then
			callbacks[receiver] = nil
			-- Fire OnUnused callback?
			if registry.OnUnused and not next(callbacks) then
				registry.OnUnused(registry, sender, eventname)
				LibProfiling.CallbackHandler:inc('OnUnused')
			end
		end
		local queuedCallbacks = registry.insertQueue and rawget(registry.insertQueue, eventname)
		if queuedCallbacks and queuedCallbacks[receiver] then
			queuedCallbacks[receiver] = nil
		end
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
				if registry.insertQueue then
					for eventname, callbacks in pairs(registry.insertQueue) do
						if callbacks[receiver] then
							callbacks[receiver] = nil
							count = count + 1
						end
					end
				end
				for eventname, callbacks in pairs(events) do
					if callbacks[receiver] then
						callbacks[receiver] = nil
						count = count + 1
						-- Fire OnUnused callback?
						if registry.OnUnused and not next(callbacks) then
							registry.OnUnused(registry, sender, eventname)
						end
					end
				end
			end
			return count
		end
	end

	if sender.mixins then
		sender.mixins[RegisterName]   = sender[RegisterName]
		sender.mixins[UnregisterName] = sender[UnregisterName]
		if UnregisterAllName then  sender.mixins[UnregisterAllName] = sender[UnregisterAllName]  end
	end

	return registry
end


-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.


---------------------------------------------------------
-- Export CallbackHandler.Dispatch(callbacks, args...)
--
CallbackHandler.Dispatch = Dispatch


