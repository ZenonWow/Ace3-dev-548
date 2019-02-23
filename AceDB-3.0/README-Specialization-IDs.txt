from LUI_Dynamics.lua:
--
if role == "TANK" then
	actualRole ="Tank"
elseif role == "HEALER" then
	actualRole = "Healer"
elseif role == "DAMAGER" then
	actualRole = "Ranged" 
	if (class=="PALADIN" or class=="DEATHKNIGHT" or class=="ROGUE" or class=="WARRIOR") then 	actualRole = "Melee"	end
	if (class=="SHAMAN" or class=="DRUID") and  (GetSpecialization() == 2) then actualRole = "Melee" end
	if (class=="MONK") and  (GetSpecialization() == 3) then actualRole = "Melee" end
end

if actualSpec == "No Assigned Talents" then 
	if class == "MAGE" or class == "WARLOCK" or class == "HUNTER" or class == "PRIEST" or class == "DRUID" or class == "SHAMAN" then
		actualRole = "Ranged" 
	else
		actualRole = "Melee"
	end
end





Blood
Frost
Unholy
Havoc
Vengeance
Balance
Feral
Guardian
Restoration
Beast Mastery
Marksmanship
Survival
Arcane
Fire
Frost
Brewmaster
Mistweaver
Windwalker
Holy
Protection
Retribution
Discipline
Holy
Shadow
Assassination
Outlaw
Subtlety
Elemental
Enhancement
Restoration
Affliction
Demonology
Destruction
Arms
Fury
Protection



SpecializationID
The ID that is returned from the GetSpecializationInfo().
These IDs can be used to confirm a primary talent tree without concern of localization. These IDs are used by GetSpecializationInfoByID(ID).

Death Knight
250 - Blood
251 - Frost
252 - Unholy
Demon Hunter
577 - Havoc
581 - Vengeance
Druid
102 - Balance
103 - Feral
104 - Guardian
105 - Restoration
Hunter
253 - Beast Mastery
254 - Marksmanship
255 - Survival
Mage
62 - Arcane
63 - Fire
64 - Frost
Monk
268 - Brewmaster
269 - Windwalker
270 - Mistweaver
Paladin
65 - Holy
66 - Protection
70 - Retribution
Priest
256 - Discipline
257 - Holy
258 - Shadow
Rogue
259 - Assassination
260 - Outlaw
261 - Subtlety
Shaman
262 - Elemental
263 - Enhancement
264 - Restoration
Warlock
265 - Affliction
266 - Demonology
267 - Destruction
Warrior
71 - Arms
72 - Fury
73 - Protection



https://wowwiki.fandom.com/wiki/SpecializationID
--

Mage
62 - Arcane
63 - Fire
64 - Frost
Paladin
65 - Holy
66 - Protection
70 - Retribution
Warrior
71 - Arms
72 - Fury
73 - Protection
Druid
102 - Balance
103 - Feral
104 - Guardian
105 - Restoration
Death Knight  -- what is DK doing before Hunter?
250 - Blood
251 - Frost
252 - Unholy
Hunter
253 - Beast Mastery
254 - Marksmanship
255 - Survival
Priest
256 - Discipline
257 - Holy
258 - Shadow
Rogue
259 - Assassination
260 - Outlaw
261 - Subtlety
Shaman
262 - Elemental
263 - Enhancement
264 - Restoration
Warlock
265 - Affliction
266 - Demonology
267 - Destruction
Monk
268 - Brewmaster
269 - Windwalker
270 - Mistweaver
Demon Hunter
577 - Havoc
581 - Vengeance




http://wowprogramming.com/docs/api_types.html#specID
--
Type: specID
Global index of different specializations used by GetSpecializationInfoByID(), GetSpecializationRoleByID(), and returned by GetArenaOpponentSpec().

62 - Mage: Arcane
63 - Mage: Fire
64 - Mage: Frost
65 - Paladin: Holy
66 - Paladin: Protection
70 - Paladin: Retribution
71 - Warrior: Arms
72 - Warrior: Fury
73 - Warrior: Protection
102 - Druid: Balance
103 - Druid: Feral
104 - Druid: Guardian
105 - Druid: Restoration
250 - Death Knight: Blood
251 - Death Knight: Frost
252 - Death Knight: Unholy
253 - Hunter: Beast Mastery
254 - Hunter: Marksmanship
255 - Hunter: Survival
256 - Priest: Discipline
257 - Priest: Holy
258 - Priest: Shadow
259 - Rogue: Assassination
260 - Rogue: Combat
261 - Rogue: Subtlety
262 - Shaman: Elemental
263 - Shaman: Enhancement
264 - Shaman: Restoration
265 - Warlock: Affliction
266 - Warlock: Demonology
267 - Warlock: Destruction
268 - Monk: Brewmaster
269 - Monk: Windwalker
270 - Monk: Mistweaver
577 - Demon Hunter: Havoc
581 - Demon Hunter: Vengeance



13 melee, 9 magic, 2 ranged

13 melee
--
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

9+2 ranged
--
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


