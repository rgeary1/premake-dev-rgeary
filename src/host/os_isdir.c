/**
 * \file   os_isdir.c
 * \brief  Returns true if the specified directory exists.
 * \author Copyright (c) 2002-2008 Jason Perkins and the Premake project
 */

#include <string.h>
#include <sys/stat.h>
#include "premake.h"
#if PLATFORM_LINUX || PLATFORM_BSD || PLATFORM_SOLARIS
#  include <unistd.h>
#endif

int os_isdir(lua_State* L)
{
	struct stat buf;
	const char* path = luaL_checkstring(L, 1);

	/* empty path is equivalent to ".", must be true */
	if (strlen(path) == 0)
	{
		lua_pushboolean(L, 1);
	}
	else if (stat(path, &buf) == 0)
	{
		lua_pushboolean(L, buf.st_mode & S_IFDIR);
	}
	else
	{
		lua_pushboolean(L, 0);
	}

	return 1;
}

/* Return the real path of a symbolic link */
int os_get_symlink_target(lua_State* L)
{
#if PLATFORM_LINUX || PLATFORM_BSD || PLATFORM_SOLARIS
	#if !defined(PATH_MAX)
	#define PATH_MAX  (4096)
	#endif

	char realpath[PATH_MAX];
	const char* path = luaL_checkstring(L, 1);

	int len = readlink(path, realpath, PATH_MAX-1);
	if (len > 0)
	{
		realpath[len] = '\0';
		lua_pushstring(L, realpath);
		return 1;
	}

	return 0;
#else
	return 0;
#endif
}
