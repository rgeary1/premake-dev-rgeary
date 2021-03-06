--
-- src/project/config.lua
-- Premake configuration object API
-- Copyright (c) 2011-2012 Jason Perkins and the Premake project
--

	local project = premake5.project
	local config = premake5.config
	local oven = premake5.oven
	local keyedblocks = premake.keyedblocks
	local globalContainer = premake5.globalContainer
	local targets = premake5.targets

	local bvignoreSet = toSet({ 'buildcfg', 'platform' })
	
	function config.createBuildVariant(buildcfg, platform, variants)
		local buildVariant = { buildcfg = buildcfg, platform = platform }
		for k,v in pairs(variants or {}) do
			if not bvignoreSet[k] then
				buildVariant[k] = v
			end
		end
		return buildVariant
	end
--
-- Create a unique name from the build configuration / platform / features
--
	function config.getBuildName(buildVariant, platformSeparator)
		platformSeparator = platformSeparator or '_'
		local cfgName = config.getcasedvalue(buildVariant.buildcfg or "All")
		if buildVariant.platform and buildVariant.platform ~= '' then
			cfgName = cfgName .. platformSeparator .. config.getcasedvalue(buildVariant.platform)
		end
		local parts = {}
		for k,v in pairs(buildVariant) do
			if not bvignoreSet[k] then
				table.insert(parts, config.getcasedvalue(v))
			end
		end
		if #parts > 0 then
			table.sort(parts)
			cfgName = cfgName..'.'..table.concat(parts,'.')
		end
		
		return cfgName
	end

--
-- Add a configuration to a usage project, propagate fields from the real project
--  buildVariant is a hash table of all the propagated features (eg. buildcfg, platform, custom features)
--
	function config.addUsageConfig(realProj, usageProj, buildVariant)
		local realCfg = project.getconfig2(realProj, buildVariant)
		
		if not usageProj then
			error("No usage project for "..realProj.name)
		end
		
		if not usageProj.hasBakedUsage then
			globalContainer.bakeUsageProject(usageProj)
		end
		
		local usageKB,found = keyedblocks.createblock(usageProj.keyedblocks, buildVariant)
		
		if found then return usageKB end

		-- To use a library project, you need to link to its target
		--  Copy the build target from the real proj
		if realCfg.linktarget and realCfg.linktarget.abspath then
			local realTargetPath = realCfg.linktarget.abspath
			if realCfg.kind == 'SharedLib' then
				-- link to the target as a shared library
				oven.mergefield(usageKB, "linkAsShared", { realTargetPath })
				--oven.mergefield(usageKB, "rpath", { path.getdirectory(realTargetPath) })
			elseif realCfg.kind == 'StaticLib' then
				-- link to the target as a static library
				oven.mergefield(usageKB, "linkAsStatic", { realTargetPath })
			end
		end
		if realCfg.kind == "Command" then
			oven.mergefield(usageKB, "compiledepends", { realProj.name })
		elseif realCfg.kind == premake.OBJECTFILE then
			local realTargetPath = realCfg.linktarget.abspath
			oven.mergefield(usageKB, "linkAsStatic", { realTargetPath })
		elseif not realCfg.kind then
			print("Warning : Target \""..realProj.name.."\" is missing cfg.kind")
			-- RG : Protobuf & mkheader projects don't define it, is it necessary?
			oven.mergefield(usageKB, "compiledepends", { realProj.name })
		end
		
		-- Propagate some fields from real project to usage project
		for fieldName, field in pairs(premake.propagatedFields) do
			local usagePropagate = field.usagePropagation
			local value = realCfg[fieldName]
			local propagateValue = false
			
			if realCfg[fieldName] then
				if usagePropagate == "Always" then
					propagateValue = value
				elseif usagePropagate == "WhenStaticLib" and realCfg.kind == "StaticLib" then
					propagateValue = value
				elseif usagePropagate == "WhenSharedOrStaticLib" and (realCfg.kind == "StaticLib" or realCfg.kind == "SharedLib") then
					propagateValue = value
				elseif type(usagePropagate) == 'function' then
					propagateValue = usagePropagate(realCfg, value)
				end
				
				if propagateValue then
					oven.mergefield(usageKB, fieldName, propagateValue )
				end
			end						
		end
		
		keyedblocks.resolveUses(usageKB, usageProj)
		
		return usageKB
	end 
