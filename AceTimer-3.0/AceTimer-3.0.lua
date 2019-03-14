--- **AceTimer-3.0** provides a central facility for registering timers.
-- AceTimer supports one-shot timers and repeating timers. All timers are stored in an efficient
-- data structure that allows easy dispatching and fast rescheduling. Timers can be registered
-- or canceled at any time, even from within a running timer, without conflict or large overhead.\\
-- AceTimer is currently limited to firing timers at a frequency of 0.01s. This constant may change
-- in the future, but for now it's required as animations with lower frequencies are buggy.
--
-- All `:Schedule` functions will return a handle to the current timer, which you will need to store if you
-- need to cancel the timer you just registered.
--
-- **AceTimer-3.0** can be embedded into your addon, either explicitly by calling AceTimer:Embed(MyAddon) or by
-- specifying it as an embedded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceTimer itself.\\
-- It is recommended to embed AceTimer, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceTimer.
-- @class file
-- @name AceTimer-3.0
-- @release $Id: AceTimer-3.0.lua 1079 2013-02-17 19:56:06Z funkydude $
-- @patch $Id: AceBucket-3.0.lua 895.1 2019-01 Mongusius, MINOR: 16 -> 16.1
-- 16.1 added AceTimer:IsActive(id) and usage doc at top
--
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
-- or:
-- LibStub("AceTimer-3.0"):Embed(MyAddOn)
-- MyAddOn:ScheduleTimer("TimerFeedback", 5)
-- function MyAddOn:TimerFeedback()  print("5 seconds passed")  end
-- or:
-- local AceTimer = LibStub("AceTimer-3.0")
-- local function scheduledFunc()  print("5 seconds passed")  end
-- local timerId = AceTimer.ScheduleTimer(anything, scheduledFunc, delay)
--

local G, MAJOR, MINOR = _G, "AceTimer-3.0", 16.1 -- Bump minor on changes
local AceTimer, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceTimer then return end -- No upgrade needed

AceTimer.frame = AceTimer.frame or CreateFrame("Frame", "AceTimer30Frame") -- Animation parent
-- AceTimer.inactiveTimers = AceTimer.inactiveTimers or {}                 -- Timer recycling storage until MINOR = 16
AceTimer.inactiveTimerList = AceTimer.inactiveTimerList or {}              -- Timer recycling list MINOR > 16
AceTimer.activeTimers      = AceTimer.activeTimers or {}                   -- Active id->timer map
AceTimer.embeds            = AceTimer.embeds or {}                         -- Clients embedding the mixin methods.
AceTimer.mixin             = AceTimer.mixin or {}                          -- Methods embedded in clients.
local mixin = AceTimer.mixin


-- Lua APIs
local type, unpack, next, error, pairs, ipairs, tostring, select = type, unpack, next, error, pairs, ipairs, tostring, select

-- Upvalue our private data
local activeTimers, inactiveTimerList = AceTimer.activeTimers, AceTimer.inactiveTimerList


