

newaction {
	trigger = "premakeTimingTests",
	description = "Run performance tests on some small Premake functions",
	isnextgen = true,
	ishelp = true,			-- don't bake the projects
	execute = function()
		if not _OPTIONS['profile'] then
			error("Run with --profile")
		end
		timer.runTests()	
	end	
}