--
-- Finish the baking process for a solution or project level configurations.
-- Doesn't bake per se, just fills in some calculated values.
--

	function config.bake(prjOrSln, filter)
		
		local cfg = keyedblocks.getconfig(prjOrSln, filter, nil, {})
		local prj, sln
		
		if ptype(prjOrSln) == 'solution' then
			sln = prjOrSln
			prj = project.getUsageProject(prjOrSln.name)
		else
			prj = prjOrSln
			sln = prj.solution
		end

		cfg.buildcfg = cfg.buildcfg or filter.buildcfg
		cfg.platform = cfg.platform or filter.platform
		cfg.system = cfg.system or filter.system
		cfg.architecture = cfg.architecture or filter.architecture
		cfg.solution = sln
		cfg.project = prj
		cfg.isUsage = prj.isUsage
		cfg.flags = cfg.flags or {}
		
		-- Move any links in to linkAsStatic or linkAsShared
		if cfg.links then
			for _,linkName in ipairs(cfg.links) do
				local linkPrj = project.getRealProject(linkName)
				local linkKind 
				
				if linkPrj then 
					linkKind = linkPrj.kind
				else 
					-- must be a system lib
					linkKind = cfg.kind
				end
				
				if linkKind == premake.STATICLIB then
					oven.mergefield(cfg, 'linkAsStatic', linkName)
				else
					oven.mergefield(cfg, 'linkAsShared', linkName)
				end
			end
			cfg.links = nil
		end
		
		-- Remove any libraries in linkAsStatic that have also been defined in linkAsShared
		oven.removefromfield(cfg.linkAsStatic, cfg.linkAsShared, "linkAsStatic") 
					
		ptypeSet( cfg, 'config' )

		-- fill in any calculated values
		
		-- assign human-readable names
		cfg.longname = config.getBuildName(cfg.buildVariant, '|')
		cfg.shortname = config.getBuildName(cfg.buildVariant, '_')
		cfg.shortname = cfg.shortname:gsub(" ", "_")
		
		-- set default objdir
		if not cfg.objdir then
			local defaultObjDir = _OPTIONS['objdir'] or "$root/bin/%{prj.dirFromRoot}/%{prj.name}/%{cfg.shortname}"

			-- objdir should be relative to $root unless specified otherwise
			if (not defaultObjDir:startswith("/")) and (not defaultObjDir:startswith("$")) then
				defaultObjDir = "$root/"..defaultObjDir
			end

			cfg.objdir = defaultObjDir
		end
		if not cfg.targetdir then
			local defaultTargetDir = _OPTIONS['targetdir'] or cfg.objdir
			 
			-- targetdir should be relative to $root unless specified otherwise
			if (not defaultTargetDir:startswith("/")) and (not defaultTargetDir:startswith("$")) then
				defaultTargetDir = "$root/"..defaultTargetDir
			end
			 
			cfg.targetdir = defaultTargetDir
		end

		if (not cfg.isUsage) and cfg.kind and cfg.kind ~= 'None' then
			cfg.buildtarget = config.gettargetinfo(cfg)
			oven.expandtokens(cfg, nil, nil, "buildtarget", true)
			-- remove redundant slashes, eg. a//b
			if (cfg.buildtarget or {}).abspath then
				cfg.buildtarget.abspath = cfg.buildtarget.abspath:replace("//","/")
			end
			
			cfg.linktarget = config.getlinkinfo(cfg)
			if cfg.linktarget ~= cfg.buildtarget then
				oven.expandtokens(cfg, nil, nil, "linktarget", true)
				if (cfg.linktarget or {}).abspath then
					cfg.linktarget.abspath = cfg.linktarget.abspath:replace("//","/") 
				end
			end
		end
		
		oven.expandtokens(cfg, "config")
		
		-- Remove self references
		-- This can happen if a library "uses" itself
		if cfg.linktarget and cfg.linktarget.abspath then
			oven.removefromfield( cfg.linkAsShared, { cfg.linktarget.abspath }, "linkAsShared" )
			oven.removefromfield( cfg.linkAsStatic, { cfg.linktarget.abspath }, "linkAsStatic" )

			-- Store for later reference, so we can compute implicit dependencies from a link output path
			targets.linkTargets[cfg.linktarget.abspath] = cfg
		end
		
		return cfg
				
	end