local function OnFinished(timer)
	local id,args = timer.id, timer.args
	if not timer.looping then
		activeTimers[id] = nil
		inactiveTimerList[#inactiveTimerList+1] = timer
		timer.args = nil
		timer.argsCount = nil
	end

	local callback =  timer.methodName and timer.object[timer.methodName]  or  timer.func
	-- We manually set the unpack count to prevent issues with an arg set that contains nil and ends with nil
	-- e.g. local t = {1, 2, nil, 3, nil} print(#t) will result in 2, instead of 5. This fixes said issue.
	callback(unpack(args, 1, timer.argsCount))

	-- If the id is different it means that the timer was reused to create a new timer during the OnFinished callback.
	-- AceBucket does that.
	if  not timer.looping  and  id == timer.id  then
		-- timer.args = nil
		-- timer.argsCount = nil
		-- .func and .object are static, not candidates for garbage collection in most if not all use-cases.
		-- timer.func = nil
		-- timer.object = nil
	end
end


local function new(client, looping, callback, delay, ...)
	local timer = inactiveTimerList[#inactiveTimerList]
	local anim
	if timer then
		inactiveTimerList[#inactiveTimerList] = nil
		anim = timer:GetParent()
	else
		anim = AceTimer.frame:CreateAnimationGroup()
		timer = anim:CreateAnimation()
		timer:SetScript("OnFinished", OnFinished)
	end

	-- Very low delays cause the animations to fail randomly.
	-- A limited resolution of 0.01 seems reasonable.
	if delay < 0.01 then  delay = 0.01  end

	if type(callback)=="string" then
		timer.methodName = callback
		timer.func = client[callback]
		timer.args = { client, ... }
		timer.argsCount = 1 + select("#",...)
	else
		timer.methodName = nil -- Reset if timer is reused.
		timer.func = callback
		timer.args = {...}
		timer.argsCount = select("#",...)
	end

	timer.object = client
	timer.looping = looping
	timer:SetDuration(delay)
	anim:SetLooping(looping and 'REPEAT' or 'NONE')

	local id = tostring(timer.args)
	timer.id = id
	activeTimers[id] = timer

	anim:Play()
	return id
end



--- Schedule a new one-shot timer.
-- The timer will fire once in `delay` seconds, unless canceled before.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self:ScheduleTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   print("5 seconds passed")
-- end
--
function mixin:ScheduleTimer(callback, delay, ...)
	if not callback or not delay then
		error(MAJOR..": ScheduleTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(callback) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[callback] then
			error(MAJOR..": ScheduleTimer(callback, delay, args...): Tried to register '"..callback.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, nil, callback, delay, ...)
end


--- Schedule a repeating timer.
-- The timer will fire every `delay` seconds, until canceled.
-- @param callback Callback function for the timer pulse (funcref or method name).
-- @param delay Delay for the timer, in seconds.
-- @param ... An optional, unlimited amount of arguments to pass to the callback function.
-- @usage
-- MyAddOn = LibStub("AceAddon-3.0"):NewAddon("MyAddOn", "AceTimer-3.0")
--
-- function MyAddOn:OnEnable()
--   self.timerCount = 0
--   self.testTimer = self:ScheduleRepeatingTimer("TimerFeedback", 5)
-- end
--
-- function MyAddOn:TimerFeedback()
--   self.timerCount = self.timerCount + 1
--   print(("%d seconds passed"):format(5 * self.timerCount))
--   -- run 30 seconds in total
--   if self.timerCount == 6 then
--     self:CancelTimer(self.testTimer)
--   end
-- end
--
function mixin:ScheduleRepeatingTimer(callback, delay, ...)
	if not callback or not delay then
		error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'callback' and 'delay' must have set values.", 2)
	end
	if type(callback) == "string" then
		if type(self) ~= "table" then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): 'self' - must be a table.", 2)
		elseif not self[callback] then
			error(MAJOR..": ScheduleRepeatingTimer(callback, delay, args...): Tried to register '"..callback.."' as the callback, but it doesn't exist in the module.", 2)
		end
	end
	return new(self, true, callback, delay, ...)
end


--- Cancels a timer with the given id, registered by the same addon object as used for `:ScheduleTimer`
-- Both one-shot and repeating timers can be canceled with this function, as long as the `id` is valid
-- and the timer has not fired yet or was canceled before.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
function mixin:CancelTimer(id)
	local timer = activeTimers[id]
	if not timer then return false end

	local anim = timer:GetParent()
	anim:Stop()

	activeTimers[id] = nil
	timer.args = nil
	timer.argsCount = nil
	inactiveTimerList[#inactiveTimerList+1] = timer
	return true
end

--- Cancels all timers registered to the current addon object ('self')
function mixin:CancelAllTimers()
	for k,v in pairs(activeTimers) do
		if v.object == self then
			AceTimer.CancelTimer(self, k)
		end
	end
end

--- Checks if the timer with the given id, registered by the current addon object ('self') is still active.
-- This function will return nil when the id is invalid.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
-- @return true if it's still ticking, otherwise nil.
function mixin:IsActive(id)
	return activeTimers[id] and true
end

--- Returns the time left for a timer with the given id, registered by the current addon object ('self').
-- This function will return 0 when the id is invalid.
-- @param id The id of the timer, as returned by `:ScheduleTimer` or `:ScheduleRepeatingTimer`
-- @return The time left on the timer.
function mixin:TimeLeft(id)
	local timer = activeTimers[id]
	if not timer then return 0 end
	return timer:GetDuration() - timer:GetElapsed()
end



-- ---------------------------------------------------------------------
-- Upgrading

-- Upgrade from old hash-bucket based timers to animation timers
if oldminor and oldminor < 10 then
	-- disable old timer logic
	AceTimer.frame:SetScript("OnUpdate", nil)
	AceTimer.frame:SetScript("OnEvent", nil)
	AceTimer.frame:UnregisterAllEvents()
	-- convert timers
	for object,timers in pairs(AceTimer.selfs) do
		for handle,timer in pairs(timers) do
			if type(timer) == "table" and timer.callback then
				local id
				if timer.delay then
					id = AceTimer.ScheduleRepeatingTimer(timer.object, timer.callback, timer.delay, timer.arg)
				else
					id = AceTimer.ScheduleTimer(timer.object, timer.callback, timer.when - GetTime(), timer.arg)
				end
				-- change id to the old handle
				local t = activeTimers[id]
				activeTimers[id] = nil
				activeTimers[handle] = t
				t.id = handle
			end
		end
	end
	AceTimer.selfs = nil
	AceTimer.hash = nil
	AceTimer.debug = nil
elseif oldminor and oldminor < 13 then
	for handle, id in pairs(AceTimer.hashCompatTable) do
		local t = activeTimers[id]
		if t then
			activeTimers[id] = nil
			activeTimers[handle] = t
			t.id = handle
		end
	end
	AceTimer.hashCompatTable = nil
end

-- Migrate inactiveTimers (timer->true) to inactiveTimerList (index->timer).
if AceTimer.inactiveTimers then
	for timer in pairs(AceTimer.inactiveTimers) do
		inactiveTimerList[#inactiveTimerList+1] = timer
	end
	wipe(AceTimer.inactiveTimers)
	AceTimer.inactiveTimers = nil
end

-- Upgrade existing timers to the latest OnFinished.
for i,timer in ipairs(inactiveTimerList) do
	timer:SetScript("OnFinished", OnFinished)
end

for _,timer in pairs(activeTimers) do
	timer:SetScript("OnFinished", OnFinished)

	-- Upgrade method calls.
	if type(timer.func)=='string' then
		-- Store methodName in its own field.
		timer.methodName = timer.func
		-- Retreive the method from `self` (object). As it might change, every OnFinished() retreives it anyway.
		timer.func = timer.object[timer.methodName]
		-- Store callback's `self` (object) as first parameter.
		table.insert(timer.args, 1, timer.object)
		timer.argsCount = 1 + timer.argsCount
	end
end



-- ---------------------------------------------------------------------
-- Embed handling


local LibShared = G.LibShared or {}  ;  G.LibShared = LibShared
--- LibShared.softerror(message):  Report error, then continue execution, *unlike* error().
LibShared.softerror = LibShared.softerror or G.geterrorhandler()


-- Embeds AceTimer into the target object making the functions from the mixin table available on target:..
-- @param target target object to embed AceTimer in
function AceTimer:Embed(target)
	-- TODO: Remove if no such anomaly found.
	if self ~= AceTimer then  LibShared.softerror("AceTimer:Embed("..tostring(target).."): self= "..tostring(self).." ~= AceTimer" )  end
	self = AceTimer

	self.embeds[target] = true
	for name,method in pairs(self.mixin) do
		target[name] = method
	end
	return target
end

-- AceTimer:OnEmbedDisable(target)
-- target (object) - target object that AceTimer is embedded in.
--
-- cancel all timers registered for the object
function AceTimer:OnEmbedDisable(target)
	target:CancelAllTimers()
end



-- Some addons use mixin methods in the form AceTimer.ScheduleTimer(clientObject, callback, delay, ...)
AceTimer:Embed(AceTimer)


for addon in pairs(AceTimer.embeds) do
	AceTimer:Embed(addon)
end


