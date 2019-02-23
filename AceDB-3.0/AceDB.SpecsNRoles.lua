--[[
/dump GetSpecializationInfo(0)
/dump GetSpecializationInfo(1)
/dump GetSpecializationInfo(2)
/dump GetSpecializationInfo(3)
/dump GetSpecializationInfo(4)

PLAYER_SPECIALIZATION_CHANGED

_G.<Addon>DB = {
	char/class/global/etc.* = {
		<sectionKey>* = sectionDB
	}
}
_G.<Addon>Profiles = {
	<profileName>* = profile
	_profileKeys = ..
	_db = _G.<Addon>DB
	__/.. = {
		profileKeys = ..
		db = ..
	}
}
--]]



--[[
function AceEvent[SpecsNRoles].PLAYER_SPECIALIZATION_CHANGED(MyAddon, unit)
function AceEvent[SpecsNRoles].Unit.player.PLAYER_SPECIALIZATION_CHANGED(MyAddon, unit)
function AceEvent[SpecsNRoles].Unit['player'].PLAYER_SPECIALIZATION_CHANGED(MyAddon, unit)
local myEvents = AceEvent[SpecsNRoles]
function myEvents.Unit['player'].PLAYER_SPECIALIZATION_CHANGED(MyAddon, unit)

function AceEvent.RegisterEvent.PLAYER_SPECIALIZATION_CHANGED(MyAddon)
function AceEvent.UnregisterEvent.PLAYER_SPECIALIZATION_CHANGED(MyAddon)
function AceEvent.PLAYER_SPECIALIZATION_CHANGED.RegisterEvent(MyAddon)
function AceEvent.PLAYER_SPECIALIZATION_CHANGED.UnregisterEvent(MyAddon)
function AceEvent.RegisterEvents(MyAddon, 'PLAYER_SPECIALIZATION_CHANGED,PLAYER_LOGIN')
function AceEvent.UnregisterAllEvents(MyAddon)

AceEvent[SpecsNRoles].PLAYER_SPECIALIZATION_CHANGED.player = SpecsNRoles.PLAYER_SPECIALIZATION_CHANGED
AceEvent[SpecsNRoles].RegisterUnitEvent.PLAYER_SPECIALIZATION_CHANGED(player)
AceEvent[SpecsNRoles].RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', player)
AceEvent:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', player, SpecsNRoles)
--]]


-- Yet another empty frame, gg buzzard. "High quality coding (tm)"
local SpecsNRoles = CreateFrame('Frame')
SpecsNRoles:Hide()

function SpecsNRoles:OnEvent(event, unit)
	if unit=='player' then  SpecsNRoles.UpdateSpec()  end
end
SpecsNRoles:SetScript('OnEvent', SpecsNRoles.OnEvent)
SpecsNRoles:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED','player')




local roleSpecs = {
	Melee = { 70,71,72,103,251,252,255,259,260,261,263,269,577 },
	-- 70:P-Retribution, 71:W-Arms, 72:W-Fury, 103:DR-Feral, 251:DK-Frost, 252:DK-Unholy, 255:H-Survival, 259:R-Assassination, 260:R-Combat, 261:R-Subtlety, 263:S-Enhancement, 269:M-Windwalker, 577:DH-Havoc 
	Ranged = { 62,63,64,102,253,254,258,262,265,266,267 },
	-- 62:M-Arcane, 63:M-Fire, 64:M-Frost, 102:DR-Balance, 253:H-Beast Mastery, 254:H-Marksmanship, 258:P-Shadow, 262:S-Elemental, 265:W-Affliction, 266:W-Demonology, 267:W-Destruction 
}
local roleEnglish = {
	DAMAGER = 'Damage',
	HEALER  = 'Healer',
	TANK    = 'Tank',
}
local rangedStarterClasses = {
	MAGE    = true,
	-- DRUID   = true,
	HUNTER  = true,
	PRIEST  = true,
	SHAMAN  = true,
	WARLOCK = true,
}


function SpecsNRoles.InitAceDB()
	AceDB.Global = AceDB.Global or {}
	AceDB.Global.showClassInSpecName = true

	-- Usage:  local specIndex = GetSpecialization()  ;  AceDB.roleEnglish[ specIndex and GetSpecializationRole(specIndex) or 'DAMAGER' ]
	AceDB.roleEnglish = roleEnglish

	local keyLocale  = AceDB.keyLocale
	local keyGlobale = AceDB.keyGlobale
	-- role keys:
	keyLocale.Melee   = _G.MELEE
	keyLocale.Ranged  = _G.RANGED
	keyLocale.Healer  = _G.HEALER
	keyLocale.Tank    = _G.TANK
	-- blizrole keys:
	keyLocale.Damage  = _G.DAMAGE
	--[[ already added
	keyLocale.Healer  = _G.HEALER
	keyLocale.Tank    = _G.TANK
	--]]
	--[[ builtin bliz role:  camelcased english used instead
	keyLocale.DAMAGER = _G.DAMAGER
	keyLocale.HEALER  = _G.HEALER
	keyLocale.TANK    = _G.TANK
	--]]

	-- Add localized specialization names to AceDB.keyLocale
	local className,class = UnitClass('player')
	for specIndex = 1,GetNumSpecializations() do
		local specID, specWithoutClass, description, icon, background, blizrole, primaryStat = GetSpecializationInfo(specIndex)
		local specKey = class..'-'..specIndex

		-- Show the class in the specialization?  "Feral" or "Feral Druid"
		local specWithClass = specWithoutClass.." "..className
		local specLocalized = AceDB.Global.showClassInSpecName and specWithClass or specWithoutClass

		-- Only one is really necessary, AceDB.keyGlobale[specLocalized] = specKey is set by  keyLocale[specKey] = specLocalized
		AceDB.keyGlobale[specWithClass] = specKey
		AceDB.keyGlobale[specWithoutClass] = specKey

		keyLocale[specKey] = specLocalized
		-- keyLocale._spec[specID] = specLocalized
		-- keyLocale[ "spec"..specID ] = specLocalized
	end

	-- Set initial value before PLAYER_LOGIN.
	SpecsNRoles.UpdateSpec()
