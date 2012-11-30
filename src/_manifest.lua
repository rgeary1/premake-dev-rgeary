--
-- _manifest.lua
-- Manage the list of built-in Premake scripts.
-- Copyright (c) 2002-2012 Jason Perkins and the Premake project
--

-- The master list of built-in scripts. Order is important! If you want to
-- build a new script into Premake, add it to this list.

	return
	{
		-- core files
		"base/_declare.lua",
		"base/timer.lua",
		"base/cache.lua",
		"base/seq.lua",
		"base/os.lua",
		"base/path.lua",
		"base/string.lua",
		"base/table.lua",
		"base/io.lua",
		"base/globals.lua",
		"base/action.lua",
		"base/option.lua",
		"base/tree.lua",
		"base/api.lua",
		"base/toolset.lua",
		"base/cmdline.lua",
		"base/validate.lua",
		"base/help.lua",
		"base/premake.lua",
		"base/spelling.lua",
		
		-- Deprecated
		--[["base/project.lua",
		"base/config.lua",
		"base/bake.lua",
		]]
		-- project APIs
		"project/keyedblocks.lua",
		"base/globalcontainer.lua",
		"project/oven.lua",
		"project/project.lua",
		"project/config.lua",
		"base/solution.lua",

		-- tool APIs
		"tools/atool.lua",
		"tools/dotnet.lua",
		"tools/gcc.lua",
		"tools/msc.lua",
		"tools/ow.lua",
		"tools/snc.lua",
		"tools/icc.lua",
		"tools/protobuf.lua",

		-- Clean action
		"actions/clean/_clean.lua",

		--[[
		-- CodeBlocks action
		"actions/codeblocks/_codeblocks.lua",
		"actions/codeblocks/codeblocks_workspace.lua",
		"actions/codeblocks/codeblocks_cbp.lua",
		
		-- CodeLite action
		"actions/codelite/_codelite.lua",
		"actions/codelite/codelite_workspace.lua",
		"actions/codelite/codelite_project.lua",
		
		-- GNU make action
		"actions/make/_make.lua",
		"actions/make/make_solution.lua",
		"actions/make/make_cpp.lua",
		"actions/make/make_csharp.lua",
		
		-- Visual Studio actions
		"actions/vstudio/_vstudio.lua",
		"actions/vstudio/vs2002_solution.lua",
		"actions/vstudio/vs2002_csproj.lua",
		"actions/vstudio/vs2002_csproj_user.lua",
		"actions/vstudio/vs200x_vcproj.lua",
		"actions/vstudio/vs200x_vcproj_user.lua",
		"actions/vstudio/vs2003_solution.lua",
		"actions/vstudio/vs2005_solution.lua",
		"actions/vstudio/vs2005_csproj.lua",
		"actions/vstudio/vs2005_csproj_user.lua",
		"actions/vstudio/vs2010_vcxproj.lua",
		"actions/vstudio/vs2010_vcxproj_user.lua",
		"actions/vstudio/vs2010_vcxproj_filters.lua",
	
		-- Xcode action
		"actions/xcode/_xcode.lua",
		"actions/xcode/xcode_common.lua",
		"actions/xcode/xcode_project.lua",
		
		-- Xcode4 action
		"actions/xcode/xcode4_workspace.lua",
		]]
		
		-- Print action
		"actions/print/_print.lua",
		
		-- Release action
		"actions/release/_release.lua",

		-- Ninja build action
		"actions/ninja/_ninja.lua",
		"actions/ninja/ninja_solution.lua",
	}
