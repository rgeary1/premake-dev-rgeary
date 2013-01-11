--
-- gcc.lua
-- Provides GCC-specific configuration strings.
-- Copyright (c) 2002-2012 Jason Perkins and the Premake project
--

--
-- GCC Compiler toolset
--
local atool = premake.abstract.buildtool 

local gcc_cc = newtool {
	toolName = 'cc',
	binaryName = 'gcc',
	fixedFlags = '-c -x c',
	language = "C",

	-- possible inputs in to the compiler
	extensionsForCompiling = { ".c", },
	
	flagMap = {
		AddPhonyHeaderDependency = "-MP",	 -- used by makefiles
		AllowUndefinedSymbols = {
			Yes = "-Wl,--undefined-symbols",
			No = "-Wl,--no-undefined-symbols",
		},
		CreateDependencyFile = "-MMD",
		CreateDependencyFileIncludeSystem = "-MD",
		InlineDisabled = "-fno-inline",
		InlineAnything = "-finline-functions",
		EnableSSE2     = "-msse2",
		EnableSSE3     = "-msse3",
		EnableSSE41    = "-msse4.1",
		EnableSSE42    = "-msse4.2",
		EnableAVX      = "-mavx",
		Warnings = {
			Off				= "-w",
			Extra			= "-Wall",
		},
		FatalWarnings  = "-Werror",
		Float = {
			Fast		  	= "-fp-model fast=2",
			Strict			= "-fp-model strict",
		},
		Optimize = {
			Off				= "-O0",
			On				= "-O2",
			Size			= "-Os",
			Speed			= "-O3",
		},
		Symbols        = "-g",
		fPIC 		   = "-fPIC",
	},
	prefixes = {
		defines 		= '-D',
		includedirs 	= '-I',
		output			= '-o',
	},
	decorateFn = {
		depfileOutput   = atool.generateDepfileOutput,
	},

	-- System specific flags
	getsysflags = function(self, cfg)
		local cmdflags = {}
		if cfg.system ~= premake.WINDOWS and cfg.kind == premake.SHAREDLIB then
			if not (cfg.flags or {}).fPIC then
				table.insert(cmdflags, '-fPIC')
			end
		end
		
		if cfg.architecture == 'x32' then
			table.insert(cmdflags, '-m32')
		elseif cfg.architecture == 'x64' then
			table.insert(cmdflags, '-m64')
		end
		
		if cfg.flags.Threading == 'Multi' then
			if cfg.system == premake.LINUX then
				table.insert(cmdflags, '-pthread')
			elseif cfg.system == premake.WINDOWS then 
				table.insert(cmdflags, '-mthreads')
			elseif cfg.system == premake.SOLARIS then 
				table.insert(cmdflags, '-pthreads')
			end
		end
		
		return table.concat(cmdflags, ' ')
	end
}
local gcc_cxx = newtool {
	inheritFrom = gcc_cc,	
	toolName = 'cxx',
	language = "C++",
	binaryName = 'g++',
	fixedFlags = '-c -xc++',
	extensionsForCompiling = { ".cc", ".cpp", ".cxx", ".c" },
	flagMap = table.merge(gcc_cc.flagMap, {
		NoExceptions   = "-fno-exceptions",
		NoRTTI         = "-fno-rtti",
	})
}
local gcc_asm = newtool {
	inheritFrom = gcc_cxx,
	toolName = 'asm',
	language = "assembler",
	fixedFlags = '-c -x assembler-with-cpp',
	extensionsForCompiling = { '.s' },
	
	prefixes = gcc_cxx.prefixes,
	suffixes = gcc_cxx.suffixes,
	-- Bug, only writes Makefile style depfiles. Just disable it.
	decorateFn = table.exceptKeys(gcc_cxx.decorateFn, { 'depfileOutput' }),
	flagMap = table.exceptKeys(gcc_cxx.flagMap, { 'CreateDependencyFile', 'CreateDependencyFileIncludeSystem', }),
}
local gcc_ar = newtool {
	toolName = 'ar',
	binaryName = 'ar',
	fixedFlags = 'rsc',
	extensionsForLinking = { '.o', '.a', '.so' },		-- possible inputs in to the linker
	redirectStderr = true,
	targetNamePrefix = 'lib',
}
local gcc_link = newtool {
	toolName = 'link',
	binaryName = 'g++',
	fixedFlags = '-Wl,--start-group',
	extensionsForLinking = { '.o', '.a', '.so' },		-- possible inputs in to the linker
	flagMap = {
		Stdlib = {
			Shared		= '-shared-libgcc',
			Static		= '-static-libgcc',		-- Might not work, test final binary with ldd. See http://www.trilithium.com/johan/2005/06/static-libstdc/
		},
		WholeArchive = "-Wl,--whole-archive",
	},
	prefixes = {
		libdirs 		= '-L',
		output 			= '-o',
		linkoptions		= '',
	},
	suffixes = {
		input 			= ' -Wl,--end-group',
	},
	decorateFn = {
		linkAsStatic	= atool.decorateStaticLibList,
		linkAsShared	= atool.decorateSharedLibList,
		rpath			= atool.decorateRPath,
	},
	endFlags = '-Wl,-Bdynamic',	-- always put this at the end
	separateSharedLibraryPaths = true,
	
	getsysflags = function(self, cfg)
		if cfg == nil then
			error('Missing cfg')
		end
		local cmdflags = {}
		
		if cfg.kind == premake.SHAREDLIB then
			if cfg.system == premake.MACOSX then
				table.insert(cmdflags, "-dynamiclib -flat_namespace")
			elseif cfg.system == premake.WINDOWS and not cfg.flags.NoImportLib then
				table.insert(cmdflags, '-shared -Wl,--out-implib="' .. cfg.linktarget.fullpath .. '"')
			else
				table.insert(cmdflags, "-shared")
			end
		end
		
		if cfg.flags.Threading == 'Multi' then
			if cfg.system == premake.SOLARIS then
				table.insert(cmdflags, '-pthread -lrt')
			elseif cfg.system == 'bsd' then
				table.insert(cmdflags, '-pthread -lrt')
			elseif cfg.system ~= premake.WINDOWS then
				table.insert(cmdflags, '-pthread -lrt')
			end
		end

		return table.concat(cmdflags, ' ')
	end	
}
newtoolset {
	toolsetName = 'gcc', 
	tools = { gcc_cc, gcc_cxx, gcc_ar, gcc_link },
}
