--
-- Abstract tool
--  Defines a command line given a tool name and how to process inputs & flags
--  Override any part of this to define your own tool
--
--  Inputs are lists of strings, split in to categories, eg :
--	  Default input filenames : toolInputs['default']			(eg. source files for cc, obj files for linker)
--	  defines :					toolInputs['defines']
--	  includedirs :				toolInputs.includedirs
--	  libdirs :					toolInputs.libdirs
--    systemlibs				toolInputs.systemlibs
--	  staticlibs  				toolInputs.staticlibs
--	  sharedlibs  				toolInputs.sharedlibs
--	  frameworklibs				toolInputs.frameworklibs
--  Decorating these toolInputs is done via tool.prefixes[inputCategory] and suffixes[inputCategory]
--  eg. tool.prefixes.defines = '-D'
--  Alternatively, you can specify function tool.decorateFn.includedirs(cfg) to override this behaviour

premake.abstract.buildtool = {}
local tool = premake.abstract.buildtool

-- Tool name as it appears to premake. There can be several tools with the same tool name (eg. 'cc'), 
--  but they must be unique within the same toolset
tool.toolName = 'unnamed-tool'

-- If specified, inherit values & function definitions from this table, unless overridden 
tool.inheritFrom = nil

-- path to the tool binary. nil = search for it
tool.binaryDir = nil

-- Name of the binary to execute
tool.binaryName = nil

tool.binaryFullpath = nil

-- Fixed flags which always appear in the command line. Two ways to override this.
tool.fixedFlags = ''
function tool:getFixedFlags()
	return self.fixedFlags
end 

-- Mapping from Premake 'flags' to compiler flags
tool.flagMap = {}

-- Prefix to decorate defines, include paths & include libs
tool.prefixes = {
	-- defines = '-D',
	-- systemlibs = '-l'
	-- depfileOutput = '-MF'
}
tool.suffixes = {
	-- depfileOutput = '.d'
}
tool.decorateFn = {
	-- input = function(cfg, inputList) return '-Wl,--start-group'..table.concat(inputList, ' ')..'-Wl,--end-group'; end
}

-- Extra cmdflags depending on the config & system
function tool:getsysflags(cfg)
	return ''
end

--
-- Construct a command line given the flags & input/output args. 
--
function tool:getCommandLine(cmdArgs)
	local toolCmd = self:getBinary()
	
	if #cmdArgs == 0 then
		error('#toolInputs == 0, did you forget to flatten it?')
	end
	cmdArgs = toList(cmdArgs)
	
	-- Allow the tool to silence stderr. eg. The Intel ar tool outputs unwanted status information   
	local redirectStderr = "" 
    if(self.redirectStderr) then
      local hostIsWindows = os.is("windows")
      if( hostIsWindows ) then
        redirectStderr = '2> nul'
      else
        redirectStderr = '2> /dev/null'
      end
	  table.insert(cmdArgs, redirectStderr)    	
    end
	
	local cmdParts = table.join(toolCmd, cmdArgs)

	local cmd = table.concat(cmdParts, ' ')
	return cmd
end

----------------------------------------------
-- Functions which you don't need to override
----------------------------------------------

--
-- Decorates the tool inputs for the command line
-- Returns a table containing a sequence of command line arguments, and a hashtable of variable definitions 
--
--  outputVar and inputVar are what you want to appear on the command line in the build file, eg. $out and $in
--
function tool:decorateInputs(cfg, outputVar, inputVar)
	local rv = {}
	
	-- Construct the argument list from the inputs
	for category,inputList in pairs(cfg) do
		local d = self:decorateInput(category, inputList)
		if d ~= '' then
			rv[category] = d
		end		
	end
	
	rv.flags = self:decorateInput('fixedFlags', self:getFixedFlags(), true)
	rv.sysflags = self:decorateInput('sysflags', self:getsysflags(), true)
	local output = self:decorateInput('output', outputVar, true)
	local input = self:decorateInput('input', inputVar, true)

	local cfgflags = table.translate(cfg.flags, self.flagMap)
	if #cfgflags > 0 then
		rv.cfgflags = table.concat(cfgflags, ' ')
	end
	
	table.insert(rv, output)
	table.insert(rv, input)
	
	-- Special case for depfile output (a secondary output). Only output depfile cmd if we want it
	if cfg.flags.AddPhonyHeaderDependency or
		cfg.flags.CreateDependencyFile or
		cfg.flags.CreateDependencyFileIncludeSystem 
	then
		local depfileOutput = self:decorateInput('depfileOutput', outputVar)
		if depfileOutput then
			table.insert(rv, depfileOutput)
		end
	end
	
	return rv
