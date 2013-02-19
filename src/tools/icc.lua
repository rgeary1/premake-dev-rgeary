--
-- Intel Compiler toolset
--
local atool = premake.abstract.buildtool

local icc_cc = newtool {
	toolName = 'cc',
	binaryName = 'icpc',
	fixedFlags = '-c -xc',
	language = "C",
	
	-- possible inputs in to the compiler
	extensionsForCompiling = { ".c", },
	
	-- These are all for linux, windows flags are different
	flagMap = {
		AddPhonyHeaderDependency = "-MP",	 -- used by makefiles
		CreateDependencyFile = "-MMD",
		CreateDependencyFileIncludeSystem = "-MD",
		Inline = {
			Disabled 	= "-inline-level=0",
			ExplicitOnly = "-inline-level=1",
			Anything 	= "-inline-level=2",
		},
		-- InterProceduralOptimization
		IPO = {
			None			= '-no-ip',
			SingleFile		= '-ip',
			MultiFile		= '-ipo',
			MultiFile2		= '-ipo2',		-- use -ipo2 or higher if the compiler/linker is running out of memory 			
			MultiFile3		= '-ipo3',			
			MultiFile4		= '-ipo4',			
		},
		Language = {
			["Assembler"]	= "-x assembler",
			["AnsiC"]		= "-x c -ansi",
			["C"]			= "-x c",
			["C++"]			= "-x c++",
			["C++0x"]		= "-std=c++0x",
			["C99"]			= "-std=c99",
		},
		EnableSSE2     		= "-msse2",
		EnableSSE3     		= "-msse3",
		EnableSSE41    		= "-msse4.1",
		EnableSSE42    		= "-msse4.2",
		EnableAVX      		= "-mavx",
		Warnings = {
			Off				= "-w0",
			Extra			= "-Wall",
		},
		FatalWarnings  		= "-Werror",
		Float = {
			Fast		  	= "-fp-model fast=2",
			Strict			= "-fp-model strict",
		},
		-- Determines whether C++ class hierarchy information is used to analyze and resolve C++ virtual function calls at compile time
		OptClassAnalysis = {
		 	On 				= "-opt-class-analysis",
		 	Off 			= "-no-opt-class-analysis", 
		},
		Optimize = {
			Off				= "-O0",
			On				= "-O2",
			Size			= "-Os",
			Speed			= "-O3",
		},
		Profiling      		= "-pg",
		Symbols        		= "-g",
		fPIC 				= "-fPIC",
		VecReport = {
			["0"]   		= '-vec-report0',
			["1"]   		= '-vec-report1',
			["2"]   		= '-vec-report2',
			["3"]   		= '-vec-report3',
			["4"]   		= '-vec-report4',
			["5"]   		= '-vec-report5',
		},
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
local icc_cxx = newtool {
	inheritFrom = icc_cc,
	toolName = 'cxx',
	fixedFlags = '-c -xc++',
	language = "C++",

	-- possible inputs in to the compiler
	extensionsForCompiling = { ".cc", ".cpp", ".cxx", ".c" },
	
	prefixes = table.merge(icc_cc.prefixes, {
		cxxflags = '',
	}),
	
	flagMap = table.merge(icc_cc.flagMap, {
		NoExceptions   = "-fno-exceptions",
		NoRTTI         = "-fno-rtti",
	}),
}
local icc_asm = newtool {
	inheritFrom = icc_cxx,
	toolName = 'asm',
	language = "assembler",
	fixedFlags = '-c -x assembler-with-cpp',
	extensionsForCompiling = { '.s' },
	
	-- Filter out unhelpful messages when compiling .s files
	redirectStderr = true,
	filterStderr = {
		'<built-in>: warning: this is the location of the previous definition',
		'<command-line>: warning: "__GNUC_MINOR__" redefined',
		'<command-line>: warning: "__GNUC_PATCHLEVEL__" redefined',
	},
	
	prefixes = icc_cxx.prefixes,
	suffixes = icc_cxx.suffixes,
	-- Bug, only writes Makefile style depfiles. Just disable it.
	decorateFn = table.exceptKeys(icc_cxx.decorateFn, { 'depfileOutput' }),
	flagMap = table.exceptKeys(icc_cxx.flagMap, { 'CreateDependencyFile', 'CreateDependencyFileIncludeSystem', }),
}
local icc_ar = newtool {
	toolName = 'ar',
	binaryName = 'xiar',
	fixedFlags = 'rsc',
	extensionsForLinking = { '.o', '.a', '.so' },		-- possible inputs in to the linker
	
	redirectStderr = true,
--	filterStderr = { "xiar: executing " },
	--targetNamePrefix = 'lib',
}
local icc_link = newtool {
	toolName = 'link',
	binaryName = 'icpc',
	fixedFlags = iif( _OPTIONS['disable-linker-groups'], "", '-Wl,--start-group' ),
	extensionsForLinking = { '.o', '.a', '.so' },		-- possible inputs in to the linker
	flagMap = {
		AllowUndefinedSymbols = {
			No = "-Wl,--no-undefined",
		},
		Stdlib = {
			Shared		= '-shared-libgcc -shared-intel',
			Static		= '-static-libgcc -static-intel',		-- Might not work, test final binary with ldd. See http://www.trilithium.com/johan/2005/06/static-libstdc/
		},
		-- InterProceduralOptimization
		IPO = {
			None			= '-no-ip',
			SingleFile		= '-ip',
			MultiFile		= '-ipo',
			MultiFile2		= '-ipo2',		-- use -ipo2 or higher if the compiler/linker is running out of memory 			
			MultiFile3		= '-ipo3',			
			MultiFile4		= '-ipo4',			
		},
		Profiling		= "-pg",
		WholeArchive = "-Wl,--whole-archive",
	},
	prefixes = {
		libdirs 		= '-L',
		output 			= '-o',
		linkoptions		= '',
	},
	suffixes = {
	},
	decorateFn = {
		linkAsStatic	= atool.decorateStaticLibList,
		linkAsShared	= atool.decorateSharedLibList,
		rpath			= atool.decorateRPath
	},
	postbuild = function(cfg)
		if cfg.soversion and cfg.kind == premake.SHAREDLIB and cfg.system ~= premake.WINDOWS then
			local libnameVer = path.asRoot(cfg.linktarget.abspath)
			local libnameNoVer = libnameVer:sub(1,#libnameVer-#cfg.soversion-1)
			return {
				name = "symlink",
				description = "symlink "..libnameNoVer.." -> "..cfg.linktarget.name,
				commands = "ln -sf "..cfg.linktarget.name.." "..libnameNoVer,
				outputs = libnameNoVer,
			}
		end
		return nil
	end,

	separateSharedLibraryPaths = true,
	
	getsysflags = function(self, cfg)
		if cfg == nil then
			error('Missing cfg')
		end
		local cmdflags = {}
		
		if cfg.kind == premake.SHAREDLIB then
			local soname = cfg.linktarget.name
			if cfg.system == premake.MACOSX then
				table.insert(cmdflags, "-dynamiclib -flat_namespace -Wl,--soname="..soname)
			elseif cfg.system == premake.WINDOWS and not cfg.flags.NoImportLib then
				table.insert(cmdflags, '-shared -Wl,--out-implib="' .. cfg.linktarget.fullpath .. '"')
			else
				table.insert(cmdflags, "-shared -Wl,--soname="..soname)
			end
		end
		
		--[[
		if cfg.kind == premake.CONSOLEAPP then
			local intelLibDir = os.findlib('imf') 		-- Intel default libs
			if not intelLibDir then
				printDebug('Warning: Unable to find libimf')
			else
				local rpath = iif( intelLibDir, '-Wl,-rpath='..intelLibDir, '')
				table.insert(cmdflags, rpath)
			end
		end
		]]

		if cfg.flags.Threading == 'Multi' then
			if cfg.system ~= premake.WINDOWS then
				table.insert(cmdflags, '-pthread -lrt')
			end
		end

		return table.concat(cmdflags, ' ')
	end	
}
newtoolset {
	toolsetName = 'icc', 
	tools = { icc_cc, icc_cxx, icc_asm, icc_ar, icc_link },
}
newtoolset {
	toolsetName = 'icc11.1', 
	tools = { 
		newtool {
			inheritfrom = icc_cc,
			binaryName = 'icpc11.1',
		},
		newtool {
			inheritfrom = icc_cxx,
			binaryName = 'icpc11.1',
		},
		newtool {
			inheritfrom = icc_asm,
			binaryName = 'icpc11.1',
		},
		newtool {
			inheritfrom = icc_ar,
			binaryName = 'xiar11.1',
		},
		newtool {
			inheritfrom = icc_link,
			binaryName = 'icpc11.1',
		},
	}
}
newtoolset {
	toolsetName = 'icc12', 
	tools = { 
		newtool {
			inheritfrom = icc_cc,
			binaryName = 'icpc12',
		},
		newtool {
			inheritfrom = icc_cxx,
			binaryName = 'icpc12',
		},
		newtool {
			inheritfrom = icc_asm,
			binaryName = 'icpc12',
		},
		newtool {
			inheritfrom = icc_ar,
			binaryName = 'xiar12',
		},
		newtool {
			inheritfrom = icc_link,
			binaryName = 'icpc12',
		},
	}
}
newtoolset {
	toolsetName = 'icc12.1', 
	tools = { 
		newtool {
			inheritfrom = icc_cc,
			binaryName = 'icpc12.1',
		},
		newtool {
			inheritfrom = icc_cxx,
			binaryName = 'icpc12.1',
		},
		newtool {
			inheritfrom = icc_asm,
			binaryName = 'icpc12.1',
		},
		newtool {
			inheritfrom = icc_ar,
			binaryName = 'xiar12.1',
		},
		newtool {
			inheritfrom = icc_link,
			binaryName = 'icpc12.1',
		},
	}
}
newtoolset {
	toolsetName = 'icc13', 
	tools = { 
		newtool {
			inheritfrom = icc_cc,
			binaryName = 'icpc13',
		},
		newtool {
			inheritfrom = icc_cxx,
			binaryName = 'icpc13',
		},
		newtool {
			inheritfrom = icc_asm,
			binaryName = 'icpc13',
		},
		newtool {
			inheritfrom = icc_ar,
			binaryName = 'xiar13',
		},
		newtool {
			inheritfrom = icc_link,
			binaryName = 'icpc13',
		},
	}
}
