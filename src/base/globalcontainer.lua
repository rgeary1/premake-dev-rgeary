--
-- Container for all projects, and global-level solution configurations
--

	premake5.globalContainer = premake5.globalContainer or {}
	local globalContainer = premake5.globalContainer
	local project 	= premake5.project
	local oven 		= premake5.oven
	local solution	= premake.solution  
	local keyedblocks = premake.keyedblocks  
	local targets = premake5.targets
	local config = premake5.config
	
	targets.requested = {}		-- explicitly requested list of prj or sln
	-- implicit & explicitly requested
	targets.prjToBuild = {}		-- prjToBuild[prjName] = prj
	targets.slnToBuild = {}		-- slnToBuild[slnName] = sln
	-- Keep track of all dependent projects
	targets.prjToGenerate = {}	-- prjToGenerate[prjName] = prj
	-- set of projectset names to include. nil = include everything
	targets.includeProjectSets = nil
	targets.prjNameToSet = {}	-- prjNameToSet[prjFullname] = set of projectsets containing prj
	targets.dirToPrjs = {}		-- dirToPrjs[fullpath] = list of prjs
	targets.releasedir = {}
	
local function matchdir(prjSln) 
	return true 
end
	
--
-- Apply any command line target filters
--
	function globalContainer.filterTargets()
	
		for _,prj in pairs(targets.allReal) do
			local dir = prj.basedir
			targets.dirToPrjs[dir] = targets.dirToPrjs[dir] or {}
			table.insert( targets.dirToPrjs[dir], prj )
		end
	
		-- Read --projectset= option
		if _OPTIONS['projectset'] then
			targets.includeProjectSets = {}
			local prjsets = _OPTIONS['projectset']:split(',')
			for _,p in ipairs(prjsets) do
				targets.includeProjectSets[p] = p
			end
		end
	
		-- Allow action to overload default command line filter behaviour	
		local action = premake.action.current()
		if action and action.filterTargets then
			action.filterTargets()
			
		else

			if _OPTIONS['defaultbuilddir'] then
				local dir = path.getabsolute(_OPTIONS['defaultbuilddir'])
				local dirS = dir..'/'
				matchdir = function(prjSln)
					if prjSln.basedir == dir or prjSln.basedir:startswith(dirS) then
						return true
					end
					return false
				end
			end
					
			-- Read command line args for specified targets
			for _,v in ipairs(_ARGS) do
				if v:endswith('/') then v = v:sub(1,#v-1) end
				 
				if not premake.action.get(v) then
	
					globalContainer.findBuildTarget(v)
				end
			end
	
			local visiblePrjsBySet = {}
			-- If nothing is specified :
			if table.isempty(targets.prjToBuild) and table.isempty(targets.slnToBuild) then
				
				-- Build default premake file projects
				
				local foundSln = false
				for _,sln in pairs(targets.solution) do
					if (not targets.slnToBuild[sln.name]) and matchdir(sln) then
						printDebug("Build Solution : "..sln.name)
						targets.slnToBuild[sln.name] = sln
						foundSln = true
					end
				end
				for _,prj in pairs(targets.allReal) do
					if (not targets.prjToBuild[prj.name]) and matchdir(prj) then

						-- keep track of what is visible, for the error message
						local prjSets = targets.prjNameToSet[prj.fullname] or toSet({ 'all' })
						for prjSetName,_ in pairs(prjSets) do
						    visiblePrjsBySet[prjSetName] = visiblePrjsBySet[prjSetName] or {}
							table.insert( visiblePrjsBySet[prjSetName], prj.name )
						end
						
						-- add the project to the build
						if project.inProjectSet(prj, targets.includeProjectSets) then
							if not foundSln then
								printDebug("Build Project : "..prj.name)
							end
							targets.prjToBuild[prj.name] = prj
						end
					end 
				end
			end
			
			-- ... or explain why we have nothing to build
			if table.isempty(targets.prjToBuild) then
				globalContainer.onNoProjects(visiblePrjsBySet)
				os.exit(1)
			end
		end
		
		--printDebug("targets.requested : "..table.concat(getKeys(targets.requested), ' '))		
		--printDebug("targets.slnToBuild : "..table.concat(getKeys(targets.slnToBuild), ' '))		
		--printDebug("targets.prjToBuild : "..table.concat(getKeys(targets.prjToBuild), ' '))		
	end
	
	function globalContainer.onNoProjects(visiblePrjsBySet)
		local msg = "Warning : No projects found"
		if targets.includeProjectSets then
			prjSets = table.concat(getKeys(targets.includeProjectSets), ",")
			msg = msg .. " in projectset \""..prjSets.."\""
		end
		if _OPTIONS['defaultbuilddir'] then
			local dir = path.getrelative(repoRoot, _OPTIONS['defaultbuilddir'])
			msg = msg .. " under directory "..dir
		end
		print(msg)
		
		if not table.isempty(visiblePrjsBySet) then
			print("Visible projectsets, build these with --projectset=X :")
			for prjSetName,prjNameList in pairs(visiblePrjsBySet) do
				local prjNames = table.concat(prjNameList, ",")
				if #prjNames > 80 then prjNames = prjNames:sub(77)..'...' end
				print("  "..prjSetName.." : "..prjNames)
			end
		end
	end

	function globalContainer.findBuildTarget(v)
		local found = false
	
		-- Check if any command line arguments are solutions
		for _,sln in pairs(targets.solution) do
			if sln.name == v or sln.name:contains(v..'/') or sln.name:endswith('/'..v) then
				-- Add solution to the build
				targets.slnToBuild[sln.name] = sln
				for _,prj in ipairs(sln.projects) do
					if (not prj.isUsage) and project.inProjectSet(prj, targets.includeProjectSets) then
						targets.prjToBuild[prj.name] = prj
					end
				end
				targets.requested[#targets.requested+1] = sln
				found = true
			end
		end
		
		-- Check if any command line arguments are projects
		local prj = project.getRealProject(v) or project.getUsageProject(v)
		if prj then
			if not prj.isUsage then
				targets.prjToBuild[prj.name] = prj
			end
			targets.requested[#targets.requested+1] = prj
			found = true
		end

		if not found and _OPTIONS['defaultbuilddir'] then
			-- search for v as a project name under default build dir
			for _,prj in Seq:new(targets.allReal):concat(targets.allUsages):each() do
				if matchdir(prj) and prj.shortname == v then
					found = true
					-- Add project to the build
					if not prj.isUsage then
						targets.prjToBuild[prj.name] = prj
					end
					table.insert( targets.requested, prj )
					print(" "..prj.name)
				end
			end
		end

		if not found then
			-- search for v as a project name
			for _,prj in Seq:new(targets.allReal):concat(targets.allUsages):each() do
				if prj.shortname == v then
					found = true
					-- Add project to the build
					if not prj.isUsage then
						targets.prjToBuild[prj.name] = prj
					end
					table.insert( targets.requested, prj )
					print(" "..prj.name)
				end
			end
		end
		
		if not found then
			-- search for v as a project name fragment
			print("Could not find project \""..v.."\", looking for matches...")
			for _,prj in Seq:new(targets.allReal):concat(targets.allUsages):each() do
				if prj.name:contains(v) then
					-- Add solution to the build
					if not prj.isUsage then
						targets.prjToBuild[prj.name] = prj
					end
					table.insert( targets.requested, prj )
					print(" "..prj.name)
				end
			end
		end
	end
	
--
-- Bake all the projects
--
	function globalContainer.bakeall()
	
		-- Message
		if _ACTION ~= 'clean' then
			local cfgNameList = Seq:new(targets.solution):select('configurations'):flatten():unique()
			if cfgNameList:count() == 0 then
				error("No configurations to build")
			elseif cfgNameList:count() == 1 then
				print("Generating configuration '"..cfgNameList:first().."' ...")
			else
				print("Generating configurations : "..cfgNameList:mkstring(', ').." ...")
			end
		end
		
		-- Test for invalid aliases
		for aliasName,fullPrjName in pairs(targets.aliases) do
			local prj = targets.allReal[fullPrjName] or targets.allUsage[fullPrjName]
			if not prj then
				print("Warning : Could not find target \""..fullPrjName.."\" for alias \""..aliasName.."\"")
			end
		end
		
		-- Filter targets to bake
		globalContainer.filterTargets()
		
		local toBake = table.shallowcopy(targets.prjToBuild)
				
		-- Bake all real projects, but don't resolve usages		
		local tmr = timer.start('Bake projects')
		for prjName,prj in pairs(toBake) do
			project.bake(prj)

			-- Add default configurations
						
			local buildVariants = project.getBuildVariants(prj)
			for _,bv in ipairs(buildVariants) do
				project.addconfig(prj, bv)
			end
			
		end
		timer.stop(tmr)
		
		-- Assign unique object directories to every project configurations
		-- Note : objdir & targetdir can't be inherited from a usage for ordering reasons 
		--globalContainer.bakeobjdirs(toBake)
		
		-- expand all tokens (must come after baking objdirs)
		--[[
		for i,prj in pairs(toBake) do
			oven.expandtokens(prj, "project")
			for cfg in project.eachconfig(prj) do
				oven.expandtokens(cfg, "config")
			end
		end]]
		
		-- Bake all solutions
		solution.bakeall()
	end
	
	-- May recurse
	function globalContainer.bakeUsageProject(usageProj)
	
		-- Look recursively at the uses statements in each project and add usage project defaults for them  
		if usageProj.hasBakedUsage then
			return true
		end
		usageProj.hasBakedUsage = true
		
		local parent
		if ptype(usageProj) == 'project' and usageProj.solution then
			parent = targets.allUsage[usageProj.solution.name]
		end
		keyedblocks.create(usageProj, parent)

		local realProj = targets.allReal[usageProj.name]
		if realProj then
		
			-- Bake the real project (RP) first, and apply RP's usages to RP
			project.bake(realProj)
			
			-- Set up the usage target defaults from RP
			for _,cfg in pairs(realProj.configs or {}) do

				if cfg.buildVariant then
					config.addUsageConfig(realProj, usageProj, cfg.buildVariant)
				end

			end
		end -- realProj

	end

--
-- Assigns a unique objects directory to every configuration of every project
-- taking any objdir settings into account, to ensure builds
-- from different configurations won't step on each others' object files. 
-- The path is built from these choices, in order:
--
--   [1] -> the objects directory as set in the config
--   [2] -> [1] + the project name
--   [3] -> [2] + the build configuration name
--   [4] -> [3] + the platform name
--

--[[	function globalContainer.bakeobjdirs(allProjects)
		
		if premake.fullySpecifiedObjdirs then
			-- Assume user has assiged unique objdirs
			for _,prj in pairs(allProjects) do
				for cfg in project.eachconfig(prj) do
					-- expand any tokens contained in the field
					oven.expandtokens(cfg, "config", nil, "objdir")
				end
			end
			return
		end
		
		-- function to compute the four options for a specific configuration
		local function getobjdirs(cfg)
			local dirs = {}
			
			local dir = path.getabsolute(path.join(project.getlocation(cfg.project), cfg.objdir or "obj"))
			table.insert(dirs, dir)

			dir = path.join(dir, cfg.project.name)
			table.insert(dirs, dir)
			
			dir = path.join(dir, cfg.buildcfg)
			table.insert(dirs, dir)
			
			if cfg.platform and cfg.platform ~= '' then
				dir = path.join(dir, cfg.platform)
				table.insert(dirs, dir)
			end
			
			return dirs
		end

		-- walk all of the configs in the solution, and count the number of
		-- times each obj dir gets used
		local counts = {}
		local configs = {}
		
		for _,prj in pairs(allProjects) do
			for cfg in project.eachconfig(prj) do
				-- expand any tokens contained in the field
				oven.expandtokens(cfg, "config", nil, "objdir")
				
				-- get the dirs for this config, and remember the association
				local dirs = getobjdirs(cfg)
				configs[cfg] = dirs
				
				for _, dir in ipairs(dirs) do
					counts[dir] = (counts[dir] or 0) + 1
				end
			end
		end

		-- now walk the list again, and assign the first unique value
		for cfg, dirs in pairs(configs) do
			for _, dir in ipairs(dirs) do
				if counts[dir] == 1 then
					cfg.objdir = dir 
					break
				end
			end
		end
	end
]]

