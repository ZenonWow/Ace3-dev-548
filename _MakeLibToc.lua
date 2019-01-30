local template =
[===[## Interface: 50400
## Title: Ace3 library ADDON_NAME
## Author: Ace3 Development Team
## X-Website: http://www.wowace.com
## X-Category: Library
## X-License: Limited BSD

## LoadOnDemand: 1
]===]
-- ## OptionalDeps: DEPENDENCIES



local addons = {
"AceAddon-3.0",
"AceBucket-3.0",
"AceComm-3.0",
"AceConfig-3.0/AceConfigCmd-3.0",
"AceConfig-3.0/AceConfigDialog-3.0",
"AceConfig-3.0/AceConfigRegistry-3.0",
"AceConfig-3.0",
"AceConsole-3.0",
"AceDB-3.0",
"AceDBOptions-3.0",
"AceEvent-3.0",
"AceGUI-3.0",
"AceGUI-3.0-SharedMediaWidgets",
"AceHook-3.0",
"AceLocale-3.0",
"AceSerializer-3.0",
"AceTab-3.0",
"AceTimer-3.0",
"CallbackHandler-1.0",
"LibDataBroker-1.1",
"LibDBIcon-1.0",
"LibEnv",
"LibSharedMedia-3.0",
-- "LibStub",  -- already has LibStub.toc
}



local D1 = "LibStub, CallbackHandler-1.0"
local dependencies = {
	["LibStub"]                          = "",
	["LibEnv"]                           = "LibStub",
	["CallbackHandler-1.0"]              = "LibStub",
	["LibDBIcon-1.0"]                    = D1..", LibDataBroker-1.1",
	["AceBucket-3.0"]                    = D1..", AceEvent-3.0, AceTimer-3.0",
	["AceConfig-3.0"]                    = D1..", AceConfigRegistry-3.0, AceConfigCmd-3.0, AceConfigDialog-3.0, AceConfigDropdown-3.0",
	["AceConfigCmd-3.0"]                    = D1..", AceConfigRegistry-3.0, AceConsole-3.0",
	["AceConfigDialog-3.0"]                    = D1..", AceGUI-3.0, AceConfigRegistry-3.0",
	-- "AceGUISharedMediaWidgets-1.0":
	["AceGUI-3.0-SharedMediaWidgets"]                    = D1..", AceGUI-3.0, LibSharedMedia-3.0",
}
--[[
["AceAddon-3.0"]                     = D1,
["AceComm-3.0"]                      = D1,
["AceConfig-3.0"]                    = D1,
["AceConsole-3.0"]                   = D1,
["AceDB-3.0"]                        = D1,
["AceDBOptions-3.0"]                 = D1,
["AceEvent-3.0"]                     = D1,
["AceGUI-3.0"]                       = D1,
["AceHook-3.0"]                      = D1,
["AceLocale-3.0"]                    = D1,
["AceSerializer-3.0"]                = D1,
["AceTab-3.0"]                       = D1,
["AceTimer-3.0"]                     = D1,
["LibDataBroker-1.1"]                = D1,
["LibSharedMedia-3.0"]               = D1,
--]]



local morefiles = {}

morefiles["AceComm-3.0"] = [==[
ChatThrottleLib.lua
AceComm-3.0.lua
]==]

morefiles["AceConfig-3.0"] = [==[
AceConfigRegistry-3.0\AceConfigRegistry-3.0.lua
AceConfigCmd-3.0\AceConfigCmd-3.0.lua
AceConfigDialog-3.0\AceConfigDialog-3.0.lua
# AceConfigDropdown-3.0\AceConfigDropdown-3.0.lua

AceConfig-3.0.lua
]==]


morefiles["AceGUI-3.0"] = [==[
AceGUI-3.0.lua

#### Container
widgets\AceGUIContainer-BlizOptionsGroup.lua
widgets\AceGUIContainer-DropDownGroup.lua
widgets\AceGUIContainer-Frame.lua
widgets\AceGUIContainer-InlineGroup.lua
widgets\AceGUIContainer-ScrollFrame.lua
widgets\AceGUIContainer-SimpleGroup.lua
widgets\AceGUIContainer-TabGroup.lua
widgets\AceGUIContainer-TreeGroup.lua
widgets\AceGUIContainer-Window.lua

#### Widgets
widgets\AceGUIWidget-Button.lua
widgets\AceGUIWidget-CheckBox.lua
widgets\AceGUIWidget-ColorPicker.lua
widgets\AceGUIWidget-DropDown.lua
widgets\AceGUIWidget-DropDown-Items.lua
widgets\AceGUIWidget-EditBox.lua
widgets\AceGUIWidget-Heading.lua
widgets\AceGUIWidget-Icon.lua
widgets\AceGUIWidget-InteractiveLabel.lua
widgets\AceGUIWidget-Keybinding.lua
widgets\AceGUIWidget-Label.lua
widgets\AceGUIWidget-MultiLineEditBox.lua
widgets\AceGUIWidget-Slider.lua
]==]


morefiles["AceGUI-3.0-SharedMediaWidgets"] = [==[
prototypes.lua
FontWidget.lua
SoundWidget.lua
StatusbarWidget.lua
BorderWidget.lua
BackgroundWidget.lua
]==]




local function writeToc(foldername)
	local addonname = foldername:match(".*/(.-)$") or foldername
	local filename = foldername.."/"..addonname..".toc"
	local deps,files = dependencies[addonname] or D1, morefiles[addonname]
	files =  files  and  "\n\n"..files  or  ("\n"..addonname..".lua\n")
	local file = io.open(filename, "w")
	-- local body = template:gsub("ADDON_NAME", addonname):gsub("DEPENDENCIES", deps)..(files).."\n",n"
	local body = template:gsub("ADDON_NAME", addonname) .. "## OptionalDeps: "..deps.."\n" .. files.."\n"
	file:write(body)
	file:close()
end



local function MakeLibToc()
	for  i,foldername  in ipairs(addons) do
		writeToc(foldername)
	end
end


MakeLibToc()

