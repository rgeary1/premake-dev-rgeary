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
	-- explicitly requested projects
	targets.requested = {}		-- requested[#] = prj or sln
	targets.prjToBuild = {}		-- prjToBuild[prjName] = prj
	targets.slnToBuild = {}		-- slnToBuild[slnName] = sln
	-- Keep track of all dependent projects
	targets.prjToExport = {}	-- prjToExport[prjName] = prj
	-- set of projectset names to include. nil = include everything
	targets.includeProjectSets = nil
	targets.prjNameToSet = {}	-- prjNameToSet[prjFullname] = set of projectsets containing prj
	
--
-- Apply any command line target filters
--
	function globalContainer.filterTargets()
		-- Read --projectset= option
		if _OPTIONS['projectset'] then
			targets.includeProjectSets = {}
			local prjsets = _OPTIONS['projectset']:split(',')
			for _,p in ipairs(prjsets) do
				if p == 'default' then
					targets.includeProjectSets[""] = ""
				end
				targets.includeProjectSets[p] = p
			end
		end
		
		-- Read command line args for specified targets
		local action = premake.action.current()
		for _,v in ipairs(_ARGS) do
			if v:endswith('/') then v = v:sub(1,#v-1) end
			 
			if not premake.action.get(v) then

				if action.filterProjectsFromCommandLine then
					action.filterProjectsFromCommandLine(v)
				else
					globalContainer.findBuildTarget(v)
				end
			end
		end

		-- If nothing is specified :
		if table.isempty(targets.requested) then
			
			-- Build default premake file projects
			if _OPTIONS['defaultbuilddir'] then
				local defaultDir = path.getabsolute(_OPTIONS['defaultbuilddir'])
				local found = false
				for _,sln in pairs(targets.solution) do
					if path.getdirectory(sln.script) == defaultDir and not targets.slnToBuild[sln.name] then
						print("Build Solution : "..sln.name)
						targets.slnToBuild[sln.name] = sln
						table.insert( targets.requested, sln )
						found = true
					end 
				end
				for _,prj in pairs(targets.allReal) do
					if path.getdirectory(prj.script) == defaultDir and not targets.prjToBuild[prj.name] then
						print("Build Project : "..prj.name)
						targets.prjToBuild[prj.name] = prj
						table.insert( targets.requested, prj )
						found = true
					end 
				end
				
				if not found then 
					print("Could not find the directory \""..defaultDir.."\" in the build tree. Did you include it?")
					os.exit(1)
				end
			end
		end
					
		-- ... or Build all solutions
		if table.isempty(targets.requested) then
			for _,sln in pairs(targets.solution) do
				targets.slnToBuild[sln.name] = sln
			end
		end
		
		-- Add solution's projects to the build
		for _,sln in pairs(targets.slnToBuild) do
			for _,prj in ipairs(sln.projects) do
			
				-- Filter to selected project sets
				if not prj.isUsage and project.inProjectSet(prj, targets.includeProjectSets) then
					targets.prjToBuild[prj.name] = project.getRealProject(prj.name)
				end
			end
		end
		
		if table.isempty(targets.prjToBuild) then
			print("Warning : No projects in the selection!")
		end		
	end


	function globalContainer.findBuildTarget(v)
		local found = false
	
		-- Check if any command line arguments are solutions
		for _,sln in pairs(targets.solution) do
			if sln.name == v or sln.name:contains(v..'/') or sln.name:endswith('/'..v) then
				-- Add solution to the build
				targets.slnToBuild[sln.name] = sln
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

		if not found then
			-- search for v as a project name
			for _,prj in Seq:new(targets.allReal):concat(targets.allUsages):each() do
				if prj.shortname == v then
					found = true
					-- Add solution to the build
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
		
		-- Filter targets to bake
		globalContainer.filterTargets()
		
		local toBake = table.shallowcopy(targets.prjToBuild)
				
		-- Bake all real projects, but don't resolve usages		
		local tmr = timer.start('Bake projects')
		for prjName,prj in pairs(toBake) do
			project.bake(prj)

			-- Add default configurations
						
			local cfglist = project.bakeconfigmap(prj)
			for _,cfgpair in ipairs(cfglist) do
				local buildVariant = {
					buildcfg = cfgpair[1],
					platform = cfgpair[2],				
				}
				
				-- Add any command-line variants
				if _OPTIONS['define'] then
					local defines = _OPTIONS['define']:split(' ')
					for _,v in ipairs(defines) do
						buildVariant[v] = v
					end
				end
				
				project.addconfig(prj, buildVariant)
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
			parent = project.getUsageProject( usageProj.solution.name )
		end
		keyedblocks.create(usageProj, parent)

		local realProj = project.getRealProject(usageProj.name, usageProj.namespaces)
		if realProj then
		
			-- Bake the real project (RP) first, and apply RP's usages to RP
			project.bake(realProj)
			
			-- Set up the usage target defaults from RP
			for _,cfg in pairs(realProj.configs) do

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

