--[[ $Id: CallbackHandler-1.0.lua 965 2010-08-09 00:47:52Z mikk $ ]]
-- @name CallbackHandler-1.0.lua
-- @release $Id: CallbackHandler-1.0.lua 965 2010-08-09 00:47:52Z mikk $
-- @patch $Id: LibStub.lua 965.1 2019-01 Mongusius, MINOR: 6 -> 6.1
-- 6.1 added safecall() from AceAddon-3.0 and AceBucket-3.0 with an updated implementation
-- added an alternative implementation without loadstring() (dynamic code)
-- 
-- Creating and using a CallbackHandler registry (details below):
-- local registry = CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
-- registry:Fire(eventname, ...)
-- target[RegisterName](receiver, eventname, functionrefOrMethodname[, arg])
-- target[UnregisterName](receiver, eventname)
-- target[UnregisterAllName](...eventnames)
--
-- Features exported to Global environment:  CallbackHandler, safecall(), AutoCreateTablesMeta
-- CallbackHandler.safecall(), CallbackHandler.AutoCreateTablesMeta

local MAJOR, MINOR = "CallbackHandler-1.0", 6.1
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end -- No upgrade needed

-- Lua APIs
local _G, tconcat = _G, table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring
local xpcall = xpcall

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

-- Forward declaration
local safecall

--------------------------------------------------------------------------
-- AutoCreateTablesMeta: metatable that automatically creates empty inner tables when keys are first referenced.

local AutoCreateTablesMeta = {__index = function(self, key) self[key] = {} return self[key] end}
CallbackHandler.AutoCreateTablesMeta = AutoCreateTablesMeta
_G.AutoCreateTablesMeta = AutoCreateTablesMeta


--------------------------------------------------------------------------
-- safecall(unsafeFunc, arg1, arg2, ...)
--
-- Similar to pcall(unsafeFunc, arg1, arg2, ...)
-- with proper errorhandler while executing unsafeFunc.

local function dispatcherErrorHandler(err)  return _G.geterrorhandler()(err)  end

if  not safecall  then

	local SafecallDispatchers = {}
	function SafecallDispatchers:CreateDispatcher(argCount)
		local sourcecode = [===[
			local xpcall, errorhandler = ...
			local unsafeFuncUp, ARGS
			local function safecallThunk()  return unsafeFuncUp(ARGS)  end
			
			local function dispatcher(unsafeFunc, ...)
				 unsafeFuncUp, ARGS = unsafeFunc, ...
				 return xpcall(safecallThunk, errorhandler)
			end
			
			return dispatcher
		]===]

		local ARGS = {}
		for i = 1, argCount do ARGS[i] = "a"..i end
		sourcecode = sourcecode:gsub("ARGS", tconcat(ARGS, ","))
		local creator = assert(loadstring(sourcecode, "SafecallDispatchers[argCount="..argCount.."]"))
		local dispatcher = creator(xpcall, errorhandler)
		rawset(self, argCount, dispatcher)
		return dispatcher
	end
	setmetatable(SafecallDispatchers, { __index = SafecallDispatchers.CreateDispatcher })

	SafecallDispatchers[0] = function(unsafeFunc)
		return xpcall(unsafeFunc, dispatcherErrorHandler)
	end

	function safecall(unsafeFunc, ...)
		-- we check to see if unsafeFunc is actually a function here and don't error when it isn't
		-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
		-- present execution should continue without hinderance
		if type(unsafeFunc) ~= "function" then  return  end
		local dispatcher = SafecallDispatchers[select('#',...)]
		return dispatcher(unsafeFunc, ...)
	end

end



--------------------------------------------------------------------------
-- safecall(unsafeFunc, arg1, arg2, ...)
--
-- Alternative implementation without loadstring() (dynamic code).
-- Handles any number of arguments by packing them in an array and unpacking in the safecallThunk.
-- Simpler and probably slower with an extra array creation on each call.
-- Easier to recognize in a callstack.

if  not safecall  then

	function safecall(unsafeFunc, ...)
		-- we check to see if the unsafeFunc passed is actually a function here and don't error when it isn't
		-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
		-- present execution should continue without hinderance
		if type(unsafeFunc) ~= "function" then  return  end
		
		-- Without parameters call the function directly
		local argsCount = select('#',...)
		if  0 == argsCount  then
			-- return xpcall(unsafeFunc, _G.geterrorhandler())
			return xpcall(unsafeFunc, dispatcherErrorHandler)
		end

		-- Pack the parameters to pass to the actual function
		local args = { ... }
		-- Unpack the parameters in the thunk
		local function safecallThunk()  return unsafeFunc( unpack(args,1,argsCount) )  end
		-- Do the call through the thunk
		-- return xpcall(safecallThunk, _G.geterrorhandler())
		return xpcall(safecallThunk, dispatcherErrorHandler)
	end

end


--------------------------------------------------------------------------
-- Export in library and global namespace

CallbackHandler.safecall = safecall
_G.safecall = safecall




local Dispatchers = {}
function Dispatchers:CreateDispatcher(argCount)
	local sourcecode = [===[
		local next, xpcall, errorhandler = ...
		
		local function dispatcher(callbacks, ...)
			if  not next(callbacks)  then  return 0  end
			local unsafeFunc, ARGS = nil, ...
			local function xpcallThunk()  return unsafeFunc(ARGS)  end
			local callbacksRan = 0
			for  key, callback  in  next, callbacks  do
				unsafeFunc = callback
				local ran = xpcall(xpcallThunk, errorhandler)
				if  ran  then  callbacksRan = callbacksRan + 1  end
			end
			return callbacksRan
		end
		
		return dispatcher
	]===]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "a"..i end
	sourcecode = sourcecode:gsub("ARGS", tconcat(ARGS, ","))
	local creator = assert(loadstring(sourcecode, "CallbackHandler.Dispatchers[argCount="..argCount.."]"))
	local dispatcher = creator(next, xpcall, dispatcherErrorHandler)
	rawset(self, argCount, dispatcher)
	return dispatcher