--
-- Helper function for getlinkinfo() and gettargetinfo(); builds the
-- name parts for a configuration, for building or linking.
--
-- @param cfg
--    The configuration object being queried.
-- @param kind
--    The target kind (SharedLib, StaticLib).
-- @param field
--    One of "target" or "implib", used to locate the naming information
--    in the configuration object (i.e. targetdir, targetname, etc.)
-- @return
--    A target info object; see one of getlinkinfo() or gettargetinfo()
--    for more information.
--

	local function buildtargetinfo(cfg, kind, field)
		if kind == 'Command' then
			return {}
		end
	
		local basedir = project.getlocation(cfg.project)

		local directory = path.asRoot(path.getabsolute(cfg[field.."dir"] or cfg.targetdir or basedir))
		local basename = cfg[field.."name"] or cfg.targetname or cfg.project.name
		
		-- in case a project has a slash in the name
		if basename:contains("/") then
			basename = basename:match(".*/([^/]*)")
		end

		local bundlename = ""
		local bundlepath = ""
		local suffix = ""

		local sysinfo = premake.systems[cfg.system][kind:lower()] or {}
		local prefix = sysinfo.prefix or ""
		local extension = sysinfo.extension or ""
		
		-- Mac .app requires more logic than I can bundle up in a table right now
		if cfg.system == premake.MACOSX and kind == premake.WINDOWEDAPP then
			bundlename = basename .. ".app"
			bundlepath = path.join(bundlename, "Contents/MacOS")
		end

		prefix = cfg[field.."prefix"] or cfg.targetprefix or prefix
		suffix = cfg[field.."suffix"] or cfg.targetsuffix or suffix
		extension = cfg[field.."extension"] or extension
		local soversion = cfg.soversion
		
		if soversion then
			if cfg.system ~= premake.WINDOWS then
				extension = extension .. "." .. soversion
			else
				extension = soversion .. "." .. extension
			end
		end

		local info = {}
		info.directory  = directory -- project.getrelative(cfg.project, directory)
		info.basename   = basename .. suffix
		info.name       = info.basename .. extension
		if not info.name:startswith(prefix) then
			-- if the project is called libX, avoid naming the target file liblibX
			info.name = prefix .. info.name
		end
		info.extension  = extension
		info.abspath    = path.join(directory, info.name)
		info.fullpath   = path.join(info.directory, info.name)
		info.relpath    = info.fullpath
		info.bundlename = bundlename
		info.bundlepath = path.join(info.directory, bundlepath)
		info.prefix     = prefix
		info.suffix     = suffix
		info.soversion  = soversion
		return info
	end


--
-- Check a configuration for a source code file with the specified 
-- extension. Used for locating special files, such as Windows
-- ".def" module definition files.
--
-- @param cfg
--    The configuration object to query.
-- @param ext
--    The file extension for which to search.
-- @return
--    The full file name if found, nil otherwise.
--

	function config.findfile(cfg, ext)
		for _, fname in ipairs(cfg.files) do
			if fname:endswith(ext) then
				return project.getrelative(cfg.project, fname)
			end
		end
	end


