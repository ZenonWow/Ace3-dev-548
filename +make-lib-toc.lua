-- +make-lib-toc.lua


local template =
[===[## Interface: 50400
## Title: Lib: ADDON_NAME
## Author: Ace3 Development Team
## X-Website: http://www.wowace.com/projects/ace3/
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
-- "CallbackHandler-1.0",  -- from CallbackHandler-1.0-r16.zip
-- "LibDataBroker-1.1",  -- recreated from  https://github.com/tekkub/libdatabroker-1-1/blob/52a68af9/LibDataBroker-1.1.toc  --  Remove all the other crap, this lib isn't standalone
-- "LibDBIcon-1.0",  -- from LibDBIcon-1.0-r38-release.zip
-- "LibDataBrokerIcon-1.0",  -- from LibDBIcon-1.0-r38-release.zip
-- "LibSharedMedia-3.0",  -- from LibSharedMedia-3.0-r87.zip
-- "LibCommon",  -- custom LibCommon.toc
-- "LibStub",  -- from LibStub-1.0.2-40200.zip
}



local D2 = "LibStub, CallbackHandler-1.0"
local D3 = "LibStub, LibCommon, CallbackHandler-1.0"
local dependencies = {
	["LibCommon"]                        = "",
	["LibStub"]                          = "",
	["CallbackHandler-1.0"]              = "LibStub, LibCommon",
	["LibDataBroker-1.1"]                = D3,
	["LibDBIcon-1.0"]                    = D2..",   LibDataBroker-1.1",

	["AceBucket-3.0"]                    = D3..",   AceEvent-3.0, AceTimer-3.0",
	["AceConfig-3.0"]                    = D2..",   AceConsole-3.0, AceGUI-3.0,   AceConfigRegistry-3.0, AceConfigCmd-3.0, AceConfigDialog-3.0",    -- , AceConfigDropdown-3.0",
	["AceConfigCmd-3.0"]                 = D2..",   AceConsole-3.0,   AceConfigRegistry-3.0",
	["AceConfigDialog-3.0"]              = D2..",   AceGUI-3.0,   AceConfigRegistry-3.0",
	-- "AceGUISharedMediaWidgets-1.0":
	["AceGUI-3.0-SharedMediaWidgets"]    = D2..",   AceGUI-3.0, LibSharedMedia-3.0",
	--[[
	["LibSharedMedia-3.0"]               = D2,
	["AceAddon-3.0"]                     = D2,
	["AceEvent-3.0"]                     = D2,
	["AceTimer-3.0"]                     = D2,
	["AceHook-3.0"]                      = D2,
	["AceDB-3.0"]                        = D2,
	["AceDBOptions-3.0"]                 = D2,
	["AceLocale-3.0"]                    = D2,
	["AceConsole-3.0"]                   = D2,

	["AceGUI-3.0"]                       = D2,
	["AceConfig-3.0"]                    = D2,
	["AceSerializer-3.0"]                = D2,
	["AceComm-3.0"]                      = D2,
	["AceTab-3.0"]                       = D2,
	--]]
}


local commonfiles = [==[
]==]


local morefiles = {}

morefiles["LibStub"] = [==[
# Packaged with Ace3
LibStub.lua

# Extensions
LibStub.Short.lua
LibStub.SetEnv.lua
]==]

morefiles["LibCommon"] = [==[
# LibCommon-all.lua
parts\all.xml
]==]

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
	print(addonname..".toc")
	local deps,files = dependencies[addonname] or D2, morefiles[addonname]
	if commonfiles ~= "" then  commonfiles = commonfiles.."\n"  end
	files =  files  and  "\n\n"..commonfiles..files  or  ("\n"..commonfiles..addonname..".lua\n")
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
	print()
	print("Press ENTER")
	io.read()
end


MakeLibToc()

