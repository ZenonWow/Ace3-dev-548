
--[[
function  AceEvent.Once.AddonLoaded[...] = Object  -- Calls Object[addonName](Object, addonName)  or  Object:AddonLoaded(addonName)  or  Object:AddonLoaded(eventName, addonName)
function  AceEvent.Once.PlayerLogin() = Object     -- Calls Object:PlayerLogin(eventName)
AceEvent.Once.AddonLoaded[Object] = nil            -- Unregister all AddonLoaded.
AceEvent.Once.AddonLoaded[...][Object] = nil       -- Unregister this addon's AddonLoaded.
AceEvent.Once.PlayerLogin[Object] = nil            -- Unregister.
AceEvent.Once.PlayerLogin.Unregister(Object)       -- Unregister.
AceEvent.Unregister.Once.PlayerLogin(Object)       -- Unregister.

function  AceEvent.Once.AddonLoaded[...](eventName, addonName) .. end
function  AceEvent.Once.CvarsLoaded(eventName) .. end
function  AceEvent.Once.SpellsLoaded(eventName) .. end
function  AceEvent.Once.PlayerLogin(eventName) .. end
function  AceEvent.Once.PlayerEnteringWorld(eventName) .. end


function  AceEvent.OnEvent[Object].ADDON_LOADED(Object, eventName, addonName) .. end
function  AceEvent.OnEvent[Object].PLAYER_SPECIALIZATION_CHANGED(Object, eventName, unit) .. end
function  AceEvent.OnEvent[Object].PLAYER_SPECIALIZATION_CHANGED.player(Object, eventName, unit) .. end

function  Object.OnEvent.ADDON_LOADED(Object, eventName, addonName) .. end
function  Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED(Object, eventName, unit) .. end
function  Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED.player(Object, eventName, unit) .. end

Object:RegisterEvent('ADDON_LOADED')
Object.OnEvent.ADDON_LOADED = true  -- Calls Object.ADDON_LOADED(Object, eventName, addonName) .. end
Object:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED = true  -- Calls Object.PLAYER_SPECIALIZATION_CHANGED(Object, eventName, unit) .. end
Object:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED.player = true  -- Calls Object.PLAYER_SPECIALIZATION_CHANGED(Object, eventName, unit) .. end  -- not Object.player(Object, eventName, unit)

Object.OnEvent.ADDON_LOADED = 'OnAddonLoaded'  -- Calls Object.OnAddonLoaded(Object, eventName, addonName) .. end
Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED = 'OnSpecChange'  -- Calls Object.OnSpecChange(Object, eventName, unit) .. end
Object.OnEvent.PLAYER_SPECIALIZATION_CHANGED.player = 'OnSpecChange'  -- Calls Object.OnSpecChange(Object, eventName, unit) .. end  -- not Object.player(Object, eventName, unit)




AceEvent.OnEvent.ADDON_LOADED = OnAddonLoaded            -- Calls OnAddonLoaded(eventName, addonName, ...)
AceEvent.OnEvent.ADDON_LOADED[OnAddonLoaded] = true      -- Expanded. Same as previous.
AceEvent.OnEvent.ADDON_LOADED[OnAddonLoaded] = nil       -- Unregister any of the above.
AceEvent.OnEvent.ADDON_LOADED = function(eventName, addonName, ...)  end    -- Without a reference to the function this cannot be unregistered. Not suggested.

Object.OnEvent.ADDON_LOADED = true                              -- Calls Object.ADDON_LOADED(Object, addonName, ...)
Object.OnEvent.ADDON_LOADED = 'OnAddonLoaded'                   -- Expanded. Same as previous.
Object.OnEvent.ADDON_LOADED = Object.OnAddonLoaded              -- Calls Object.OnAddonLoaded(Object, addonName, ...)
Object.OnEvent.ADDON_LOADED = function(Object, event, ...)  end -- Calls Object.OnAddonLoaded(Object, addonName, ...)
Object.OnEvent.ADDON_LOADED = nil                               -- Unregister any of the above.

Object:RegisterEvent('ADDON_LOADED')   -- AceEvent4: 2 selfs
Object.RegisterEvent.ADDON_LOADED(true)

AceEvent.OnEvent.ADDON_LOADED = Object                          -- Calls Object.ADDON_LOADED(Object, eventName, addonName, ...)
AceEvent.OnEvent.ADDON_LOADED[Object] = true                    -- Expanded. Same as previous.
AceEvent.OnEvent.ADDON_LOADED[Object] = 'OnAddonLoaded'         -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent.OnEvent.ADDON_LOADED[Object] = Object.OnAddonLoaded    -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent.OnEvent.ADDON_LOADED[Object] = function(Object, eventName, addonName, ...)  end
AceEvent.OnEvent.ADDON_LOADED[Object] = nil                     -- Unregister any of the above.

AceEvent.RegisterEvent(Object, 'ADDON_LOADED')  -- AceEvent3
AceEvent:RegisterEvent('ADDON_LOADED', Object)  -- AceEvent4
AceEvent.RegisterEvent.ADDON_LOADED(Object)     -- AceEvent4

AceEvent.OnEvent.ADDON_LOADED = Object                          -- Calls Object.ADDON_LOADED(Object, eventName, addonName, ...)
AceEvent.OnEvent[Object].ADDON_LOADED = true                    -- Expanded. Same as previous.
AceEvent.OnEvent[Object].ADDON_LOADED = 'OnAddonLoaded'         -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent.OnEvent[Object].ADDON_LOADED = Object.OnAddonLoaded    -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent.OnEvent[Object].ADDON_LOADED = function(Object, eventName, addonName, ...)  end
AceEvent.OnEvent[Object].ADDON_LOADED = nil                     -- Unregister any of the above.

AceEvent.OnEvent.ADDON_LOADED = Object                          -- Calls Object.ADDON_LOADED(Object, eventName, addonName, ...)
AceEvent[Object].OnEvent.ADDON_LOADED = true                    -- Expanded. Same as previous.
AceEvent[Object].OnEvent.ADDON_LOADED = 'OnAddonLoaded'         -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent[Object].OnEvent.ADDON_LOADED = Object.OnAddonLoaded    -- Calls Object.OnAddonLoaded(Object, eventName, addonName, ...)
AceEvent[Object].OnEvent.ADDON_LOADED = function(Object, eventName, addonName, ...)  end
AceEvent[Object].OnEvent.ADDON_LOADED = nil                     -- Unregister any of the above.

AceEvent[Object]:RegisterEvent('ADDON_LOADED')
AceEvent[Object].RegisterEvent.ADDON_LOADED(true)

--]]



