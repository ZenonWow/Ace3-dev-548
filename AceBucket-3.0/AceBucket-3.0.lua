
--- A bucket to catch events in. **AceBucket-3.0** provides throttling of events that fire in bursts and
-- your addon only needs to know about the full burst.
-- 
-- This Bucket implementation works as follows:\\
--   Initially, no schedule is running, and its waiting for the first event to happen.\\
--   The first event will start the bucket, and get the scheduler running, which will collect all
--   events in the given interval. When that interval is reached, the bucket is pushed to the 
--   callback and a new schedule is started. When a bucket is empty after its interval, the scheduler is 
--   stopped, and the bucket is only listening for the next event to happen, basically back in its initial state.
-- 
-- In addition, the buckets collect information about the "arg1" argument of the events that fire, and pass those as a 
-- table to your callback. This functionality was mostly designed for the UNIT_* events.\\
-- The table will have the different values of "arg1" as keys, and the number of occurances as their value, e.g.\\
--   { ["player"] = 2, ["target"] = 1, ["party1"] = 1 }
--
-- **AceBucket-3.0** can be embedded into your addon, either explicitly by calling AceBucket:Embed(MyAddon) or by 
-- specifying it as an embedded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceBucket itself.\\
-- It is recommended to embed AceBucket, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceBucket.
-- @usage
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("BucketExample", "AceBucket-3.0")
-- 
-- function MyAddon:OnEnable()
--   -- Register a bucket that listens to all the HP related events, 
--   -- and fires once per second
--   self:RegisterBucketEvent({"UNIT_HEALTH", "UNIT_MAXHEALTH"}, 1, "UpdateHealth")
-- end
--
-- function MyAddon:UpdateHealth(units)
--   if units.player then
--     print("Your HP changed!")
--   end
-- end
-- @class file
-- @name AceBucket-3.0.lua
-- @release $Id: AceBucket-3.0.lua 895 2009-12-06 16:28:55Z nevcairiel $
-- @patch $Id: AceBucket-3.0.lua 895.1 2019-01 Mongusius, MINOR: 3 -> 3.1
-- 3.1 added  firstInterval  parameter to RegisterBucketEvent and RegisterBucketMessage. Defaults to interval.
-- The first batch of events is sent after firstInterval (in the next frame if zero, collecting events sent at the same time).
-- 3.1 replaced safecall implementation with xpcall(bucket.xpcallClosure, errorhandler).

local MAJOR, MINOR = "AceBucket-3.0", 3.1
local _G, AceBucket, oldminor = _G, LibStub:NewLibrary(MAJOR, MINOR)

if not AceBucket then return end -- No Upgrade needed


-- Export to LibCommon:  errorhandler
-- Import from LibCommon:
local LibCommon = _G.LibCommon
assert(LibCommon and LibCommon.isanytype and LibCommon.istype, "AceBucket-3.0 requires LibCommon.isanytype, LibCommon.istype")
local isanytype, isstring, isfunc, istable = LibCommon.isanytype, LibCommon.isstring, LibCommon.isfunc, LibCommon.istable


-- Allow hooking _G.geterrorhandler(): don't cache/upvalue it or the errorhandler returned.
-- Avoiding tailcall: errorhandler() function would show up as "?" in stacktrace, making it harder to understand.
LibCommon.errorhandler = LibCommon.errorhandler or  function(errorMessage)  return true and _G.geterrorhandler()(errorMessage)  end
local errorhandler = LibCommon.errorhandler
	

-- the libraries will be lazyly bound later, to avoid errors due to loading order issues
local AceEvent, AceTimer
-- Or get a stub if LibStub.GetDependencies is present.
if LibStub.GetDependencies then  AceEvent, AceTimer = LibStub:GetDependencies(AceBucket, 'AceEvent', 'AceTimer')  end

-- Lua APIs
local tconcat = table.concat
local type, next, pairs, select = type, next, pairs, select
local tonumber, tostring, rawset = tonumber, tostring, rawset
local assert, loadstring = assert, loadstring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: LibStub, geterrorhandler


AceBucket.buckets = AceBucket.buckets or {}
AceBucket.embeds  = AceBucket.embeds or {}
AceBucket.mixins  = AceBucket.mixins or {}   -- Methods embedded in clients.
local mixins = AceBucket.mixins



-- FireBucket ( bucket )
--
-- send the bucket to the callback function and schedule the next FireBucket in interval seconds
-- local 
local function FireBucket(bucket)
	-- bucket.timer = nil
	local received = bucket.received
	
	-- we dont want to fire empty buckets
	if next(received) then
		--[[
		local callback = bucket.callback
		if type(callback) == 'function'
		then  safecall(callback, received)
		else  safecall(bucket.object[callback], bucket.object, received)
		end
		--]]

		-- Pass a delegating errorhandler to avoid _G.geterrorhandler() function call before any error actually happens.
		xpcall(bucket.xpcallClosure, errorhandler)
		-- Or pass the registered errorhandler directly to avoid inserting an extra callstack frame.
		-- The errorhandler is expected to be the same at both times: callbacks usually don't change it.
		--xpcall(bucket.xpcallClosure, _G.geterrorhandler())

		wipe(received)

		-- if the bucket was not empty, schedule repeating FireBucket after interval seconds
		-- the bucket won't be fired until this timer finishes
		if  not AceTimer.activeTimers[bucket.timer]  then
			bucket.timer = AceTimer.ScheduleRepeatingTimer(bucket, FireBucket, bucket.interval, bucket)
		end

	else
		-- if it was empty, clear the timer and wait for the next event
		AceTimer.CancelTimer(bucket, bucket.timer)
		bucket.timer = nil
	end
