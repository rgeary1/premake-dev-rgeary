--
-- Print action, explains what each configuration will do
--  Useful for finding & explaining compiler flags
--

-- capital P to distinguish it from the global function print()
	premake.actions.Print = {}
	local Print = premake.actions.Print
	local config = premake5.config
	local project = premake5.project
	local solution = premake.solution
	local globalContainer = premake5.globalContainer
	local keyedblocks = premake.keyedblocks
	local targets = premake5.targets
	Print.filterProj = nil
	Print.level	= 5		-- Print everything
	
	Print.fieldLevel = {
		uses = 1,
		projectset = 1,
		compiledepends = 1,
		includedirs = 1,
		linkAsStatic = 1,
		linkAsShared = 1,
		system = 99,
		architecture = 99,
	}
	
	newaction {
		trigger		= "print",
		shortname	= "Print meta-action",
		description = "Explains the commands to be run for each configuration print [uses/usage] [project name]",
		
		isnextgen	= true,
	
		filterTargets = function ()
			Print.filterProj = {}
			for _,v in ipairs(_ARGS) do
				if v == 'uses' then
					Print.level = 1
				end
				if v == 'usage' then
					Print.what = "usage"
				end
				local sln = targets.solution[v]
				if premake.action.get(v) then
					-- do nothing
				elseif sln then
					table.insert( Print.filterProj, sln )
					table.insert( targets.requested, sln )
				else
					local prj = project.getRealProject(v) or project.getUsageProject(v)
					local defaultBuildDir = _OPTIONS['defaultbuilddir']
					if not prj then
						-- try to match the name
						for _,p in pairs(targets.allReal) do
							if (not defaultBuildDir) or p.basedir:startswith(defaultBuildDir) then
								if p.shortname == v then
									prj = p
									break
								end
							end
						end
					end
					if not prj then
						-- try to match the name
						for _,p in pairs(targets.allUsage) do
							if (not defaultBuildDir) or p.basedir:startswith(defaultBuildDir) then
								if p.shortname == v then
									prj = p
									break
								end
							end
						end
					end
					if not prj then
						-- match any part of the name
						for _,p in pairs(targets.allReal) do
							if (not defaultBuildDir) or p.basedir:startswith(defaultBuildDir) then
								if p.name:contains(v) then
									prj = p
									break
								end
							end
						end
					end
					if prj then
						table.insert( Print.filterProj, prj )
						targets.prjToBuild[prj.name] = prj
						table.insert( targets.requested, prj )
					end					
				end
			end
			table.sort(Print.filterProj, function (a,b) return a.name < b.name end )
			if #Print.filterProj == 0 then
				print("No projects specified")
			end
		end,
		
		onsolution 	= function(sln) 
			if Print.filterProj then return end
			print("Solution : "..sln.name) 
		end,
		
		execute = function() Print.execute() end
	}
	
	local indentStr = ''
	local function indent(change)
		local len = #indentStr + change
		indentStr = ''
		for i = 1,len do
			indentStr = indentStr .. ' '
		end
	end
	
	local function pRecursive(level, name, obj, depth)
		depth = depth or 4
		local str = iif(name, tostring(name) .. ' : ', '')
		if( obj and type(obj) == "table" ) then
			if depth < 0 then
				print(indentStr .. str .. tostring(obj))
			else
				if( isStringSeq(obj) ) then
					local objStr = table.concat(getIValues(obj), ', ')
					if level < 2 and #objStr > 100 then
						objStr = table.concat(getIValues(obj), '\n'..indentStr..'  ')
						print(indentStr .. str .. objStr)
					else
						print(indentStr .. str .. objStr)
					end
				else
					print(indentStr .. str)
					indent(2)
					for k,v in pairs(obj) do
						pRecursive(level, k, v, depth-1)
					end
					indent(-2)
				end
			end
		elseif obj then
			print(indentStr .. str .. tostring(obj))
		else
			print(indentStr .. tostring(name))
		end
	end
	
	-- need to separate out this from pRecursive otherwise calling with tables will put the 2nd value as the depth
	function Print.print(level, name, obj)
		if level > 0 and level < 5 and not obj then
			return
		end
		if Print.level >= level then
			return pRecursive(level, name, obj, nil)
		end
	end
	local function p0(name,obj) return Print.print(0,name,obj) end 
	local function p1(name,obj) return Print.print(1,name,obj) end 
	local function p2(name,obj) return Print.print(2,name,obj) end 
	local function p3(name,obj) return Print.print(3,name,obj) end 
	local function p4(name,obj) return Print.print(4,name,obj) end 
	local function p5(name,obj) return Print.print(5,name,obj) end
	local function p(str) return print(indentStr .. str) end 
	
	function Print.execute()
		for _,prjOrSln in ipairs(Print.filterProj or {}) do
			local sln, prj
			if ptype(prjOrSln) ~= 'project' then
				sln = prjOrSln
				Print.onSolution(sln)
			else
				prj = prjOrSln
				Print.onProject(prj)
			end
			if not prj and not sln then
				local name = prjOrSln.name
				local suggestions, suggestionStr = project.getProjectNameSuggestions(name)
				print("Could not find "..name)
				if #suggestions == 1 then
					name = suggestions[1]
					print('Suggested : '..name)
					local prj = project.getRealProject(name) or project.getUsageProject(name)
					Print.onProject(prj)
				else
					error(suggestionStr or '')
				end
			end
		end
	end	
	
	function Print.onSolution(sln)
		p0('Solution ', sln.name)
		indent(2)
		p2('platforms', getIValues(sln.platforms))
		p5('language', sln.language)
		p5('basedir', sln.basedir)
		p5('configurations', sln.configurations)
		local prjNames = Seq:new(sln.projects):whereK(function(k,v) return type(k) == 'string' end)
			:getKeys():toTable()
		table.sort(prjNames)
		p1('Projects', prjNames)
		indent(-2)
	end
	
	function Print.onProject(prj)
		local uProj = prj
		if prj.isUsage then
			p0('Usage', prj.name)
		else
			uProj = project.getUsageProject(prj.name)
			if not uProj then
				error("Could not find usage project for "..prj.name)
			end
			p0('Usage Requirements', uProj.name)
		end
		
		if Print.what == 'usage' or prj.isUsage then
			indent(2)
				globalContainer.bakeUsageProject(uProj)
				project.bake(uProj)
				local buildVariants = Seq:new(prj.configs or {}):select('buildVariant'):toTable()
				if table.isempty(buildVariants) then
					buildVariants = solution.getBuildVariants(prj.solution)
				end
				for _,bv in pairs(buildVariants) do
					local filter = keyedblocks.getfilter(uProj, bv)
					local ucfg = config.bake(uProj, filter)
					p1("config", ucfg.shortname)
					indent(2)			
					for k,v in pairs(ucfg) do
						if v and premake.fields[k] then
							local level = Print.fieldLevel[k] or 5
							if type(v) == 'table' then
								if #v > 0 then
									Print.print(level, k, v)
								end
							else
								Print.print(level, k, v)
							end
						end
					end
					indent(-2)
				end
			indent(-2)
		end
		
		if prj.isUsage then
			return
		end

		p0('RealProject', prj.name)
		indent(2)
		p1('solution', prj.solution.name)
		for cfg in project.eachconfig(prj) do
			p0('config', cfg.shortname)
			indent(2)

			p1('kind', cfg.kind)
			p1('projectset', targets.prjNameToSet[prj.fullname])
			attachDebugger()
			local cfg2 = keyedblocks.getconfig(prj, cfg.filter or {}, nil, {})
			p1('usevariant', cfg.usevariant)
			p1('uses', cfg.uses)
			--Print.printUses(cfg, prj)
			p1('alwaysuses', cfg.alwaysuses)
			local usesconfig = {}
			for k,v in pairs(cfg.usesconfig or {}) do
				if k == v then
					table.insert( usesconfig, '['..k..']' )
				else 
					table.insert( usesconfig, '['..k..']='..v )
				end
			end
			p5('usesconfig', usesconfig)
			p1('compiledepends', cfg.compiledepends)
			
			if cfg.toolset then
				local toolset = premake.tools[cfg.toolset]
				p1('toolset ', cfg.toolset)
				indent(2)
					local function flattenArgs(t)
						local t2 = {}
						for k,v in pairs(t) do
							if type(k) ~= 'number' then
								if v ~= '' then
									table.insert(t2, '$'..k)
								end
							else
								table.insert(t2, v)
							end
						end
						return t2
					end
					
					local compileTool = toolset:getCompileTool(cfg)
					local linkTool = toolset:getLinkTool(cfg)
					
					local compileSysflags, compileCmdArgs, compileCmdArgsFlat
					if compileTool then
						compileSysflags = compileTool:getsysflags(cfg)
						compileCmdArgs = compileTool:decorateInputs(cfg, '$out', '$in')
						compileCmdArgsFlat = flattenArgs(compileCmdArgs)
					end
					--local compileVars = Seq:new(compileCmdArgs):getKeys():prependEach('$'):prepend(compileSysflags):mkstring(' ')
					local linkCmdArgs = {}
					local linkVars, linkCmdArgsFlat
					if linkTool then
						linkCmdArgs = linkTool:decorateInputs(cfg, '$out', '$in')
						linkVars = Seq:new(linkCmdArgs):getKeys():prependEach('$'):prepend(linkSysflags):mkstring(' ')
						linkCmdArgsFlat = flattenArgs(linkCmdArgs)
					end
					
	--				p0('cfg          ', cfg)
					p5('defines      ', cfg.defines)
					p1('includedirs  ', cfg.includedirs)
					p1('compiledepends', cfg.compiledepends)
					p4('flags        ', cfg.flags)
					p4('compilewrapper', cfg.compilewrapper)
					if compileTool then
						p5('compiler tool', compileTool.toolName)
						p5('compiler bin ', compileTool:getBinary(cfg))
						p5('compile sysflags', compileSysflags)
						for k,v in pairs(compileCmdArgs) do
						 p5(' .' .. tostring(k) ..' = '..v)
						end				
						p5('compile cmd  ', compileTool:getCommandLine(compileCmdArgsFlat))
					end
					p5('objdir       ', cfg.objdir)
					local files = {}
					for _,v in ipairs(cfg.files or {}) do
						table.insert( files, path.getrelative(repoRoot, v) )
					end
					p5('files', files)
					if linkTool then
						p5('link cmd     ', linkTool:getCommandLine(linkCmdArgsFlat))
						p5('link flags   ', linkTool:getsysflags(cfg), ' ')
						for k,v in pairs(linkCmdArgs) do
							if k ~= 'includedirs' then
						 		p5(' .' .. tostring(k) ..' = '..v)
						 	end
						end				
					end
					if (cfg.linktarget or {}).name then
						p5('link target  ', cfg.linktarget.directory .. '/' .. cfg.linktarget.name)
					end
					p1('linkAsStatic ', cfg.linkAsStatic)
					p1('linkAsShared ', cfg.linkAsShared)
					p4('linkerwrapper', cfg.linkerwrapper)
					if (cfg.buildtarget or {}).name then
						p1('build target  ', cfg.buildtarget.directory .. '/' .. cfg.buildtarget.name)
					end
					p5('build targetdir', cfg.targetdir )
					if cfg.prebuildcommands and 0 < #cfg.prebuildcommands then
						p5('prebuild cmd ', table.concat(cfg.prebuildcommands, "\n" .. indentStr .. '                '))
					end
					if cfg.postbuildcommands and 0 < #cfg.postbuildcommands then
						p5('postbuild cmd', table.concat(cfg.postbuildcommands, "\n".. indentStr .. '                '))
					end
				indent(-2)
			end -- if toolset
			
			indent(-2) -- config
		end
		indent(-2)
		for k,v in pairs(prj) do
			--print('  ' .. tostring(k) .. ' = ' .. tostring(v))
		end
		p0('')
	end
	
	function Print.printUses(cfg, realPrj)
		p("uses :")
		local toPrint = { "defines", "includedirs", "compiledepends", "flags", "links", "uses", 
			"alwaysuses", "usesconfig", "toolset", "links", "linkAsStatic", "linkAsShared", "libdirs" }
		
		indent(2)
		for _,uName in ipairs(cfg.uses) do
			p(uName)
			indent(2)
			
			local uProj = project.getUsageProject(uName, cfg.project.namespaces)
			if uProj then
				local filter = keyedblocks.getfilter(uProj, cfg.buildVariant)
				local ucfg = config.bake(uProj, filter)
				for _,k in ipairs(toPrint) do
					if k ~= 'flags' or #ucfg[k] > 0 then
						p1(k,ucfg[k])
					end
				end
			end
			indent(-2)
		end
		indent(-2)
	end
	