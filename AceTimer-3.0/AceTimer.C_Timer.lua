if  select(4, G.GetBuildInfo()) >= 60000  then  return  end

local G, LIB_NAME, LIB_REVISION  =  _G, 'AceTimer.C_Timer', 1
assert(LibStub, 'Include "LibStub.lua" before AceTimer.C_Timer.')

local AceTimer = LibStub("AceTimer-3.0")
local C_Timer = LibStub:NewLibrary(LIB_NAME, LIB_REVISION)
if not C_Timer then  return  end



-- Export to _G:  C_Timer, C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker
G.C_Timer = C_Timer
AceTimer:Embed(C_Timer)


--- C_Timer.After(delay, callback)
-- Implemented in C since WoD.
--
function C_Timer.After(delay, callback)
	C_Timer:ScheduleTimer(callback, delay)
end


--- local timer = C_Timer.NewTimer(delay, callback)
-- Implemented in SharedXML/C_TimerAugment.lua.  Bliz can't implement cancellable timers in C.
--
function C_Timer.NewTimer(delay, callback)
	local timer = setmetatable({}, C_Timer.TimerMeta)
	timer.id = C_Timer:ScheduleTimer(callback, delay, timer)
	return timer
end


--- local timer = C_Timer.NewTicker(delay, callback, iterations)
function C_Timer.NewTicker(delay, callback, iterations)
	local timer = setmetatable({ callback = callback, iterations = iterations }, C_Timer.TimerMeta)
	if iterations then  callback = TimerMeta._LimitedCallback  end
	timer.id = C_Timer:ScheduleRepeatingTimer(callback, delay, timer)
	return timer
end


local TimerMeta = C_Timer.TimerMeta or {}
C_Timer.TimerMeta = TimerMeta


--- timer:Cancel()
function TimerMeta:Cancel()
	C_Timer:CancelTimer(self.id)
end


--- timer:IsCancelled()
function TimerMeta:IsCancelled()
	return  not AceTimer.activeTimers[self.id]
end


-- Callback function when iterations is set.
function TimerMeta:_LimitedCallback()
	self:callback()
	if 0 < self.iterations
	then  self.iterations = self.iterations - 1
	else  self:Cancel()
	end
end