end

--[[
local function Dispatchers:CreateDispatcher(argCount)
	local sourcecode = [===[
		local next, xpcall, errorhandler = ...
		
		local unsafeFunc, ARGS
		local function xpcallThunk()  return unsafeFunc(ARGS)  end
		
		local function dispatcher(callbacks, ...)
			local index
			index, unsafeFunc = next(callbacks)
			if  not unsafeFunc  then  return 0  end
			local SAVED = ARGS
			ARGS = ...
			local callbacksRan = 0
			repeat
				local ran = xpcall(xpcallThunk, errorhandler)
				if  ran  then  callbacksRan = callbacksRan + 1  end
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
	local dispatcher = creator(next, xpcall, dispatcherErrorHandler)
	rawset(self, argCount, dispatcher)
	return dispatcher
end
--]]

setmetatable(Dispatchers, { __index = Dispatchers.CreateDispatcher })




--------------------------------------------------------------------------
-- CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName, OnUsed, OnUnused)
	-- TODO: Remove this after beta has gone out
	assert(not OnUsed and not OnUnused, "ACE-80: OnUsed/OnUnused are deprecated. Callbacks are now done to registry.OnUsed and registry.OnUnused")

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, AutoCreateTablesMeta)
	local registry = { recurse=0, events=events }


	--------------------------------------------------------------------------
	-- registry:Fire() - fires the given event/message into the registry
	--
	-- Event trigger part of internal registry API:

	function registry:Fire(eventname, ...)
		local callbacks = rawget(events, eventname)
		if not callbacks or not next(callbacks) then return nil end

		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		local dispatcher = Dispatchers[select('#',...) + 1]
		local callbacksRan = dispatcher(callbacks, eventname, ...)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for receiver,callback in pairs(callbacks) do
					events[eventname][receiver] = callback
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
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
	-- target[RegisterName](receiver, eventname, functionrefOrMethodname[, arg])
	-- default:
	-- target.RegisterCallback(receiver, eventname, functionrefOrMethodname[, arg])
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

	target[RegisterName] = function(receiver, eventname, method, ... --[[actually just a single arg]])
		if type(eventname) ~= "string" then
			error("Usage: receiver:"..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: receiver:"..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - string or function expected.", 2)
		end

		local regfunc

		if type(method) == "string" then
			-- receiver["method"] calling style
			if type(receiver) ~= "table" then
				error("Usage: receiver:"..RegisterName.."(\"eventname\", \"methodname\"): receiver was not a table?", 2)
			elseif receiver == target then
				error("Usage: receiver:"..RegisterName.."(\"eventname\", \"methodname\"): do not use Library:"..RegisterName.."(), use your own object as 'self/receiver'", 2)
			elseif type(receiver[method]) ~= "function" then
				error("Usage: receiver:"..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - method '"..tostring(method).."' not found on 'self/receiver'.", 2)
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
				error("Usage: target."..RegisterName.."(receiver or \"addonId\", eventname, method): 'receiver or addonId': table or string or thread expected.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg = ...
				regfunc = function(...) method(arg,...) end
			else
				regfunc = method
			end
		end

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if events[eventname][receiver] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			events[eventname][receiver] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable({}, AutoCreateTablesMeta)
			registry.insertQueue[eventname][receiver] = regfunc
		end
	end


	--------------------------------------------------------------------------
	-- Unregister a callback
	-- target[UnregisterName](receiver, eventname)
	-- default:
	-- target.UnregisterCallback(receiver, eventname)
	--
	-- eventname  is the event the handler is registered for
	-- receiver  is the table or a string ("addonId") that identifies the event handler

	target[UnregisterName] = function(receiver, eventname)
		if not receiver or receiver == target then
			error("Usage: receiver:"..UnregisterName.."(eventname): use your own object as 'receiver/receiver'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: receiver:"..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		local callbacks = rawget(events, eventname)
		if callbacks and callbacks[receiver] then
			callbacks[receiver] = nil
			-- Fire OnUnused callback?
			if registry.OnUnused and not next(callbacks) then
				registry.OnUnused(registry, target, eventname)
			end
		end
		local queuedCallbacks = registry.insertQueue and rawget(registry.insertQueue, eventname)
		if queuedCallbacks and queuedCallbacks[receiver] then
			queuedCallbacks[receiver] = nil
		end
	end


	--------------------------------------------------------------------------
	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	-- target[UnregisterAllName](...receivers)
	-- default:
	-- target.UnregisterAllCallbacks(...receivers)
	--
	-- receivers  objects or "addonId"s that unregister all callbacks

	if UnregisterAllName then
		target[UnregisterAllName] = function(...)
			local last = select("#",...)
			if last < 1 then
				error("Usage: target."..UnregisterAllName.."([whatFor]): missing 'receiver' or \"addonId\" to unregister events for.", 2)
			end
			if last == 1 and ... == target then
				error("Usage: receiver:"..UnregisterAllName.."([whatFor]): use your own object as 'self/receiver' or \"addonId\"", 2)
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
							registry.OnUnused(registry, target, eventname)
						end
					end
				end
			end
			return count
		end
	end

	return registry
end


-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.

