--[[
Name: DBIcon-1.0
Revision: $Rev: 34 $
Author(s): Rabbit (rabbit.magtheridon@gmail.com)
Description: Allows addons to register to recieve a lightweight minimap icon as an alternative to more heavy LDB displays.
Dependencies: LibStub
License: GPL v2 or later.
]]

--[[
Copyright (C) 2008-2011 Rabbit

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
]]

-----------------------------------------------------------------------
-- DBIcon-1.0
--
-- Disclaimer: Most of this code was ripped from Barrel but fixed, streamlined
--             and cleaned up a lot so that it no longer sucks.
--

local MAJOR, MINOR = "LibDBIcon-1.0", 34.1    -- tonumber(("$Rev: 34 $"):match("(%d+)"))
assert(LibStub, MAJOR .. " requires LibStub.")
local ldb = LibStub("LibDataBroker-1.1", nil, MAJOR)
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.disabled = lib.disabled or nil
lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}

local LibCommon = _G.LibCommon or {}  ;  _G.LibCommon = LibCommon
LibCommon.softassert = LibCommon.softassert or  function(ok, message)  return ok, ok or _G.geterrorhandler()(message)  end
local safecall = assert(LibCommon.safecall, "LibMinimapIcon(LibDBIcon) requires LibCommon.safecall")


function lib:IconCallback(event, name, key, value, dataobj)
	local button = lib.objects[name]
	if button then
		if key == "icon" then
			button.icon:SetTexture(value)
		elseif key == "iconCoords" then
			button.icon:UpdateCoord()
		elseif key == "iconR" then
			local _, g, b = button.icon:GetVertexColor()
			button.icon:SetVertexColor(value, g, b)
		elseif key == "iconG" then
			local r, _, b = button.icon:GetVertexColor()
			button.icon:SetVertexColor(r, value, b)
		elseif key == "iconB" then
			local r, g = button.icon:GetVertexColor()
			button.icon:SetVertexColor(r, g, value)
		end
	end
end

function lib.RegisterCallbacks(lib)
	if lib.callbackRegistered then  return  end
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__icon", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconR", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconG", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconB", "IconCallback")
	ldb.RegisterCallback(lib, "LibDataBroker_AttributeChanged__iconCoords", "IconCallback")
	lib.callbackRegistered = true
end

function lib.UnregisterCallbacks(lib)
	ldb.UnregisterAllCallbacks(lib)
	--[[
	ldb.UnregisterCallback(lib, "LibDataBroker_AttributeChanged__icon")
	ldb.UnregisterCallback(lib, "LibDataBroker_AttributeChanged__iconR")
	ldb.UnregisterCallback(lib, "LibDataBroker_AttributeChanged__iconG")
	ldb.UnregisterCallback(lib, "LibDataBroker_AttributeChanged__iconB")
	ldb.UnregisterCallback(lib, "LibDataBroker_AttributeChanged__iconCoords")
	--]]
	lib.callbackRegistered = nil
end

lib:RegisterCallbacks()

-- Tooltip code ripped from StatBlockCore by Funkydude
local function getAnchors(frame)
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

local function onEnter(self)
	if self.isMoving then return end
	local obj = self.dataObject
	if obj.OnTooltipShow then
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(getAnchors(self))
		obj.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	elseif obj.OnEnter then
		obj.OnEnter(self)
	end
end

local function onLeave(self)
	local obj = self.dataObject
	GameTooltip:Hide()
	if obj.OnLeave then obj.OnLeave(self) end
end

--------------------------------------------------------------------------------

local onClick, onMouseUp, onMouseDown, onDragStart, onDragStop, onDragEnd, updatePosition