end

-- BucketHandler ( event, arg1 )
-- 
-- callback function for AceEvent
-- stores first event argument `arg1` in the received table, and schedules the bucket if necessary
-- local 
local function BucketHandler(bucket, event, arg1)
	if arg1 == nil then
		arg1 = "nil"
	end
	
	bucket.received[arg1] = (bucket.received[arg1] or 0) + 1
	
	if  not bucket.timer  then
		-- No timer -> last callback() was more than interval ago. Send events in next framedraw -> interval = 0 -> 0.01
		bucket.timer = AceTimer.ScheduleTimer(bucket, FireBucket, bucket.firstInterval or bucket.interval, bucket)
	end
end



-- Alternative timer management:
if  not FireBucket  then

	-- FireBucket ( bucket )
	--
	-- send the bucket to the callback function and schedule the next FireBucket in interval seconds
	-- local 
	function FireBucket(bucket)
		bucket.timer = nil
		local received = bucket.received
		
		-- we dont want to fire empty buckets
		if next(received) then
			bucket.lastTime = GetTime()
			xpcall(bucket.xpcallClosure, errorhandler)
			-- xpcall(bucket.xpcallClosure, _G.geterrorhandler())
			wipe(received)
		end
	end

	-- BucketHandler ( event, arg1 )
	-- 
	-- callback function for AceEvent
	-- stores arg1 in the received table, and schedules the bucket if necessary
	-- local
	function BucketHandler(bucket, event, arg1)
		if arg1 == nil then  arg1 = "nil"  end
		
		bucket.received[arg1] = (bucket.received[arg1] or 0) + 1
		
		if  not bucket.timer  then
			local interval = (bucket.lastTime or 0) + bucket.interval - GetTime()
			if  interval <= 0  then  interval = bucket.firstInterval or bucket.interval  end
			bucket.timer = AceTimer.ScheduleTimer(bucket, FireBucket, interval, bucket)
		end
	end

end  -- if  not FireBucket




local bucketCache = setmetatable({}, {__mode='k'})

-- RegisterBucket( event, interval, callback, isMessage )
--
-- event(string or table) - the event, or a table with the events, that this bucket listens to
-- interval(int) - time between bucket fireings
-- callback(function or string) - function pointer, or method name of the object, that gets called when the bucket is cleared
-- isMessage(boolean) - register AceEvent Messages instead of game events
local function RegisterBucket(owner, event, interval, callback, isMessage, firstInterval)
	-- try to fetch the librarys
	if not AceEvent then
		AceEvent = LibStub("AceEvent-3.0", true)
		AceTimer = LibStub("AceTimer-3.0", true)
	end
	local error = error
	if  not AceEvent  or  not AceTimer  or  AceEvent.IsNotLoaded  or  AceTimer.IsNotLoaded  then
		error( MAJOR..' requires "AceEvent-3.0" and "AceTimer-3.0" loaded before.', 3 )
	end
	
	if not isanytype(event, 'string', 'table') then error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): `event` - string or table expected, got "..type(event), 3) end
	if not callback and isstring(event) then
		callback = event
	elseif not callback then
			error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): cannot omit callback when event is not a string.", 3)
	end
	if not tonumber(interval) then  error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): `interval` - number expected, got '"..tostring(interval).."'.", 3)  end
	if firstInterval and not tonumber(firstInterval) then  error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): `firstInterval` - number expected, got '"..tostring(firstInterval).."'.", 3)  end
	if not isanytype(callback, 'string', 'function') then  error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): `callback` - string or function or nil expected, got "..type(callback), 3)  end
	if not isfunc(callback) and not isfunc(owner[callback]) then  error("Usage: MyAddon:RegisterBucketEvent(event, interval, callback[, firstInterval]): `callback` - method not found on target object: '"..tostring(callback).."'.", 3)  end
	
	-- local bucket = next(bucketCache)
	local bucket = next(bucketCache)
	if bucket then
		bucketCache[bucket] = nil
	else
		-- bucket = { handler = BucketHandler, received = {} }
		bucket = { received = {} }
	end

	-- bucket.callback = callback
	bucket.object = owner
	bucket.interval, bucket.firstInterval = tonumber(interval), tonumber(firstInterval)
	bucket.handler = BucketHandler
	-- bucket.xpcallClosure() is the ready-to-go function passed to xpcall. It upvalues owner,callback,received for fast access; none of those will change.
	local received = bucket.received
	if isfunc(callback) then
		function bucket.xpcallClosure()  return callback(received) end
	else
		function bucket.xpcallClosure()  return owner[callback](owner, received) end
	end
	
	local RegisterCallback = isMessage and AceEvent.RegisterMessage or AceEvent.RegisterEvent
	for _,e in ipairsOrOne(event) do
		RegisterCallback(bucket, e, 'handler')
	end
	
	local handle = tostring(bucket)
	AceBucket.buckets[handle] = bucket
	
	return handle
