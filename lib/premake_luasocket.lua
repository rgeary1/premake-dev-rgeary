function lib(name)
	project(name)
		kind "SharedLib"
end

solution "luasocket"

flags "Optimize=Speed"

configuration "SharedLib"
	targetprefix ""

configuration "debug"
	defines "LUASOCKET_DEBUG"

configuration "macos"
	linkerwrapper 'export MACOSX_DEPLOYMENT_TARGET="10.3"; '
	linkflags "-bundle -undefined dynamic_lookup"
	cflags "-pedantic -fno-common"
	flags "Warnings=Extra"
	defines { "LUASOCKET_DEBUG", "UNIX_HAS_SUN_LEN" }
	
configuration "linux"
	flags "fPIC"
	
configuration "windows"
	-- untested.

usage "debugger"
	files "debugger.lua"
	uses "socket mime lfs"

-- Default build targets
export( "socket", "luasocket/socket" )
export( "mime", "luasocket/mime" )

include "./src"
include "./lfs"
