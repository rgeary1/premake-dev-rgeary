--
--  New way to read/bake configurations
--

premake.keyedblocks = {}
local keyedblocks = premake.keyedblocks

local globalContainer = premake5.globalContainer
local project = premake5.project
local oven = premake5.oven

--
-- Expand any 'a or b' statements, and sort each term within the term set 
function keyedblocks.expandTerms(terms)
	if type(terms) == 'string' then
		terms = { terms }
	end

	-- Return { { input, perm[1] } } if #perms == 1
	--   or { { input, perm[1] }, { input, perm[2] } ... } if #perms > 1 
	function permutations(input, perms)
		local rv = {}
		for _,v in ipairs(input) do
			for _,p in ipairs(perms) do
				
				-- 'not' terms, replace with '-' for sorting
				if p:startswith('not ') then
					p = '-'..p:sub(5)
				end
				p = p:lower()
				
				-- create permutations
				local r = table.shallowcopy(v)
				table.insert(r, p)
				table.insert(rv, r)					
			end
		end
		return rv
	end
	
	local expTerms = { {} }
	for _,unexpTerm in ipairs(terms) do
		local ts = unexpTerm:explode(' or ', true)
		expTerms = permutations(expTerms, ts)
	end
	
	-- have a well defined order for the terms
	for _,terms in ipairs(expTerms) do
		table.sort(terms)
	end
	
	return expTerms
end

-- Generate the keyedblocks from the blocks. obj can be sln, prj or cfg
function keyedblocks.bake(obj, isUsage, usesIncluded)
	local kbBase = {}
	
	-- Prevent infinite recursion
	usesIncluded = usesIncluded or {}
	if usesIncluded[obj] then
		return obj
	end
	usesIncluded[obj] = obj
	
	-- No need to bake twice
	if obj.keyedblocks then
		return obj
	end
	