--
-- Retrieve the configuration settings for a specific file.
--
-- @param cfg
--    The configuration object to query.
-- @param filename
--    The full, absolute path of the file to query.
-- @return
--    A configuration object for the file, or nil if the file is
--    not included in this configuration.
--

	function config.getfileconfig(cfg, filename)
		-- if there is no entry, then this file is not part of the config
		if not cfg.files then
			error("No files for "..cfg.project.name..":"..cfg.shortname)
		end
		local filecfg = cfg.files[filename]
		if not filecfg then
			return nil
		end
		
		-- initially this value will be a string (the file name); if so, build
		-- and replace it with a full file configuration object
		if type(filecfg) ~= "table" then
			-- fold up all of the configuration settings for this file
			filecfg = oven.bakefile(cfg, filename)
			
			-- merge in the file path information (virtual paths, etc.) that are
			-- computed at the project level, for token expansions to use
			local prjcfg = project.getfileconfig(cfg.project, filename)
			for key, value in pairs(prjcfg) do
				filecfg[key] = value
			end
			
			-- expand inline tokens
			oven.expandtokens(cfg, "config", filecfg)
			
			filecfg.extension = path.getextension(filename):lower()
			
			-- and cache the result
			cfg.files[filename] = filecfg
		end
		
		return filecfg
	end


--
-- Retrieve linking information for a specific configuration. That is,
-- the path information that is required to link against the library
-- built by this configuration.
--
-- @param cfg
--    The configuration object to query.
-- @return
--    A table with these values:
--      basename   - the target with no directory or file extension
--      name       - the target name and extension, with no directory
--      directory  - relative path to the target, with no file name
--      extension  - the file extension
--      prefix     - the file name prefix
--      suffix     - the file name suffix
--      fullpath   - directory, name, and extension relative to project
--      abspath    - absolute directory, name, and extension
--

	function config.getlinkinfo(cfg)
		-- if an import library is in use, switch the target kind
		local kind = cfg.kind
		local field = "target"
		if project.iscppproject(cfg.project) then
			if cfg.system == premake.WINDOWS and kind == premake.SHAREDLIB and not cfg.flags.NoImportLib then
				kind = premake.STATICLIB
				field = "implib"
			end
		elseif cfg.buildtarget then
			-- saves some time
			return cfg.buildtarget
		end

		return buildtargetinfo(cfg, kind, field)
	end


--
-- Returns a string key that can be used to identify this configuration.
--

	function config.getlookupkey(cfg)
		return (cfg.buildcfg or "All") .. (cfg.platform or "")
	end


--
-- Retrieve a list of link targets from a configuration.
--
-- @param cfg
--    The configuration object to query.
-- @param kind
--    The type of links to retrieve; one of:
--      siblings     - linkable sibling projects
--      system       - system (non-sibling) libraries
--      dependencies - all sibling dependencies, including non-linkable
--      all          - return everything
-- @param part
--    How the link target should be expressed; one of:
--      name      - the decorated library name with no directory
--      basename  - the undecorated library name
--      directory - just the directory, no name
--      fullpath  - full path with decorated name
--      object    - return the project object of the dependency
-- @return
--    An array containing the requested link target information.
--	
	
 	function config.getlinks(cfg, kind, part)
		local result = {}

		-- if I'm building a list of link directories, include libdirs
		if part == "directory" and kind == "all" then
			for _, dir in ipairs(cfg.libdirs) do
				table.insert(result, project.getrelative(cfg.project, dir))
			end
		end
		
		local function canlink(source, target)
			-- can't link executables
			if (target.kind ~= "SharedLib" and target.kind ~= "StaticLib") then 
				return false
			end
			-- can't link managed and unmanaged projects
			if project.iscppproject(source.project) then
				return project.iscppproject(target.project)
			elseif project.isdotnetproject(source.project) then
				return project.isdotnetproject(target.project)
			end
		end	

		for _, link in ipairs(cfg.links or {}) do
			local item

			-- is this a sibling project?
			local prj = premake.solution.findproject(cfg.solution, link)
			if prj and kind ~= "system" then

				local prjcfg = project.getconfig(prj, cfg.buildcfg, cfg.platform)
				if prjcfg and (kind == "dependencies" or canlink(cfg, prjcfg)) then
					-- if the caller wants the whole project object, then okay
					if part == "object" then
						item = prjcfg
					
					-- if this is an external project reference, I can't return
					-- any kind of path info, because I don't know the target name
					elseif not prj.externalname then
						if part == "basename" then
							item = prjcfg.linktarget.basename
						else
							item = path.rebase(prjcfg.linktarget.fullpath, 
											   project.getlocation(prjcfg.project), 
											   project.getlocation(cfg.project))
							if part == "directory" then
								item = path.getdirectory(item)
							end
						end
					end
				end

			elseif not prj and (kind == "system" or kind == "all") then

				if part == "directory" then
					local dir = path.getdirectory(link)
					if dir ~= "." then
						item = dir
					end
				elseif part == "fullpath" then
					item = link
					if cfg.system == premake.WINDOWS then
						if project.iscppproject(cfg.project) then
							item = path.appendextension(item, ".lib")
						elseif project.isdotnetproject(cfg.project) then
							item = path.appendextension(item, ".dll")
						end
					end
					if item:find("/", nil, true) then
						item = project.getrelative(cfg.project, item)
					end
				else
					item = link
				end

			end

			if item and not table.contains(result, item) then
				table.insert(result, item)
			end
		end
	
		return result
	end