end

function tool:decorateInput(category, inputList, alwaysReturnString)
	local str = ''
	inputList = toList(inputList)
	
	if self.decorateFn[category] then
	
		-- Override prefix/suffix behaviour
		str = self.decorateFn[category](inputList)
		
	elseif self.prefixes[category] or self.suffixes[category] then
		-- Decorate each entry with prefix/suffix
		local prefix = self.prefixes[category] or ''
		local suffix = self.suffixes[category] or ''
		
		for _,v in ipairs(inputList) do
			str = str..prefix .. v .. suffix..' '
		end
	elseif alwaysReturnString then
		str = table.concat(inputList, ' ')
	end
	return str
end

-- Return the full path of the binary
function tool:getBinary()
	if self.binaryFullpath then
		return self.binaryFullpath
	end
	
	if not self.binaryName then
		error('binaryName is not specified for tool ' .. self.toolName)
	end

 	-- Find the binary
	local path = os.findbin(self.binaryName, self.binaryDir)
	local fullpath = ''
	if path then
		fullpath = path .. '/' .. self.binaryName
	else
		-- Just assume it's there
		if self.binaryDir then
			fullpath = self.binaryDir .. '/'
		end
		fullpath = fullpath .. self.binaryName
	end
	self.binaryDir = path
	self.binaryFullpath = fullpath
	
	return fullpath
end

--
-- Get library includes
--
function tool:getIncludeLibs(cfg, systemonly)
	local result = {}

	local links
	if not systemonly then
		links = config.getlinks(cfg, "siblings", "object")
		for _, link in ipairs(links) do
			-- skip external project references, since I have no way
			-- to know the actual output target path
			if not link.project.externalname then
				if link.kind == premake.STATICLIB then
					-- Don't use "-l" flag when linking static libraries; instead use
					-- path/libname.a to avoid linking a shared library of the same
					-- name if one is present
					table.insert(result, project.getrelative(cfg.project, link.linktarget.abspath))
				else
				 	-- Don't use path when linking shared libraries, otherwise loader will always expect the same
				 	-- folder structure
					table.insert(result, self.includeLibPrefix .. link.linktarget.basename)
				end
			end
		end
	end

	-- The "-l" flag is fine for system libraries
	links = config.getlinks(cfg, "system", "basename")
	for _, link in ipairs(links) do
		if path.isframework(link) then
			table.insert(result, self.includeFrameworkPrefix .. path.getbasename(link))
		elseif path.isobjectfile(link) then
			table.insert(result, link)
		else
			table.insert(result, self.includeLibPrefix .. link)
		end
	end

	return result
end	

--
-- API callbacks
--

function premake.tools.newtool(toolDef)
	if not toolDef or type(toolDef) ~= 'table' then
		error('Expected tool definition table')
	end
	
	local t = inheritFrom(premake.abstract.buildtool, 'tool')
	
	-- Apply inherited tool
	if toolDef.inheritFrom then
		for k,v in pairs(toolDef.inheritFrom) do
			t[k] = v
		end
	end
	
	-- Apply specified values/functions
	for k,v in pairs(toolDef) do
		if type(t[k]) == 'table' and type(v) == 'table' then
			t[k] = table.merge(t[k], v) 
		else 
			t[k] = v
		end
	end
	return t
end

function premake.tools.newtoolset(toolsetDef)
	if not toolsetDef or type(toolsetDef) ~= 'table' then
		error('Invalid toolset definition, expected table')
	end
	if not toolsetDef.toolsetName or toolsetDef.toolsetName == '' then
		error('newtoolset does not define toolsetName')
	end
	
	local t = inheritFrom(premake.abstract.toolset)
	
	-- Apply specified values/functions
	for k,v in pairs(toolsetDef) do
		t[k] = v
	end
	ptypeSet(t, 'toolset')
	
	if t.tools == nil then
		print('Warning : No tools defined for toolset ' .. t.toolsetName)
	else
		-- Construct tool lookup
		for _,tool in ipairs(t.tools) do
			t.tools[tool.toolName] = tool
		end
	end 
	
	premake.tools[t.toolsetName] = t
end