timer.start('keyedblocks.bake')
	for _,block in ipairs(obj.blocks or {}) do
		local terms = block.keywords
		
		-- expand ors. { "debug, "a or b" } turns in to { { "debug", "a" }, { "debug", "b" } }
		local expTerms = keyedblocks.expandTerms(terms)

		for _,terms in ipairs(expTerms) do
			-- Iterate over 'and' terms to create a nested block
			local kb = kbBase
			for _,term in ipairs(terms) do
				
				-- case insensitive
				term = term:lower()
				
				-- 'not' is a separate category
				if term:startswith('-') then
					kb['not'] = kb['not'] or {}
					kb = kb['not']
					term = term:sub(2)
				end
				
				-- Insert term in to keyedblocks
				kb[term] = kb[term] or {}
				
				-- recurse kb
				kb = kb[term]
			end
			
			-- insert the field values in to the keyed block
			local ignoreField = { terms = 1, keywords = 1, removes = 1 }
			for k,v in pairs(block) do
				if (not ignoreField[k]) and v and (#v>0 or not table.isempty(v)) then
					local field = premake.fields[k]
					if not field then
						error('Unknown field "'..k..'"')
					end
					local fieldKind = field.kind
					if (not isUsage) or (field.usagefield) then
						
						-- Recurse on nested 'uses' statements
						if k == 'uses' then
							kb.__uses = kb.__uses or {}
							
							for _,useProjName in ipairs(v) do
								local usageProj = project.getUsageProject(useProjName)
								if not usageProj then
									error('Could not find usage project '..tostring(useProjName))
								end
								kb.__uses[useProjName] = usageProj
								--[[
								keyedblocks.bake(usageProj, isUsage, usesIncluded)
								if not usageProj.keyedblocks then
									print('Warning : Usage '..useProjName..' contains a cyclic dependency on '..tostring(obj.name)..'. Processing may not be complete.')
								end  
								-- Merge with the other usage
								keyedblocks.merge(kb, usageProj.keyedblocks)
								]]
							end
														
						else
							-- Include the key/value
							kb.values = kb.values or {}
							oven.mergevalue(kb.values, k, fieldKind, v)
						end
					end
				end
			end -- each block

			if block.removes then
				for k,v in pairs(block.removes) do
					if (not ignoreField[k]) and v and (not table.isempty(v)) then
						kb.removes = kb.removes or {}
						oven.mergefield(kb.removes, k, v)
					end
				end
			end -- block.removes
			
		end -- expTerms
		
	end
	obj.keyedblocks = kbBase
	
timer.stop(tmr)
	
	return obj
end

function keyedblocks.merge(dest, src)
	if not src then
		return
	end
	if src.values then
		for k,v in ipairs(src.values) do
			oven.mergefield(dest.values, k, v)
		end
	end
	
	for k,v in pairs(src) do
		if k ~= 'values' and k ~= 'uses' then
			dest[k] = dest[k] or {} 
			keyedblocks.merge(dest[k], v)
		end
	end
end


-- eg. keyedblocks.getfield(cfg, {"debug"}, 'system')
function keyedblocks.getfield(obj, keywords, fieldName, dest)
	local rv = nil
	local removes = nil
	if not obj.keyedblocks then
		return nil
	end
	local kbBase = obj.keyedblocks
	
	timer.start('keyedblocks.getfield')
	local terms = {}
	function getKeywordSet(ws)
		for _,v in ipairs(ws) do
			v = v:lower()
			if v:find('not ') then
				error("keyword 'not' not supported as a filter")
			end
			if v:find(' or ') then
				error("keyword 'or' not supported as a filter")
			end
			terms[v] = 1
		end
	end
	getKeywordSet(keywords)
	
	-- set of .values structures which apply to 'keywords'
	local foundValues = {}
	-- set of .removes structures which apply to 'keywords'
	local foundRemoves = {}
	
	-- Find the .values & .removes structures which apply to 'keywords'
	local recurse = {}
	local function findValues(kb)
		if not kb or recurse[kb] then 
			return 
		end
		recurse[kb] = kb
		if kb.values then
			foundValues[kb.values] = kb.values
		end
		if kb.removes then
			foundRemoves[kb.removes] = kb.removes
		end
		
		for term,_ in pairs(terms) do
	
			-- check the 'not' terms
			local kbNot = kb['not']
			if kbNot then
				for notTerm,notTermKB in pairs(kbNot) do
					if not terms[notTerm] then
						-- recurse
						findValues(notTermKB)
					end
				end
			end
				
			-- check if this combination of terms has been specified
			if kb[term] then
				findValues(kb[term])
			end
			
			if kb.__uses then
				for useProjName,useProj in pairs(kb.__uses) do
					globalContainer.bakeUsageProject(useProj)
					findValues(useProj.keyedblocks)
				end
			end
		end
	end -- findValues
	
	findValues(kbBase)
	
	-- Filter values structures
	local rv = dest or {}
	for _,values in pairs(foundValues) do
		
		if not fieldName then
		
			for k,v in pairs(values) do
				oven.mergefield(rv, k, v)
			end
		
		elseif values[fieldName] then
			oven.mergefield(rv, fieldName, values[fieldName])
		end
	end
	
	-- Remove values
	for _,values in pairs(foundRemoves) do
		if not fieldName then
			for k,v in pairs(values) do
				oven.remove(rv, k, v)
			end
		elseif values[fieldName] then
			oven.remove(rv, fieldName, values[fieldName])
		end
	end
	
	timer.stop(tmr)	
	return iif(#foundValues == 0, nil, rv)
end

-- return or create the nested keyedblock for the given term
function keyedblocks.createblock(kb, terms)
	for _,v in ipairs(terms) do
		v = v:lower()
		if v:find('not ') then
			error("keyword 'not' not supported as a filter")
		end
		if v:find(' or ') then
			error("keyword 'or' not supported as a filter")
		end
		
		kb[v] = kb[v] or {}
		kb = kb[v]
	end
	
	return kb
end

--
-- Testing
--

function keyedblocks.test()
	
	global()
	usage "testRecursion"
		uses "testBase"
		define "recurse"
	usage "testBase"
		uses "testRecursion"
		define "recurseBase"
		configuration "debug"
			includedir "dir/testBase"
	usage "testUsage"
		uses "testBase"
		configuration "debug"
			includedir "dir/debug"
		configuration "release"
			includedir "dir/release"
		configuration "not debug"
			includedir "dir/notdebug"
		configuration "debug or release"
			includedir "dir/debugorrelease"
			buildoptions "-DEBUGORREL"
	global()
	
	local gc = premake5.globalContainer
	local Print = premake.actions.Print
	local testUsage = keyedblocks.bake(gc.allUsage["testUsage"])
	local testRecursion = keyedblocks.bake(gc.allUsage["testRecursion"])
	local testBase = keyedblocks.bake(gc.allUsage["testBase"])
	local xU = keyedblocks.getfield(testUsage, { 'release', 'debug' }, nil)
	local xB = keyedblocks.getfield(testBase, { 'release', 'debug' }, nil)
	local xR = keyedblocks.getfield(testRecursion, { 'release', 'debug' }, nil)
	
	Print.print('kbU = ', xU)
	Print.print('kbB = ', xB)
	Print.print('kbR = ', xR)
	print('')	
end