end




--- Register a Bucket for an event (or a set of events)
-- @param event The event to listen for, or a table of events.
-- @param interval The Bucket interval (burst interval)
-- @param callback The callback function, either as a function reference, or a string pointing to a method of the addon object.
-- @param firstInterval 0 to send the first batch without delay on the next OnUpdate, and throttle the oncoming events, emptying the bucket every interval.
-- @return The handle of the bucket (for unregistering)
-- @usage
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceBucket-3.0")
-- MyAddon:RegisterBucketEvent("BAG_UPDATE", 0.2, "UpdateBags")
-- 
-- function MyAddon:UpdateBags()
--   -- do stuff
-- end
function mixins:RegisterBucketEvent(event, interval, callback, firstInterval)
	return RegisterBucket(self, event, interval, callback, false, firstInterval)
end

--- Register a Bucket for an AceEvent-3.0 addon message (or a set of messages)
-- @param message The message to listen for, or a table of messages.
-- @param interval The Bucket interval (burst interval)
-- @param callback The callback function, either as a function reference, or a string pointing to a method of the addon object.
-- @return The handle of the bucket (for unregistering)
-- @usage
-- MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceBucket-3.0")
-- MyAddon:RegisterBucketMessage("SomeAddon_InformationMessage", 0.2, "ProcessData")
-- 
-- function MyAddon:ProcessData()
--   -- do stuff
-- end
function mixins:RegisterBucketMessage(message, interval, callback, firstInterval)
	return RegisterBucket(self, message, interval, callback, true, firstInterval)
end

--- Unregister any events and messages from the bucket and clear any remaining data.
-- @param handle The handle of the bucket as returned by RegisterBucket*
function mixins:UnregisterBucket(handle)
	local bucket = AceBucket.buckets[handle]
	if bucket then
		AceEvent.UnregisterAllEvents(bucket)
		AceEvent.UnregisterAllMessages(bucket)
		
		-- clear any remaining data in the bucket
		AceTimer.CancelTimer(bucket, bucket.timer)
		local received = bucket.received
		wipe(received)
		wipe(bucket)
		bucket.received = received
		
		AceBucket.buckets[handle] = nil
		-- store our bucket in the cache
		bucketCache[bucket] = true
	end
end

--- Unregister all buckets of the current addon object (or custom "self").
function mixins:UnregisterAllBuckets()
	-- hmm can we do this more efficient? (it is not done often so shouldn't matter much)
	for handle, bucket in pairs(AceBucket.buckets) do
		if bucket.object == self then
			AceBucket.UnregisterBucket(self, handle)
		end
	end
end




--[[
Whenever a newer version of the library upgrades an older version, the existing buckets are not upgraded.
They retain reference to the old  bucket.handler = BucketHandler  and through that to FireBucket(),
and keep using  bucket.callback()  instead of  bucket.xpcallClosure()  which isn't created either.
Unless this method is called.
--]]
function AceBucket:UpgradeBuckets()
	for handle, bucket in pairs(self.buckets) do
		-- Timer started by the old BucketHandler() can be active, calling the old FireBucket() at some later time, in turn calling bucket.object:<bucket.callback>(bucket.received)
		if bucket.timer then
		bucket.handler = BucketHandler
		local owner,callback,received = bucket.object, bucket.callback, bucket.received
		if isfunc(callback) then
			function bucket.xpcallClosure()  return callback(received) end
		else
			function bucket.xpcallClosure()  return owner[callback](owner, received) end
		end
	end
	
	AceBucket.UpgradeBuckets = nil
end




--[[
-- embedding and embed handling
local mixins = {
	"RegisterBucketEvent",
	"RegisterBucketMessage", 
	"UnregisterBucket",
	"UnregisterAllBuckets",
}--]]

-- Embeds AceBucket into the target object making the functions from the mixins list available on target:..
-- @param target target object to embed AceBucket in
function AceBucket:Embed( target )
	self.embeds[target] = true
	for name,method in pairs(self.mixins) do
		target[name] = method
	end
	return target
end


function AceBucket:OnEmbedDisable( target )
	target:UnregisterAllBuckets()
end




-- Upgrade to new FireBucket and BucketHandler, or leave as it is.
-- AceBucket:UpgradeBuckets()

-- Mix in itself for backwards compatibility.
AceBucket.embeds[AceBucket] = true

-- Upgrade our embedded mixins from previous revision.
for addon in pairs(AceBucket.embeds) do
	AceBucket:Embed(addon)
end