do
	local minimapShapes = {
		["ROUND"] = {true, true, true, true},
		["SQUARE"] = {false, false, false, false},
		["CORNER-TOPLEFT"] = {false, false, false, true},
		["CORNER-TOPRIGHT"] = {false, false, true, false},
		["CORNER-BOTTOMLEFT"] = {false, true, false, false},
		["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
		["SIDE-LEFT"] = {false, true, false, true},
		["SIDE-RIGHT"] = {true, false, true, false},
		["SIDE-TOP"] = {false, false, true, true},
		["SIDE-BOTTOM"] = {true, true, false, false},
		["TRICORNER-TOPLEFT"] = {false, true, true, true},
		["TRICORNER-TOPRIGHT"] = {true, false, true, true},
		["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
		["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
	}

	function updatePosition(button)
		local angle = math.rad(button.db and button.db.minimapPos or button.minimapPos or 225)
		local x, y, q = math.cos(angle), math.sin(angle), 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end
		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local quadTable = minimapShapes[minimapShape]
		if quadTable[q] then
			x, y = x*80, y*80
		else
			local diagRadius = 103.13708498985 --math.sqrt(2*(80)^2)-10
			x = math.max(-80, math.min(x*diagRadius, 80))
			y = math.max(-80, math.min(y*diagRadius, 80))
		end
		button:SetPoint("CENTER", Minimap, "CENTER", x, y)
	end
end

function onClick(self, b) if self.dataObject.OnClick then self.dataObject.OnClick(self, b) end end
function onMouseDown(self) self.isMouseDown = true; self.icon:UpdateCoord() end
function onMouseUp(self) self.isMouseDown = false; self.icon:UpdateCoord() end

do
	local function onUpdate(self)
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		if self.db then
			self.db.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
		else
			self.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
		end
		updatePosition(self)
	end

	function onDragStart(self)
		self:LockHighlight()
		self.isMouseDown = true
		self.icon:UpdateCoord()
		self:SetScript("OnUpdate", onUpdate)
		self.isMoving = true
		GameTooltip:Hide()
	end
end

function onDragStop(self)
	self:SetScript("OnUpdate", nil)
	self.isMouseDown = false
	self.icon:UpdateCoord()
	self:UnlockHighlight()
	self.isMoving = nil
end

local defaultCoords = {0, 1, 0, 1}
local function updateCoord(self)
	local coords = self:GetParent().dataObject.iconCoords or defaultCoords
	local deltaX, deltaY = 0, 0
	if not self:GetParent().isMouseDown then
		deltaX = (coords[2] - coords[1]) * 0.05
		deltaY = (coords[4] - coords[3]) * 0.05
	end
	self:SetTexCoord(coords[1] + deltaX, coords[2] - deltaX, coords[3] + deltaY, coords[4] - deltaY)
end

local function createButton(name, dataobj, db)
	local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
	button.dataObject = dataobj
	button.db = db
	button:SetFrameStrata("MEDIUM")
	button:SetSize(31, 31)
	button:SetFrameLevel(8)
	button:RegisterForClicks("anyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(dataobj.icon)
	icon:SetPoint("TOPLEFT", 7, -6)
	button.icon = icon
	button.isMouseDown = false

	local r, g, b = icon:GetVertexColor()
	icon:SetVertexColor(dataobj.iconR or r, dataobj.iconG or g, dataobj.iconB or b)

	icon.UpdateCoord = updateCoord
	icon:UpdateCoord()

	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	button:SetScript("OnClick", onClick)
	if not db or not db.lock then
		button:SetScript("OnDragStart", onDragStart)
		button:SetScript("OnDragStop", onDragStop)
	end
	button:SetScript("OnMouseDown", onMouseDown)
	button:SetScript("OnMouseUp", onMouseUp)

	lib.objects[name] = button

	if lib.loggedIn then
		updatePosition(button)
		button:SetShown(not db or not db.hide)
	end
	lib.callbacks:Fire("LibDBIcon_IconCreated", button, name) -- Fire 'Icon Created' callback

	local safecall = LibCommon.safecall or pcall
	safecall(dataobj.AttachDisplay, dataobj, button)
end

-- We could use a metatable.__index on lib.objects, but then we'd create
-- the icons when checking things like :IsRegistered, which is not necessary.
local function check(name)
	if lib.notCreated[name] then
		createButton(name, lib.notCreated[name][1], lib.notCreated[name][2])
		lib.notCreated[name] = nil
	end
end

-- Wait a bit with the initial positioning to let any GetMinimapShape addons
-- load up.
if lib.loggedIn == nil then
	lib.loggedIn = false
	local f = CreateFrame("Frame")
	f:SetScript("OnEvent", function()
		for _, button in pairs(lib.objects) do
			updatePosition(button)
			button:SetShown( not lib.disabled and (not button.db or not button.db.hide) )
		end
		lib.loggedIn = true
		f:SetScript("OnEvent", nil)
		f = nil
	end)
	f:RegisterEvent("PLAYER_LOGIN")
end

local function getDatabase(name)
	return lib.notCreated[name] and lib.notCreated[name][2] or lib.objects[name].db
end

function lib:Register(name, dataobj, db)
	if not dataobj.icon then  error("LibMinimapIcon:  LibDBIcon:Register():  Can't register dataobject '"..name.."' without .icon set.")  end
	if lib.objects[name] or lib.notCreated[name] then
		LibCommon.softassert(false, "LibMinimapIcon:  LibDBIcon:Register():  dataobject '"..name.."' already registered.")
		return false
	end

	if not lib.disabled and (not db or not db.hide) then
		createButton(name, dataobj, db)
	else
		lib.notCreated[name] = {dataobj, db}
	end
end

function lib:Unregister(name, dataobjIn)
	local button = lib.objects[name]
	local dataobj = button.dataObject
	local safecall = LibCommon.safecall or pcall
	safecall(dataobj.DetachDisplay, dataobj, button)

	lib.notCreated[name] = nil
	lib.objects[name] = nil
	if not button then  return  end

	button.dataObject = nil
	button.db = nil
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)
	button:SetScript("OnClick", nil)
	button:SetScript("OnDragStart", nil)
	button:SetScript("OnDragStop", nil)
	button:SetScript("OnMouseDown", nil)
	button:SetScript("OnMouseUp", nil)
	button:SetParent(nil)
end

function lib:Lock(name)
	if not lib:IsRegistered(name) then return end
	local button = lib.objects[name]
	if button then
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnDragStop", nil)
	end
	local db = getDatabase(name)
	if db then db.lock = true end
end

function lib:Unlock(name)
	if not lib:IsRegistered(name) then return end
	local button = lib.objects[name]
	if button then
		button:SetScript("OnDragStart", onDragStart)
		button:SetScript("OnDragStop", onDragStop)
	end
	local db = getDatabase(name)
	if db then db.lock = nil end
end

function lib:Hide(name)
	local button = lib.objects[name]
	if not button then return end
	button:Hide()
end
function lib:Show(name)
	if lib.disabled then return end
	assert(name, "Usage: LibMinimapIcon:  LibDBIcon:Show(dataobjectname)")
	check(name)
	local button = lib.objects[name]
	assert(button, "Dataobject not registered: ".. tostring(name))
	button:Show()
	updatePosition(button)
end
function lib:Toggle(name, shown)
	if lib.disabled then return end
	assert(name, "Usage: LibMinimapIcon:  LibDBIcon:Toggle(dataobjectname, shown or nil)")
	check(name)
	local button = lib.objects[name]
	assert(button, "Dataobject not registered: ".. tostring(name))
	if  shown == nil  then  shown = not button:IsShown()  end
	button:SetShown(shown)
	if shown then  updatePosition(button)  end
end

function lib:IsRegistered(name)
	return (lib.objects[name] or lib.notCreated[name]) and true or false
end
function lib:Refresh(name, db)
	if lib.disabled then return end
	check(name)
	local button = lib.objects[name]
	if db then button.db = db end
	updatePosition(button)
	if not button.db or not button.db.hide then
		button:Show()
	else
		button:Hide()
	end
	if not button.db or not button.db.lock then
		button:SetScript("OnDragStart", onDragStart)
		button:SetScript("OnDragStop", onDragStop)
	else
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnDragStop", nil)
	end
end
function lib:GetMinimapButton(name)
	return lib.objects[name]
end

function lib:EnableLibrary()
	lib.disabled = nil
	-- lib:RegisterCallbacks()
	local safecall = LibCommon.safecall or pcall

	for name, button in pairs(lib.objects) do
		if not button.db or not button.db.hide then
			button:Show()
			updatePosition(button)
			local dataobj = button.dataObject
			safecall(dataobj.AttachDisplay, dataobj, button)
		end
	end
	for name, data in pairs(lib.notCreated) do
		if not data.db or not data.db.hide then
			createButton(name, data[1], data[2])
			lib.notCreated[name] = nil
		end
	end
end

function lib:DisableLibrary()
	lib.disabled = true
	-- lib:UnregisterCallbacks()
	local safecall = LibCommon.safecall or pcall

	for name, button in pairs(lib.objects) do
		button:Hide()
		local dataobj = button.dataObject
		safecall(dataobj.DetachDisplay, dataobj, button)
	end
end

