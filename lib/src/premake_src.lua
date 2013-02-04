		
lib "mime"
	soversion "1.0.2"
	files "mime.c"

lib "unix"
	configuration "macos or linux"
		files { 
			"buffer.c",
			"auxiliar.c",
			"options.c",
			"timeout.c",
			"io.c",
			"usocket.c",
			"unix.c",
		}
	
lib "socket"
	soversion "2.0.2"
	files {
		"luasocket.c",
		"timeout.c",
		"buffer.c",
		"io.c",
		"auxiliar.c",
		"options.c",
		"inet.c",
		"tcp.c",
		"udp.c",
		"except.c",
		"select.c",
		"usocket.c",
	}
	

