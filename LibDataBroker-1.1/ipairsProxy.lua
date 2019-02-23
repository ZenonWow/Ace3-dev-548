-- http://lua-users.org/wiki/NextMetamethodForIndexTable
--[[
Next Metamethod For Index Table
 lua-users home / wiki 

Rewriting next() for when __index is a Table
To make a next() function that matches this indexing method (including the shadowing of higher level keys by lower level ones) you can use the following code...
--]]


function tnext(t,o)
  local i,v

  if o then
    -- 'o' is not nil (it is a real existing key).
    -- Locate the key's table.
    local r = t
    while not rawget(r,o) do
      local m = getmetatable(r)
      r = m and m.__index
      assert(type(r)=="table", "Key not in table")
    end

    -- Grab the next non-shadowed index
    local s
    i = o -- Start with the current index.
    repeat
      -- Get next real (non-nil) index.
      i,v = next(r,i)
      while (i==nil) do
        local m = getmetatable(r)
        r = m and m.__index
        if (r==nil) then return nil,nil end -- None left.
        assert(type(r)=="table", "__index must be table or nil")
        i,v = next(r)
      end
      -- Find the next index's level.
      s = t
      while not rawget(s,i) do
        local m = getmetatable(s)
        s = m and m.__index
      end
      -- If match then not shadowed, else repeat.
    until (r==s)
    -- Return it.
    return i,v

  else
    -- 'o' is nil, so want the first real key. Scan each table in
    -- turn until we find one (or give up if all are empty).
    while t do
      i,v = next(t)
      if i then break end
      local m = getmetatable(t)
      t = m and m.__index
      assert(t==nil or type(t)=="table", "__index must be table or nil")
    end
    return i,v
  end
end


--[[
Example usage
t = {a=111,  b=222, c=333}
u = {a=123, d=444}
setmetatable(t, {__index=u})
for i,v in tnext,t do print(i,v) end
will give a result of:
a  111
b  222
c  333
d  444
-- PeterHill

See Also
GeneralizedPairsAndIpairs - alternate approach using new metamethods.
RecentChanges · preferences
edit · history
Last edited May 28, 2007 9:40 pm GMT (diff)
--]]

