--
--  New way to read/bake configurations
--

premake.keyedblocks = {}
local keyedblocks = premake.keyedblocks

local globalContainer = premake5.globalContainer
local targets = premake5.targets
local project = premake5.project
local oven = premake5.oven
local config = premake5.config

keyedblocks.active = {}		 -- for logging

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
function keyedblocks.create(obj, parent)
	local kbBase = {}
	
	-- No need to create twice
	if obj.keyedblocks then
		return obj
	end
	
	if parent == obj then
		parent = nil
	end
	
	local namespaces = obj.namespaces
	
	local tmr = timer.start('keyedblocks.create')
	for _,block in ipairs(obj.blocks or {}) do
		local terms = block.terms
		
		-- expand ors. { "debug, "a or b" } turns in to { { "debug", "a" }, { "debug", "b" } }
		local expTerms = keyedblocks.expandTerms(terms)

		for _,terms in ipairs(expTerms) do
			-- Iterate over 'and' terms to create a nested block
			local kb = kbBase
			for _,term in ipairs(terms) do
				
				-- case insensitive
				term = term:lower()
				
				if premake.fieldAliases[term] then
					term = premake.fieldAliases[term]
				end
				
				-- if it's of the form key=value, match on the value. This allows you to match on flag values.
				if term:contains('=') then
					term = term:match(".*=(.*)")
				end

				-- 'not' is a separate category
				local kbcfg
				if term:startswith('-') then
					kb.__notconfig = kb.__notconfig or {}
					kbcfg = kb.__notconfig
					term = term:sub(2)
				else
					kb.__config = kb.__config or {}
					kbcfg = kb.__config
				end

				-- TODO : Separate category for wildcard configuration strings

				-- Insert term in to keyedblocks
				kbcfg[term] = kbcfg[term] or {}
				if kb.__name then
					kbcfg[term].__name = term ..':'.. kb.__name
				end
				
				-- recurse kb
				kb = kbcfg[term]
			end

			-- insert the field values in to the keyed block
			local ignoreField = { terms = 1, keywords = 1, removes = 1 }
			for k,v in pairs(block) do
				if (not ignoreField[k]) and v and (#v>0 or not table.isempty(v)) then
					if premake.fieldAliases[v] then
						v = premake.fieldAliases[v]
					end

					-- Include the key/value
					oven.mergefield(kb, k, v)
				end
			end -- each block

			if block.removes then
				for k,v in pairs(block.removes) do
					if (not ignoreField[k]) and v and (not table.isempty(v)) then
						kb.__removes = kb.__removes or {}
						oven.mergefield(kb.__removes, k, v)
					end
				end
			end -- block.removes

			keyedblocks.resolveUses(kb, obj)

		end -- expTerms

	end

	if parent then
		keyedblocks.create(parent)
		kbBase.__parent = parent
	end
	kbBase.__name = obj.name

	obj.keyedblocks = kbBase

	timer.stop(tmr)

	return obj
end

function keyedblocks.resolveUses(kb, obj)
	if kb.uses or kb.alwaysuses then
		kb.__uses = kb.__uses or {}

		local uses = kb.uses or kb.alwaysuses
		if kb.alwaysuses and kb.uses then
			uses = {}
			for _,v in Seq:ipairs(kb.uses):iconcat(kb.alwaysuses):each() do
				table.insert(uses, v)
			end
		end

		for _,useProjName in ipairs(uses) do
			
			local usevariant = {}
			for v in useProjName:gmatch(':([^:]*)') do
				table.insert( usevariant, v )
			end
			if #usevariant == 0 then usevariant = nil end
			useProjName = useProjName:match("[^:]*")
			
			local useProj = kb.__uses[useProjName]

			if type(useProj) ~= 'table' then
				local suggestions
				useProj, suggestions = keyedblocks.getUsage(useProjName, obj.namespaces)
				if not useProj then
					local errMsg = '\nCould not find usage "'..tostring(useProjName)..'" ' ..
					"for "..ptype(obj).." "..tostring(obj.name) ..' at ' .. tostring(obj.basedir)
					if obj.namespaces then
						errMsg = errMsg .. '\n' .. "Current namespaces : "..mkstring(obj.namespaces)
					end
					if suggestions then
						errMsg = errMsg .. '"\n' .. suggestions
					end
					local debug = debuggerIsAttached
					if debug then
						useProj, suggestions = keyedblocks.getUsage(useProjName, obj.namespaces)
					end
					printAlways(errMsg)
					if _ACTION ~= 'print' then
						os.exit(1)
					end
				end
				kb.__uses[useProjName] = { prj = useProj, usevariant = usevariant }
			end
		end
	end
end

function keyedblocks.getDependencies(prjOrSln, deps, includeUses)
	deps = deps or {}
	local kb = prjOrSln.keyedblocks
	if not kb then return {} end

	if kb.__parent then
		keyedblocks.getDependencies(kb.__parent, deps)
	end
	if kb.__uses then
		for useProjName, p in pairs(kb.__uses or {}) do
			deps[#deps+1] = p.prj
			if includeUses then
				keyedblocks.getDependencies(p.prj, deps)
			end
		end
	end
	for term,obj in pairs(kb.__config or {}) do
		keyedblocks.getDependencies(obj, deps)
	end
	for filterStr,obj in pairs(kb.__filter or {}) do
		keyedblocks.getDependencies(obj, deps)
	end	
	
	return deps
end

function keyedblocks.getUsage(name, namespaces)
	local suggestions, suggestionStr

	local usage = project.getUsageProject(name, namespaces)

	if not usage then
		suggestions, suggestionStr = project.getProjectNameSuggestions(name, namespaces)
	end

	return usage, suggestionStr
end

function keyedblocks.bake(usage, buildVariant)
	if not table.isempty(buildVariant) then
		project.addconfig(usage, buildVariant)
	end
	if not usage.keyedblocks then
		if ptype(usage) == 'project' then
			globalContainer.bakeUsageProject(usage)
		else
			keyedblocks.create(usage)
		end
	end
end

function keyedblocks.merge(dest, src)
	if not src then
		return
	end
	for k,v in ipairs(src) do
		oven.mergefield(dest, k, v)
	end
	
	for k,v in pairs(src) do
		--if k ~= '__values' and k ~= 'uses' then
			dest[k] = dest[k] or {} 
			keyedblocks.merge(dest[k], v)
		--end
	end
end

--
-- Given a build variant, this returns the keyword filter
--
function keyedblocks.getfilter(obj, buildVariant)
	local tmr = timer.start('keyedblocks.getfilter')

	-- check if we've already found the filter
	local kb = obj.keyedblocks
	
	-- Start with the buildVariant keywords
	local filter = table.shallowcopy(buildVariant)
	
	-- Set some defaults
	local defaultArchitecture = iif( os.is64bit(), "x64", nil )
	
	filter.buildcfg		= filter.buildcfg or 'All'
	filter.platform		= filter.platform or nil
	filter.architecture = filter.architecture or defaultArchitecture
	filter.action 		= filter.action or _ACTION
	filter.system		= filter.system or premake.action.current().os or os.get()
	
	-- Apply usesconfig, repeat until the filter is stable
	local loop = 0
	local loopMax = 10
	local origFilter
	local filterList = {}
	
	repeat
		loop = loop + 1
		
		origFilter = table.shallowcopy(filter)
		table.insert(filterList, origFilter)
		local usesconfig = keyedblocks.getconfig(obj, filter, "usesconfig", {})
		
		-- usesconfig adds/mutates the filter
		if usesconfig then
			local filter2 = {}
			for k,v in Seq:new(filter):concat(usesconfig):each() do
				-- set the filter on the key, match blocks on the value
				if type(k) ~= 'number' then
					if k:contains('=') then
						k = k:match("[^=]*"):lower()
					end
					filter2[k:lower()] = v:lower()
				end
			end
			filter = filter2
		end
		
		local filterUnchanged = table.equals(filter, origFilter)
		if filterUnchanged then
			break
		end
	until( loop > loopMax )
	if loop >= loopMax then
		print("Maximum recursion reached, configuration filter is oscillating : ")
		for _,f in ipairs(filterList) do
			f = mkstring(f):split(' ')
			table.sort(f) 
			print(mkstring(f))
		end
		error("Please change your configuration, you've defined an unstable loop")
	end
	
	timer.stop(tmr)

	return filter
end

--
-- Returns a full config from the keyedblocks
--   eg. keyedblocks.getconfig(cfg, filter, 'kind', {})
-- May have to create the usage & bake the project if it's not already created 
--
function keyedblocks.getconfig(obj, filter, fieldName, dest)
	local rv = dest
	if not obj.keyedblocks then
		return nil
	end

	local tmr = timer.start('keyedblocks.getconfig')
	local ignore = toSet({ '__config', '__filter', '__name', '__parent', '__uses', '__cache', '__usesconfig' })
	local kbBase = obj.keyedblocks
	
	table.insert( keyedblocks.active, obj )

	local buildVariant = config.getBuildVariant(filter)
	local buildVariantName = config.getBuildName(buildVariant)
	local filterStr = getValues(filter)
	table.sort(filterStr)
	filterStr = table.concat(filterStr, ' ')..':'..tostring(fieldName)

	-- Find the values & .removes structures which apply to 'keywords'
	local accessedBlocks = {}
	local foundBlocks = {}
	foundBlocks.cfgs = {}
	-- Set of all separate configurations

	local function findBlocks(kb)
	
		if not kb or table.isempty(kb) then
			return nil
		elseif accessedBlocks[kb] then
			return nil
		end
		accessedBlocks[kb] = kb
		
		-- Apply parent before block
		if kb.__parent then
			keyedblocks.bake(kb.__parent, buildVariant)
			findBlocks(kb.__parent.keyedblocks)
		end

		-- New : Apply usages before block, so the block can override them
		-- Old : Apply usages after block
		--if kb.__uses and fieldName ~= 'usesconfig' then		-- Removed optimization as usevariant can exist in a usage() section?
		if kb.__uses then
			for useProjName, p in pairs(kb.__uses) do
			
				local oldFilter = filter
				local oldBuildVariant = buildVariant
				local oldBuildVariantName = buildVariantName
				if p.usevariant then
					-- Add the build feature to the target project's config list
					filter = table.shallowcopy(filter)
					buildVariant = table.shallowcopy(buildVariant)
					for _,variant in ipairs(p.usevariant) do
						local k,v = config.getkeyvalue(variant) 
						buildVariant[k] = v
						filter[k] = v
					end
					buildVariantName = config.getBuildName(buildVariant)
					
					-- evaluate the usage requirements of the target project, with the feature(s) enabled
					local newCfg = project.addconfig(p.prj, buildVariant)
					buildVariant = newCfg.buildVariant
					filter = newCfg.filter
					findBlocks(p.prj.keyedblocks)
					
				elseif p.prj then
					keyedblocks.bake(p.prj, buildVariant)
					findBlocks(p.prj.keyedblocks)
				end
				filter = oldFilter
				buildVariant = oldBuildVariant
				buildVariantName = oldBuildVariantName
				
			end
		end

		-- Found some values to add/remove
		for k,v in pairs(kb) do
			if not ignore[k] then
				table.insert( foundBlocks, kb )
				break
			end
		end

		-- Iterate through the filters and apply any blocks that match
		if kb.__config then
			for _,term in pairs(filter) do
				-- check if this combination of terms has been specified
				if kb.__config[term] then
					foundBlocks.cfgs[term] = term
					findBlocks(kb.__config[term], filter)
				end
			end
		end

		-- Iterate through the exact filters and apply any blocks that match
		if kb.__filter then
			-- check if this combination of terms has been specified
			--[[local parts = buildVariantName:split(' ')
			for _,v in ipairs(parts) do
				for f,_ in pairs(kb.__filter) do
					if f:contains(v) then 
						foundBlocks.cfgs[buildVariantName] = buildVariantName
						findBlocks(kb.__filter[f], filter)
					end
				end
			end]]
			if kb.__filter[buildVariantName] then
				for _,v in ipairs(buildVariant) do
					foundBlocks.cfgs[v] = v
				end
				findBlocks(kb.__filter[buildVariantName], filter)
			end
		end

		-- check the 'not' terms
		if kb.__notconfig then
			for notTerm,notTermKB in pairs(kb.__notconfig) do
				local match = false
				for _,term in pairs(filter) do
					if term == notTerm then
						foundBlocks.cfgs[term] = term
						match = true
						break
					end
				end
				if not match then
					-- recurse
					findBlocks(notTermKB, filter)
				end
			end
		end

	end -- findBlocks
	
	kbBase.__cache = kbBase.__cache or {}
	if kbBase.__cache[filterStr] then
		foundBlocks = kbBase.__cache[filterStr]
	else
		findBlocks(kbBase, filter)
	end
	kbBase.__cache[filterStr] = foundBlocks

	--printDebug("getconfig "..obj.name.." size "..#foundBlocks)

	if not fieldName then
		rv.filter = table.shallowcopy(filter)
	end

	-- Filter values structures
	local isEmpty = table.isempty(foundBlocks)
	--insertBlockList(rv, foundBlocks)

	local removes = {}
	for _,block in ipairs(foundBlocks) do
		if not fieldName then
			for k,v in pairs(block) do
				if ignore[k] then
					-- do nothing
				elseif k == '__removes' then
					table.insert(removes, v)
				else
					oven.mergefield(rv, k, v)
				end
			end
		else
			oven.mergefield(rv, fieldName, block[fieldName])
			if block.__removes then
				table.insert(removes, block.__removes)
			end
		end
	end

	-- Remove values
	for _,removeBlock in ipairs(removes) do
		if not fieldName then
			for k,v in pairs(removeBlock) do
				oven.removefromfield(rv[k], v, k)
			end
		elseif removes[fieldName] then
			for k,v in pairs(removeBlock) do
				oven.remove(rv, fieldName, removes[fieldName])
			end
		end
	end
	
	if not fieldName then
	
		-- Add the build variant to the output
		-- but filter out any build variants which we didn't use
		rv.buildVariant = {}
		if filter.buildcfg == 'all' then
			-- no variants for "All"
			rv.buildVariant = { buildcfg = filter.buildcfg }
		else
			for k,v in pairs(config.getBuildVariant(filter)) do
				if k == 'buildcfg' or k == 'platform' or foundBlocks.cfgs[v] then
					rv.buildVariant[k] = v
				end
			end
		end
		
		if rv.compiledepends then
			for _,v in ipairs(rv.compiledepends) do
				local prj = project.getRealProject(v)
				project.addconfig(prj, rv.buildVariant)
			end
		end
	end
	
	if rv.alwaysdefines then
		oven.mergefield(rv, 'defines', rv.alwaysdefines) 
	end	
	if rv.alwaysincludedir then
		oven.mergefield(rv, 'includedirs', rv.alwaysincludedir) 
	end	
	
	table.remove( keyedblocks.active )
			
	timer.stop(tmr)
	
	if isEmpty then
		return nil
	elseif fieldName then
		return rv[fieldName]
	else
		return rv
	end
end

function keyedblocks.bakeUsesConfig(kb, accessed)
	if accessed[kb] then return {} end
	accessed[kb] = true
	
	if kb.__usesconfig then
		return kb.__usesconfig
	end
	
	local uc = {}
	-- parent
	if kb.__parent then
		table.insertflat( uc, keyedblocks.bakeUsesConfig(kb.__parent, accessed) )
	end
	
	-- uses
	for useProjName, p in pairs(kb.__uses or {}) do

		if not p.keyedblocks then
			if ptype(p) == 'project' then
				globalContainer.bakeUsageProject(p)
			else
				keyedblocks.create(usage)
			end
		end
		
		table.insertflat( uc, keyedblocks.bakeUsesConfig(p, accessed) )
	end
	
	-- returns a list of functions which you call with the filter to return the usesconfigs
	function genFindUsesConfig(kb2)
		local rv = {}
		if kb2.usesconfig then
			local func = function(filter)
				return kb2.usesconfig
			end
			table.insert( rv, func )
		end
		for term,kbTerm in pairs(kb2.__config or {}) do
			for _,vfn in ipairs(genFindUsesConfig(kbTerm)) do
				local func = function(filter) 
					if filter[term] then
						return vfn()
					end
				end
				table.insert( rv, func )
			end
		end
		for term,kbTerm in pairs(kb2.__notconfig or {}) do
			for _,vfn in ipairs(genFindUsesConfig(kbTerm)) do
				local func = function(filter)
					if not filter[term] then
						return vfn()
					end
				end
				table.insert( rv, func )
			end
		end
		return rv
	end
	local uc = genFindUsesConfig(kb)

	kb.__usesconfig = uc
	return uc		
end

-- return or create the nested keyedblock for the given term
function keyedblocks.createblock(kb, buildVariant)
	
	local buildVariantName = config.getBuildName(buildVariant)
	kb.__filter = kb.__filter or {}
	
	if kb.__filter[buildVariantName] then
		return kb.__filter[buildVariantName], true
	else
		kb.__filter[buildVariantName] = {}
		return kb.__filter[buildVariantName], false
	end
end

--
-- Testing
--
--[[
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
	local testUsage = keyedblocks.create(targets.allUsage["testUsage"])
	local testRecursion = keyedblocks.create(targets.allUsage["testRecursion"])
	local testBase = keyedblocks.create(targets.allUsage["testBase"])
	local xU = keyedblocks.getconfig(testUsage, { 'release', 'debug' }, nil)
	local xB = keyedblocks.getconfig(testBase, { 'release', 'debug' }, nil)
	local xR = keyedblocks.getconfig(testRecursion, { 'release', 'debug' }, nil)
	
	Print.print('kbU = ', xU)
	Print.print('kbB = ', xB)
	Print.print('kbR = ', xR)
	print('')	
end
]]