end


-- Whole role/spec identification is not straightforward, therefore it does not fit a generic library, and has its own.
-- Keys are always in English, not localized.  AceDB.keyLocale[key] == the translation.
function SpecsNRoles.UpdateSpec()
	local tokenKeys = AceDB.ProfileTokenKeys
	local class = tokenKeys.class
	-- local className, class = UnitClass('player')
	local specIndex = GetSpecialization()
	local specKey, role3, dpsrole

	if not specIndex then
		specKey = class         -- Spec is '<CLASS>' until decided.
		role3   = 'Damage'
		dpsrole = rangedStarterClasses[class] and 'Ranged' or 'Melee'

	else
		-- local blizrole = GetSpecializationRole(specIndex)
		local specID, specLocalized, description, icon, background, blizrole, primaryStat = GetSpecializationInfo(specIndex)

		specKey = class..'-'..specIndex    -- '<CLASS>-<specIndex>'
		role3   = roleEnglish[blizrole]    -- 'Damage/Tank/Healer'
		-- tokenKeys['specID'] = specID

		-- dpsrole based on specID:
		local indexOf = LibCommon.Require.indexOf
		if     indexOf(roleSpecs.Melee,  specID) then  dpsrole = 'Melee'
		elseif indexOf(roleSpecs.Ranged, specID) then  dpsrole = 'Ranged'
		elseif blizrole == 'DAMAGER' then
			_G.geterrorhandler()( "Encountered an unknown specialization with 'Damage' role:  specID=".._G.tostring(specID)..", name='".._G.tostring(specLocalized).."'." )
		end
		
	end

	local role = dpsrole or roleEnglish[blizrole]
	tokenKeys['spec']    = specKey         -- '<CLASS>-<specIndex>'
	tokenKeys['role']    = role            -- 'Melee/Ranged/Tank/Healer'
	tokenKeys['role3']   = role3           -- 'Damage/Tank/Healer'
	tokenKeys['dpsrole'] = dpsrole         -- 'Melee/Ranged'/nil
	-- tokenKeys['blizrole'] = blizrole    -- 'DAMAGER/TANK/HEALER'
end


-- GetSpecializationInfo(specIndex [, isInspect [, isPet [, ? [, genderCode]]]])
--[[
specID - number - between 62-270, demonhunter: 577,581; 0 if the query is invalid.
blizrole - string - One of 'DAMAGER/TANK/HEALER'
-- Missing roles:  'Melee', 'Ranged', ['Magic']
icon - string - Texture path to this specialization's icon.
background - String - Background texture name for this talent tree
-- Prepend "Interface\TALENTFRAME\" to this value for a valid texture path.
--]]




--[[
-- sectionKeys.class  and  AceDB.keyLocale[class]  can be:
 1.  WARRIOR        "Warrior"         "Guerrier"
 2.  PALADIN        "Paladin"         "Paladin"
 3.  HUNTER         "Hunter"          "Chasseur"
 4.  ROGUE          "Rogue"           "Voleur"
 5.  PRIEST         "Priest"          "Prêtre"
 6.  DEATHKNIGHT    "Death Knight"    "Chevalier de la mort"
 7.  SHAMAN         "Shaman"          "Chaman"
 8.  MAGE           "Mage"            "Mage"
 9.  WARLOCK        "Warlock"         "Démoniste"
10.  MONK           "Monk"            "Moine"
11.  DRUID          "Druid"           "Druide"
12.  DEMONHUNTER    "Demon Hunter"    "Chasseur de démons"
--]]


--[[
meleeSpecs:
70 - Paladin: Retribution
71 - Warrior: Arms
72 - Warrior: Fury
103 - Druid: Feral
251 - Death Knight: Frost
252 - Death Knight: Unholy
255 - Hunter: Survival
259 - Rogue: Assassination
260 - Rogue: Combat
261 - Rogue: Subtlety
263 - Shaman: Enhancement
269 - Monk: Windwalker
577 - Demon Hunter: Havoc

rangedSpecs:
62 - Mage: Arcane
63 - Mage: Fire
64 - Mage: Frost
102 - Druid: Balance
253 - Hunter: Beast Mastery
254 - Hunter: Marksmanship
258 - Priest: Shadow
262 - Shaman: Elemental
265 - Warlock: Affliction
266 - Warlock: Demonology
267 - Warlock: Destruction

meleeSpecs:
70:Pala-Retri
71:Warr-Arms
72:Warr-Fury
103:Dudu-Feral
251:DK-Frost
252:DK-Unholy
255:Hunt-Surv
259:Rog-Assa
260:Rog-Comb
261:Rog-Sub
263:Sham-Enha
269:Monk-WW
577:DH-Havoc

rangedSpecs:
62:Mag-Arcane
63:Mag-Fire
64:Mag-Frost
102:Dudu-Bala
253:Hunt-BM
254:Hunt-MM
258:Pri-Sha
262:Sham-Ele
265:Lock-Affl
266:Lock-Demo
267:Lock-Dest
--]]


