--
-- cmdline.lua
-- Functions to define and handle command line actions and options.
-- Copyright (c) 2002-2011 Jason Perkins and the Premake project
--


--
-- Built-in command line options
--

	newoption
	{
		trigger     = "file",
		value       = "FILE",
		description = "Read FILE as a Premake script; default is 'premake4.lua'"
	}
	
	newoption
	{
		trigger     = "help",
		description = "Display this information"
	}
		
	newoption
	{
		trigger     = "scripts",
		value       = "path",
		description = "Search for premake scripts on the given path"
	}
	
	newoption
	{
		trigger     = "version",
		description = "Display version information"
	}
	
	newoption
	{
		trigger		= "debug",
		description = "Display full stack trace for errors"
	}
	
	newoption
	{
		trigger		= "attach",
		value		= "[ip]",
		description = "Attach to the Eclipse Koneki DBGp debugger. IP address optional."
	}

	newoption
	{
		trigger		= "attachNoWait",
		value		= "[ip]",
		description = "Try attaching to the debugger, but don't wait. IP address optional."
	}
	
	newoption
	{
		trigger		= "dryrun",
		description	= "Print the files which would be modified, but do not execute commands or make any changes to the file system",
	}
	
	newoption
	{
		trigger		= "profile",
		description	= "Run premake with timing enabled",
	}
	
	newoption
	{
		trigger		= "threads",
		value		= "#",
		description	= "If the action is also building the project, use this number of threads",
		aliases		= { 'j' },
	}
	
	newoption
	{
		trigger		= "automated",
		description = "Automated mode, no interaction available.",
		aliases 	= { 'a' },
	}
	
	newoption
	{
		trigger     = "absolutepaths",
		description = "Always generate absolute build paths",
	}
	
	newoption
	{
		trigger		= "reporoot",
		description	= "Sets the root directory of the codebase (repository). Build files can base relative paths from reporoot", 
	}
	
	newoption
	{
		trigger     = "systemScript",
		description = "Run a system script before the build script. Default filename is premake-system.lua.",
	}
	
	newoption {
		trigger 	= "quiet",
		description = "Don't print status messages",
	}
		
	newoption {
		trigger		= "interactive",
		description = "Interactive Lua shell with Premake loaded. Press Ctrl-C to exit.",
		aliases		= { "i" },
	}
	
	newoption {
		trigger		= "nobuild",
		description = "Don't build the project, just generate the build scripts",
		aliases		= { "n" },
	}

	newoption {
		trigger		= "define",
		value		= "\"Define1 Define2 ...\"",
		description = ' Build all projects with variant define { "Define1", "Define2", ... }',
		aliases 	= { "d" },
	}
	newoption {
		trigger 	= "toolset",
		value 		= "name",
		description = "Set the toolset",
	}
	newoption {
		trigger 	= "config",
		value 		= "name",
		description = "Set the configurations",
	}
	newoption {
		trigger		= "projectset",
		value		= "set1,set2,...",
		description = " Only include projects in these project sets. Use \"default\" for projects where projectset is undefined, \"export\" for exported projects.",
	}
	newoption {
		trigger 	= "defaultbuildfile",
		value		= "premakeFile.lua",
		description = "Unless otherwise specified, only build projects listed in this premake file (& dependencies)",
		hide		= true,
	}
	newoption {
		trigger		= "releasedir",
		value		= "path",
		description	= "Destination root path to copy the release",
	}
	newoption {
		trigger     = "releaseCopy",
		description = "Release a copy of the files, not a symlink",
	}