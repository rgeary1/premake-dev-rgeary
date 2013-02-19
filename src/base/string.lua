--
-- string.lua
-- Additions to Lua's built-in string functions.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--


--
-- Returns an array of strings, each of which is a substring of s
-- formed by splitting on boundaries formed by `pattern`.
-- 

	function string.explode(s, pattern, plain, ignoreRepeatedDelimiters)
		if (pattern == '') then return false end
		local pos = 0
		local arr = { }
		for st,sp in function() return s:find(pattern, pos, plain) end do
			if ignoreRepeatedDelimiters then
				if sp ~= pos then 
					table.insert(arr, s:sub(pos, st-1))
				end
			else
				table.insert(arr, s:sub(pos, st-1))
			end
			pos = sp + 1
		end
		table.insert(arr, s:sub(pos))
		return arr
	end

--
-- Split is similar to explode, but with a better name & default delimiters
--  split also preserves delimiters within double quotes "" or %{ } 
--
	local splitCache = {}
	function string.split(s, delimiters)
		-- memo cache
		delimiters = delimiters or ", \t\n|"
		splitCache[delimiters] = splitCache[delimiters] or {}
		local cache = splitCache[delimiters]
		if cache[s] then return cache[s] end
		
		local pattern = '['..delimiters..'"%%]'
		local searchPos = 0
		local copyFrom = 0
		local rv = { }
		for pstart,pend in function() return s:find(pattern, searchPos) end do
			if s:sub(pstart, pstart+1) == '%{' then
				searchPos = (s:find("}",pend+1) or searchPos)+1
			elseif s:sub(pstart,pstart) == '"' then
				searchPos = (s:find('\"',pend+1) or searchPos)+1
			else
				if copyFrom <= pstart-1 then
					table.insert( rv, s:sub(copyFrom, pstart-1) )
				end
				copyFrom = pend+1
				searchPos = pend+1
			end
		end
		if #s >= copyFrom and copyFrom < #s then
			table.insert(rv, s:sub(copyFrom))
		end
		cache[s] = rv
		
		return rv
	end	


--
-- Find the last instance of a pattern in a string.
--

	function string.findlast(s, pattern, plain)
		local curr = 0
		repeat
			local next = s:find(pattern, curr + 1, plain)
			if (next) then curr = next end
		until (not next)
		if (curr > 0) then
			return curr
		end	
	end
	
--
-- Find searching backwards. Plain only.
--
	function string.rfind(s, pattern, start)
		local i = start
		local pi = #pattern
		while i > 0 do
			if s[i] == pattern[pi] then
				pi = pi - 1
				if pi == 0 then
					return i
				end
			else
				pi = #pattern
			end
			i = i - 1
		end
		return nil
	end

--
-- Returns true if the string has a match for the plain specified pattern
--
	function string.contains(str, match)
		return string.find(str, match, 1, true) ~= nil 
	end

--
-- string.gsub without pattern matching
--

	function string.replace_test(str, searchStr, replaceStr)
		local rnew = string.replace_new(str, searchStr, replaceStr)
		local rold = string.replace_old(str, searchStr, replaceStr)
		
		if rnew ~= rold then	
			error('"Replace mismatch, "'..str..'", "'..searchStr..'", "'..replaceStr..'"')
		end
		return rnew
	end
	
	function string.replace(str, searchStr, replaceStr)
		local i = 1
		if not str then
			return ''
		end 
		if #searchStr == 0 then
			return str
		end
		local newstr = {}
		while( i <= #str ) do
			local findIdx = string.find(str, searchStr, i, true)
			if findIdx then
				newstr[#newstr+1] = str:sub(i,findIdx-1) 
				newstr[#newstr+1] = replaceStr 
				i = findIdx + #searchStr
			else
				break
			end
		end
		newstr[#newstr+1] = str:sub(i, #str)
		return table.concat(newstr)
	end
	
	function string.replace_old(str, searchStr, replaceStr)
		local i = 1
		if not str then
			return ''
		end 
		if #searchStr == 0 then
			return str
		end
		while( i <= #str ) do
			local findIdx = string.find(str, searchStr, i, true)
			if findIdx then
				str = str:sub(1,findIdx-1) .. replaceStr .. str:sub(findIdx + #searchStr)
				i = findIdx + #replaceStr
			else
				break
			end
		end
		return str
	end
		
	--[[
	function string.testReplace()
		local count = 1000
		local randomStrings = {}
		
		for i = 1,count do
			local str = tostring(math.random(1000000,9999999))
			if math.mod(i, 5) == 0 then	
				table.insert(randomStrings, randomStrings[1])
			else 
				table.insert(randomStrings, str)
			end
		end
		local searchStr = randomStrings[1] 
		local bigStr = table.concat(randomStrings)
		
		local tmr = timer.start("Replace test")
		for i = 1,1000 do
			local newstr = string.replace(bigStr, searchStr, "blah")
		end
		timer.stop(tmr)
	end
	]]
	
--
-- Replace whole word. Match only if followed by whitespace or EOF.
--

	function string.replaceword(str, searchStr, replaceStr)
		local i = 1
		if not str then
			return ''
		end 
		if #searchStr == 0 then
			return str
		end
		local newstr = {}
		while( i <= #str ) do
			local findIdx = string.find(str, searchStr, i, true)
			if findIdx then
				local last = findIdx + #searchStr
				local c = str:sub(last,last)
				if c == ' ' or c == '' or c == '\t' or c == '\n' or c == '\"' or c == "'" then
					newstr[#newstr+1] = str:sub(i,findIdx-1) 
					newstr[#newstr+1] = replaceStr
				else
					newstr[#newstr+1] = str:sub(i,last)
				end
				i = last
			else
				break
			end
		end
		if i == 1 then
			return str
		end
		newstr[#newstr+1] = str:sub(i, #str)
		return table.concat(newstr)
	end	
--
-- Remove repeated whitespace
--
	function string.trimWhitespace(str)
		local rv = {}
		for v in str:gmatch('[^\t ]+') do
			table.insert(rv, v)
		end
		return table.concat(rv, ' ') 
	end
	