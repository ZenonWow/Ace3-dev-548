-----------------------------------------------
--- LDB:Init():  Initialize registry tables and metatable function closures.
--
function LibDataBroker.Init(lib)
	-- One dataobject metatable (domt) for all dataobjects. Versions: 1 <= MINOR <= 4
	lib.domt = lib.domt or {}
	local domt = lib.domt
	domt.NOTE = lib.MetaTableNote

	-- Upvalues for __index and __newindex().
	local attributestorage, namestorage, callbacks = lib.attributestorage, lib.namestorage, lib.callbacks

	-- Since MINOR = 5  `attributestorage[dataobj]`  is never nil. It exists from :NewDataObject(name, dataobj) until :RemoveDataObject(dataobj).
	domt.__index = function(dataobj, key)
		return attributestorage[dataobj][key]
		-- return (attributestorage[dataobj] or dataobj)[key]
	end

	--- __newindex(dataobj, key, value):  Triggered by changing a field/attribute/property on a dataobject.
	-- This is achieved by intentionally keeping the dataobject as an empty proxy table.
	domt.__newindex = function(dataobj, key, value)
		local attributes = attributestorage[dataobj]
		-- if not attributes then  lib:LostDataObject(dataobj, key, value) ; return  end
		if attributes[key] == value then  return  end
		attributes[key] = value

		local name = namestorage[dataobj] or "?"
		local callbacks = callbacks
		callbacks:Fire("LibDataBroker_AttributeChanged",                  name, key, value, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name,           name, key, value, dataobj)
		callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..key, name, key, value, dataobj)
		-- This is the order since MINOR = 1, tho "__key" might be preferable before "_name" as it is more generic.
		callbacks:Fire("LibDataBroker_AttributeChanged__"..key,           name, key, value, dataobj)
	end

	-- The functions in `lib.domt` keep copies of  `lib.attributestorage, lib.namestorage, lib.callbacks`  in upvalues,
	-- therefore those fields cannot be changed without regenerating the functions by another call to lib:Init().
	-- This restriction can be lifted for the price of +1 `lib.` lookup in __index() and +3 lookup in __newindex().

end  -- LibDataBroker.Init(lib)


