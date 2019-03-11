local G, LIB_NAME, LIB_REVISION  =  _G, "CallbackHandler-1.0", 7.1
assert(LibStub and LibStub.NewLibraryPart, 'Include "LibStub.NewLibraryPart.lua" before CallbackHandler.DispatchDynamic.')
local CallbackHandler = LibStub:NewLibraryPart(LIB_NAME, LIB_REVISION, 'DispatchDynamic')


if CallbackHandler then

	local next,type,select,unpack,xpcall = next,type,select,unpack,xpcall

	------------------------------
	-- CallbackHandler. DispatchDynamic(callbacks, ...)
	--
	-- This is a version of LibDispatch.CallWrapperDynamic(), with iteration of callbacks and xpcall() added.
	--
	function CallbackHandler.DispatchDynamic(callbacks, ...)
		if  not next(callbacks)  then  return 0  end

		local callback, selfArg
		local functionClosure, methodClosure
		local argNum = select('#',...)

		if  0 == argNum  then
			methodClosure   = function()  callback(selfArg)  end
		elseif  1 == argNum  then
			local arg1 = ...
			functionClosure = function()  callback(arg1)  end
			methodClosure   = function()  callback(selfArg, arg1)  end
		else
			-- Pack the parameters into an array.
			local args = {...}
			-- Unpack the parameters in the closure.
			functionClosure = function()  callback( unpack(args,1,argNum) )  end
			methodClosure   = function()  callback( selfArg, unpack(args,1,argNum) )  end
		end

		local callbacksRan,closure = 0
		-- local errorhandler = _G.geterrorhandler()
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

end -- CallbackHandler.DispatchDynamic