--
-- Retrieve information about a configuration's build target.
--
-- @param cfg
--    The configuration object to query.
-- @return
--    A table with these values:
--      basename   - the target with no directory or file extension
--      name       - the target name and extension, with no directory
--      directory  - relative path to the target, with no file name
--      extension  - the file extension
--      prefix     - the file name prefix
--      suffix     - the file name suffix
--      fullpath   - directory, name, and extension, relative to project
--      abspath    - absolute directory, name, and extension
--      bundlepath - the relative path and file name of the bundle
--

	function config.gettargetinfo(cfg)
		return buildtargetinfo(cfg, cfg.kind, "target")
	end

--
--	Returns true if the configuration requests a dependency file output
--
	function config.hasDependencyFileOutput(cfg)
		return cfg.flags.AddPhonyHeaderDependency or
			cfg.flags.CreateDependencyFile or
			cfg.flags.CreateDependencyFileIncludeSystem 
	end
	
--
-- Register a key/value pair, eg. buildcfg=Debug
--
	config.cfgValues = {}
	config.cfgKeys = {}
	function config.registerkey(cfgKey, cfgValues, isPropagated)
		if type(cfgValues) == 'string' then cfgValues = { cfgValues } end
		cfgKey = cfgKey:lower()
		
		for k,v in pairs(cfgValues) do
			if type(v) == 'table' then 
				config.registerkey(cfgKey, v, isPropagated)
			else
				local key = cfgKey
				if type(k) == 'string' then key = k end
				 
				local vlower = v:lower()
				if config.cfgValues[v] then
					if config.cfgValues[v].key ~= key then
						error( 'Configuration keyword "'..v..'" is already registered to key "'..config.cfgValues[v].key..'", can\'t register it to "'..key..'"', 3)
					end
				end
				config.cfgValues[v] = {
					v = v,
					vlower = vlower,
					key = key,
					isPropagated = isPropagated,				
				}
				config.cfgValues[vlower] = config.cfgValues[v]
				
				config.cfgKeys[key] = config.cfgKeys[key] or {}
				config.cfgKeys[key].key = key
				config.cfgKeys[key].isPropagated = isPropagated
			end
		end
	end
	
--
-- Restore the Normal Case from a lower cased form of value
--
	function config.getcasedvalue(cfgValue)
		local cfgValueT = config.cfgValues[cfgValue]
		if cfgValueT then
			cfgValue = cfgValueT.v
		end	
		return cfgValue
	end
	
--
-- Given a value (eg. "Release"), find the category (ie. buildcfg)
--
	function config.getkeyvalue(v)
		if v:contains("=") then
			v = v:lower()
			local key = v:match("[^=]*")
			local value = v:match(".*=(.*)")
			return key,config.getcasedvalue(value)
		else
			local cfgValue = config.cfgValues[v]
			if cfgValue then
				return cfgValue.key, cfgValue.v
			else
				return v, v
			end
		end
	end
	
--
-- Returns list of keywords that are propagated
--
	function config.getBuildVariant(filter)
		local rv = {}
		for k,v in pairs(filter) do
			local keyword = config.cfgKeys[k] or config.cfgValues[v]
			if keyword and keyword.isPropagated then
				if type(k) == 'number' then
					rv[k] = v
				elseif type(k) == 'string' and keyword.key == k:lower() then
					rv[k] = v
				end
			end
		end
		return rv			
	end