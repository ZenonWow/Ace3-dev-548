--[[ $Id: CallbackHandler-1.0.lua 14 2010-08-09 00:43:38Z mikk $ ]]
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



-- Export to global: metatable that auto-creates empty inner tables when first referenced.
local AutoInnerTablesMeta = {__index = function(self, key) self[key] = {} return self[key] end}
CallbackHandler.AutoInnerTablesMeta = AutoInnerTablesMeta
_G.AutoInnerTablesMeta = AutoInnerTablesMeta



--[=[
---- safecall(unsafeFunc, arg1, arg2, ...) == pcall(unsafeFunc, arg1, arg2, ...) with errorhandler, using xpcall
--]=]

local function dispatcherErrorHandler(err)  return _G.geterrorhandler()(err)  end

----[=[
local function CreateDispatcher(argCount)
	local code = [===[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end
	
		local function dispatch(func, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh)
		end
	
		return dispatch
	]===]
	
	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "a"..i end
	code = code:gsub("ARGS", tconcat(ARGS, ","))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, dispatcherErrorHandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})
Dispatchers[0] = function(func)
	return xpcall(func, dispatcherErrorHandler)
end

local function safecall(func, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, ...)
	end
end
--]=]


--[=[ Alternative implementation with any number of arguments packed in an array and unpacked. Probably slower.
local function safecall(unsafeFunc, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(unsafeFunc) ~= "function" then  return  end
	
	-- Without parameters call the function directly
	local nParams = select('#',...)
	if  0 == nParams  then
		-- return xpcall(unsafeFunc, _G.geterrorhandler())
		return xpcall(unsafeFunc, safecallErrorHandler)
	end

	-- Pack the parameters to pass to the actual function
	local tParams = { ... }
	-- Unpack the parameters in the thunk
	local function safecallThunk()  return unsafeFunc( unpack(tParams,1,nParams) )  end
	-- Do the call through the thunk
	-- return xpcall(safecallThunk, _G.geterrorhandler())
	return xpcall(safecallThunk, safecallErrorHandler)
end
--]=]


-- Export to global namespace
CallbackHandler.safecall = safecall
_G.safecall = safecall




local function CreateDispatcher(argCount)
	local code = [[
	local next, xpcall, eh = ...

	local method, ARGS
	local function call() method(ARGS) end

	local function dispatch(handlers, ...)
		local handlersRan, index = 0
		index, method = next(handlers)
		if not method then return end
		local OLD_ARGS = ARGS
		ARGS = ...
		repeat
			local ran = xpcall(call, eh)
			if ran then handlersRan = handlersRan + 1 end
			index, method = next(handlers, index)
		until not method
		ARGS = OLD_ARGS
		return handlersRan
	end

	return dispatch
	]]

	local ARGS, OLD_ARGS = {}, {}
	for i = 1, argCount do ARGS[i], OLD_ARGS[i] = "a"..i, "o"..i end
	code = code:gsub("OLD_ARGS", tconcat(OLD_ARGS, ",")):gsub("ARGS", tconcat(ARGS, ","))
	return assert(loadstring(code, "CallbackHandler Dispatcher["..argCount.."]"))(next, xpcall, dispatcherErrorHandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
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
	local events = setmetatable({}, AutoInnerTablesMeta)
	local registry = { recurse=0, events=events }

	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, ...)
		local handlers = rawget(events, eventname)
		if not handlers or not next(handlers) then return nil end

		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		local handlersRan = Dispatchers[select('#', ...) + 1](handlers, eventname, ...)

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for self,func in pairs(callbacks) do
					events[eventname][self] = func
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
						first = nil
					end
				end
			end
			registry.insertQueue = nil
		end
		
		-- Return number of successful handlers.
		return handlersRan
	end

	-- Registration of a callback, handles:
	--   self["method"], leads to self["method"](self, ...)
	--   self with function ref, leads to functionref(...)
	--   "addonId" (instead of self) with function ref, leads to functionref(...)
	-- all with an optional arg, which, if present, gets passed as first argument (after self if present)
	target[RegisterName] = function(self, eventname, method, ... --[[actually just a single arg]])
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - string or function expected.", 2)
		end

		local regfunc

		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): self was not a table?", 2)
			elseif self==target then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): do not use Library:"..RegisterName.."(), use your own 'self'", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - method '"..tostring(method).."' not found on self.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg=select(1,...)
				regfunc = function(...) self[method](self,arg,...) end
			else
				regfunc = function(...) self[method](self,...) end
			end
		else
			-- function ref with self=object or self="addonId" or self=thread
			if type(self)~="table" and type(self)~="string" and type(self)~="thread" then
				error("Usage: "..RegisterName.."(self or \"addonId\", eventname, method): 'self or addonId': table or string or thread expected.", 2)
			end

			if select("#",...)>=1 then	-- this is not the same as testing for arg==nil!
				local arg=select(1,...)
				regfunc = function(...) method(arg,...) end
			else
				regfunc = method
			end
		end


		if events[eventname][self] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			events[eventname][self] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable({}, AutoInnerTablesMeta)
			registry.insertQueue[eventname][self] = regfunc
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or self==target then
			error("Usage: "..UnregisterName.."(eventname): bad 'self'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(events, eventname) and events[eventname][self] then
			events[eventname][self] = nil
			-- Fire OnUnused callback?
			if registry.OnUnused and not next(events[eventname]) then
				registry.OnUnused(registry, target, eventname)
			end
		end
		if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
			registry.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(...)
			if select("#",...)<1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or \"addonId\" to unregister events for.", 2)
			end
			if select("#",...)==1 and ...==target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or \"addonId\"", 2)
			end


			for i=1,select("#",...) do
				local self = select(i,...)
				if registry.insertQueue then
					for eventname, callbacks in pairs(registry.insertQueue) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
				end
				for eventname, callbacks in pairs(events) do
					if callbacks[self] then
						callbacks[self] = nil
						-- Fire OnUnused callback?
						if registry.OnUnused and not next(callbacks) then
							registry.OnUnused(registry, target, eventname)
						end
					end
				end
			end
		end
	end

	return registry
end


-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.

