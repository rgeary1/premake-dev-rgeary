--
-- New file path class
--

premake.Path = premake.Path or {}
local Path = premake.Path

function Path.registerFile(fileAndDir)
	local filename, dir
	if fileAndDir:match("[\\/]") then
		dir, filename = fileAndDir:match("^(.*)[/\\]([^/]*)")
	else
	end
end

local allData = {
	files = {},
	fullpathToFilename = {},
	fullpathToDir = {},
	filesInDir = {},
	relativeDirs = {},		-- key='fromDir toDir' value=<as relative dir>
	
}