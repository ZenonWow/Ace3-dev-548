--- AceEvent-3.0 provides event registration and secure dispatching.
-- All dispatching is done using **CallbackHandler-1.0**. AceEvent is a simple wrapper around
-- CallbackHandler, and dispatches all game events or addon message to the registrees.
--
-- **AceEvent-3.0** can be embedded into your addon, either explicitly by calling AceEvent:Embed(MyAddon) or by 
-- specifying it as an embedded library in your AceAddon. All functions will be available on your addon object
-- and can be accessed directly, without having to explicitly call AceEvent itself.\\
-- It is recommended to embed AceEvent, otherwise you'll have to specify a custom `self` on all calls you
-- make into AceEvent.
-- @class file
-- @name AceEvent-3.0
-- @release $Id: AceEvent-3.0.lua 1161 2017-08-12 14:30:16Z funkydude $
-- @patch $Id: AceEvent-3.0.lua 1161.1 2019-01 Mongusius, MINOR: 4 -> 5
-- Revision 5:  added AceEvent:IsEventRegistered(eventName)

local CallbackHandler = LibStub("CallbackHandler-1.0", nil, MAJOR)
-- local CallbackHandler = LibStub:Depend(AceEvent, "CallbackHandler-1.0")
-- local CallbackHandler = AceEvent:Depend("CallbackHandler-1.0")

local MAJOR, MINOR = "AceEvent-3.0", 5
local AceEvent = LibStub:NewLibrary(MAJOR, MINOR)

if not AceEvent then return end


-- Lua APIs
local pairs = pairs

AceEvent.frame  = AceEvent.frame  or CreateFrame("Frame", "AceEvent30Frame") -- our event frame
AceEvent.embeds = AceEvent.embeds or {}  -- Clients of AceEvent embedding the mixin methods.
AceEvent.mixin  = AceEvent.mixin  or {}  -- Methods embedded in clients.



--- Register for a Blizzard Event.
-- The callback will be called with the optional `arg` as the first argument (if supplied), and the event name as the second (or first, if no arg was supplied)
-- Any arguments to the event will be passed on after that.
-- @name AceEvent:RegisterEvent
-- @class function
-- @paramsig event[, callback [, arg]]
-- @param event The event to register for
-- @param callback The callback function to call when the event is triggered (funcref or method, defaults to a method with the event name)
-- @param arg An optional argument to pass to the callback function

--- Unregister an event.
-- @name AceEvent:UnregisterEvent
-- @class function
-- @paramsig event
-- @param event The event to unregister


--- Register for a custom AceEvent-internal message.
-- The callback will be called with the optional `arg` as the first argument (if supplied), and the event name as the second (or first, if no arg was supplied)
-- Any arguments to the event will be passed on after that.
-- @name AceEvent:RegisterMessage
-- @class function
-- @paramsig message[, callback [, arg]]
-- @param message The message to register for
-- @param callback The callback function to call when the message is triggered (funcref or method, defaults to a method with the event name)
-- @param arg An optional argument to pass to the callback function

--- Unregister a message
-- @name AceEvent:UnregisterMessage
-- @class function
-- @paramsig message
-- @param message The message to unregister

--- Send a message over the AceEvent-3.0 internal message system to other addons registered for this message.
-- @name AceEvent:SendMessage
-- @class function
-- @paramsig message, ...
-- @param message The message to send
-- @param ... Any arguments to the message


------------------------------------------
-- APIs and registry for blizzard events, using CallbackHandler lib
------------------------------------------

if not AceEvent.events then
	AceEvent.events = CallbackHandler:New(AceEvent, "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents")
end

function AceEvent.IsEventRegistered(receiver, eventName)
	assert(receiver ~= AceEvent, "Usage: receiver:IsEventRegistered(`eventName`):  do not use AceEvent:IsEventRegistered(), use your own object as self/`receiver`", 2)
	local callbacks = rawget(AceEvent.events.events, eventName)
	return  callbacks  and  callbacks[receiver] ~= nil
end


function AceEvent.events:OnUsed(sender, eventName) 
	AceEvent.frame:RegisterEvent(eventName)
end

function AceEvent.events:OnUnused(sender, eventName) 
	AceEvent.frame:UnregisterEvent(eventName)
end



------------------------------------------
-- APIs and registry for IPC messages, using CallbackHandler lib
------------------------------------------

if not AceEvent.messages then
	AceEvent.messages = CallbackHandler:New(AceEvent, "RegisterMessage", "UnregisterMessage", "UnregisterAllMessages")
	-- AceEvent.SendMessage():  wrap messages:Fire(...) instead of exporting internal api, so :Fire() gets the proper `self`.
	-- Historically :Fire() threw away `self` and used the upvalued `registry`. This meant that every registry had its own Fire() closure.
	AceEvent.SendMessage = function(embedder, ...)  AceEvent.messages:Fire(...)  end
end




-- embedding and embed handling
local mixins = {
	"RegisterEvent",   "UnregisterEvent",   "UnregisterAllEvents",   "IsEventRegistered",
	"RegisterMessage", "UnregisterMessage", "UnregisterAllMessages", "SendMessage",
}
-- CallbackHandler:New mixes methods of 
for i,name in ipairs(mixins) do  AceEvent.mixin[name] = AceEvent[name]  end


-- Embeds AceEvent into the client object making the functions from the mixin object available on client:..
-- @param client client object to embed AceEvent in
function AceEvent:Embed(client)
	self.embeds[client] = true
	for name,method in pairs(self.mixin) do
		client[name] = method
	end
	return client
end

-- AceEvent:OnEmbedDisable( client )
-- client (object) - client object that is being disabled
--
-- Unregister all events messages etc when the client disables.
-- this method should be called by the client manually or by AceAddon or another addon framework
function AceEvent:OnEmbedDisable(client)
	client:UnregisterAllEvents()
	client:UnregisterAllMessages()
end

-- Script to fire blizzard events into the event listeners
local events = AceEvent.events
AceEvent.frame:SetScript("OnEvent", function(frame, eventName, ...)
	events:Fire(eventName, ...)
end)

--- Finally: upgrade our old embeds
for client, v in pairs(AceEvent.embeds) do
	AceEvent:Embed(client)
end


