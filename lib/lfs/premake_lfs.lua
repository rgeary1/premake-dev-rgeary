
lib "lfs"
	files "src/lfs.c"
	
	configuration "windows"
		linkflags "/def:src\lfs.def"
	
