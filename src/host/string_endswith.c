/**
 * \file   string_endswith.c
 * \brief  Determines if a string ends with the given sequence.
 * \author Copyright (c) 2002-2009 Jason Perkins and the Premake project
 */

#include "premake.h"
#include <string.h>

int string_startswith(lua_State* L)
{
	const char* haystack = luaL_optstring(L, 1, NULL);
	const char* needle   = luaL_optstring(L, 2, NULL);

	if (haystack && needle)
	{
		int nlen = strlen(needle);
		lua_pushboolean(L, strncmp(haystack, needle, nlen) == 0);
		return 1;
	}

	return 0;
}

int string_endswith(lua_State* L)
{
	const char* haystack = luaL_optstring(L, 1, NULL);
	const char* needle   = luaL_optstring(L, 2, NULL);

	if (haystack && needle)
	{
		int hlen = strlen(haystack);
		int nlen = strlen(needle);
		if (hlen >= nlen) 
		{
			lua_pushboolean(L, strcmp(haystack + hlen - nlen, needle) == 0);
			return 1;
		}
	}

	return 0;
}

/* From FNV-1 64bit hash function http://isthe.com/chongo/src/fnv/hash_64.c */
int string_createhashU(lua_State* L)
{
	const char* str = luaL_optstring(L, 1, NULL);

	if (str)
	{
		unsigned long long hval = 0ULL;
		int i;

		for(i=0; str[i] != '\0'; ++i)
		{
			hval += (hval << 1) + (hval << 4) + (hval << 5) +
					(hval << 7) + (hval << 8) + (hval << 40);
			hval ^= (unsigned long long)str[i];
		}
		lua_pushlightuserdata(L, (void*)hval);
		return 1;
	}

	return 0;
}

/* From FNV-1 64bit hash function http://isthe.com/chongo/src/fnv/hash_64.c */
int string_createhash(lua_State* L)
{
	const char* str = luaL_optstring(L, 1, NULL);

	if (str)
	{
		unsigned long long hval = 0ULL;
		int i;

		for(i=0; str[i] != '\0'; ++i)
		{
			hval += (hval << 1) + (hval << 4) + (hval << 5) +
					(hval << 7) + (hval << 8) + (hval << 40);
			hval ^= (unsigned long long)str[i];
		}
		lua_pushinteger(L, hval);
		return 1;
	}

	return 0;
}

/* From FNV-1 64bit hash function http://isthe.com/chongo/src/fnv/hash_64.c */
int string_createhashS(lua_State* L)
{
	const char* str = luaL_optstring(L, 1, NULL);

	if (str)
	{
		unsigned long long hval = 0ULL;
		int i;

		for(i=0; str[i] != '\0'; ++i)
		{
			hval += (hval << 1) + (hval << 4) + (hval << 5) +
					(hval << 7) + (hval << 8) + (hval << 40);
			hval ^= (unsigned long long)str[i];
		}
		char hashStr[21];
		sprintf(hashStr, "%020llX", hval);
		lua_pushlstring(L, hashStr, 20);
		return 1;
	}

	return 0;
}
