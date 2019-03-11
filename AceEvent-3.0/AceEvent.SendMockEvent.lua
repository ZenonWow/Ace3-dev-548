local G, LIB_NAME, LIB_REVISION  =  _G, "AceEvent-3.0", 3.1
assert(LibStub and LibStub.NewLibraryPart, 'Include "LibStub.NewLibraryPart.lua" before AceEvent.SendMockEvent.')
local AceEvent = LibStub:NewLibraryPart(LIB_NAME, LIB_REVISION, 'SendMockEvent')
if not AceEvent then return end



function AceEvent:SendMockEvent(eventName, ...)
	local frames = { G.GetFramesRegisteredForEvent(eventName) }
	if  not next(frames)  then  return 0  end

	local LibDispatch = G.LibStub('LibDispatch')
	local wrapper = LibDispatch.CallWrapper(eventName, ...)
	local callbacksRan = 0
	local errorhandler = G.LibShared.errorhandler
	-- local errorhandler = G.geterrorhandler()

	for i,frame in  ipairs(frames)  do
		local callback = frame:GetScript('OnEvent')
		if callback then
			local closure = wrapper(callback, frame)
			local ok = xpcall(closure, errorhandler)
			if ok then  callbacksRan = callbacksRan + 1  end
		end
	end
	return  callbacksRan
end



--[[
function AceEvent:SendMockEvent(eventName, ...)
	-- Yet another DispatchDynamic(), now with frames and OnEvent script.
	-- Differences:  source of receiver list,  source of receiver -> function mapping

	local frames = { G.GetFramesRegisteredForEvent(eventName) }
	if  not next(frames)  then  return 0  end

	local argNum = select('#',...)
	local methodClosure, selfArg, callback
	if  0 == argNum  then
		-- There is no `return`:  events ignore return values.
		methodClosure = function()  callback( selfArg, eventName )  end
	elseif  1 == argNum  then
		local arg = ...
		methodClosure = function()  callback( selfArg, eventName, arg )  end
	else
		-- Pack the parameters in a closure to pass to the actual function.
		local args = { eventName, ... }
		-- Unpack the parameters in the closure.
		-- xpcallClosure = function()  callback( unpack(args,1,argNum) )  end
		methodClosure = function()  callback( selfArg, unpack(args,1,argNum) )  end
	end

	local callbacksRan = 0
	local errorhandler = LibShared.errorhandler
	-- local errorhandler = G.geterrorhandler()
	for i,frame in ipairs(frames) do
		selfArg = frame
		callback = frame:GetScript('OnEvent')
		local ok = callback and xpcall(methodClosure, errorhandler)
		if ok then  callbacksRan = callbacksRan + 1  end
	end
	return  callbacksRan
end
--]]


--[[
/dump  (function()  local l={GetFramesRegisteredForEvent( 'ADDON_LOADED' )} ; for i,f in ipairs(l) do  l[i] = f:GetName()  end ; return l end)()
/dump  (function()  local l={GetFramesRegisteredForEvent( 'PLAYER_LOGOUT' )} ; for i,f in ipairs(l) do  l[i] = f:GetName()  end ; return l end)()
/run  AceEvent30Frame:RegisterEvent('MadeUpEvent')
/dump  (function()  local evt= 'MadeUpEvent'  ;  AceEvent30Frame:RegisterEvent(evt)  ;  local l={GetFramesRegisteredForEvent(evt)} ; for i,f in ipairs(l) do  l[i] = f:GetName()  end ; return l end)()
/dump  (function()  local evt= 'PLAYER_LOGOUT'  ;  local l={GetFramesRegisteredForEvent(evt)} ; for i,f in ipairs(l) do  l[i] = f:GetName()  end ; l[#l+1]="no?" ; return l end)()
--]]

