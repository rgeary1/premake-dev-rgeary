--
-- Premake 4.x build configuration script
-- 

-- For Backwards compatibility
	local function checkFn(name) 
		if not rawget(_G, name) then 
			_G[name] = function() end
		end
	end
	checkFn("ninjaBuildDir")
	checkFn("uses")
	checkFn("buildrule")
	checkFn("toolset")

-- Enable JIT with --jit option
newoption {
	trigger = "jit",
	description = "Build Premake to use LuaJIT",
}

-- Include luasocket
include "./lib"

--
-- Define the project. Put the release configuration first so it will be the
-- default when folks build using the makefile. That way they don't have to 
-- worry about the /scripts argument and all that.
--

	solution "Premake4"
		if _OPTIONS['jit'] then
			configurations { "DebugJIT", "ReleaseJIT" }
		else
			configurations { "Release", "Debug", }
		end
		
		location ( _OPTIONS["to"] )
	
	project "Premake4"
		targetname  "premake4"
		language    "C"
		kind        "ConsoleApp"
		flags       { "No64BitChecks", "ExtraWarnings" }	
		ninjaBuildDir "."

		files 
		{
			"*.txt", "**.lua", 
			"src/**.h", "src/**.c",
			"src/host/scripts.c"
		}

		excludes
		{
			--"src/host/lua-5.1.4/src/lua.c",
			"src/host/lua-5.1.4/src/luac.c",
			"src/host/lua-5.1.4/src/print.c",
			"src/host/lua-5.1.4/**.lua",
			"src/host/lua-5.1.4/etc/*.c"
		}
			
		configuration "Debug"
			includedirs { "src/host/lua-5.1.4/src" }
			defines     "_DEBUG"
			flags       { "Symbols" }
			uses "luasocket/debugger"
			
		configuration "Release"
			includedirs { "src/host/lua-5.1.4/src" }
			defines     "NDEBUG"
			flags       { "OptimizeSpeed", "Symbols" }

		configuration "vs*"
			defines     { "_CRT_SECURE_NO_WARNINGS" }
		
		configuration "vs2005"
			defines	{"_CRT_SECURE_NO_DEPRECATE" }

		configuration "windows"
			defines "_WIN32"
			links { "ole32" }

		configuration "linux"
			defines     { "LUA_USE_LINUX", }
			links       { "m", "dl", "readline", "curses" } 

		configuration "bsd"
			defines     { "LUA_USE_POSIX", "LUA_USE_DLOPEN" }
			links       { "m" } 
			
		configuration "macosx"
			defines     { "LUA_USE_MACOSX" }
			links       { "CoreServices.framework" }
			
		configuration { "macosx", "gmake" }
			buildoptions { "-mmacosx-version-min=10.4" }
			linkoptions  { "-mmacosx-version-min=10.4" }

		configuration { "linux or bsd" }
			linkoptions { "-rdynamic" }
			
		configuration { "solaris" }
			linkoptions { "-Wl,--export-dynamic" }
			
	  -- Non LuaJIT configurations
	  configuration { "Debug or Release" }
			excludes "src/host/luajit-2.0/**.*"
			flags "StaticRuntime"

		-- LuaJIT configurations

		configuration { "DebugJIT or ReleaseJIT" }
			excludes { "src/host/lua-5.1.4/lua.c" }
			excludes { "src/host/lua-5.1.4/**.*" }
			excludes { "src/host/luajit-2.0/**.*" }
			includedirs { "src/host/luajit-2.0/src" }
			libdirs { "src/host/luajit-2.0/src" }
			links { "lua51" }			
			define "LUAJIT"

		configuration { "DebugJIT or ReleaseJIT", "vs*" }
			prebuildcommands
			{
				"cd src\\host\\luajit-2.0\\src\\",
				"msvcbuild.bat static"
			}
			
		configuration { "DebugJIT or ReleaseJIT", "not vs*" }
			prebuildcommands
			{
				"cd src\\host\\luajit-2.0\\",
				"make"
			}
			
		configuration "DebugJIT"
			defines     "_DEBUG"
			flags       { "Symbols" }
			
		configuration "ReleaseJIT"
			defines     "NDEBUG"
			flags       { "OptimizeSpeed", "Symbols" }
			

--
-- A more thorough cleanup.
--

	if _ACTION == "clean" then
		os.rmdir("bin")
		os.rmdir("build")
	end
	
	

--
-- Use the --to=path option to control where the project files get generated. I use
-- this to create project files for each supported toolset, each in their own folder,
-- in preparation for deployment.
--

	newoption {
		trigger = "to",
		value   = "path",
		description = "Set the output location for the generated files"
	}



--
-- Use the embed action to convert all of the Lua scripts into C strings, which 
-- can then be built into the executable. Always embed the scripts before creating
-- a release build.
--

	dofile("scripts/embed.lua")
	
	newaction {
		trigger     = "embed",
		isnextgen		= true,
		description = "Embed scripts in scripts.c; required before release builds",
		execute     = doembed
	}


--
-- Use the release action to prepare source and binary packages for a new release.
-- This action isn't complete yet; a release still requires some manual work.
--


	dofile("scripts/release.lua")
	
	newaction {
		trigger     = "release",
		description = "Prepare a new release (incomplete)",
		execute     = dorelease
	}
