extends "res://tools/biome_extensions/check_all.gd"
func run()->void:
	var marker:String=OS.get_environment("PREDATOR_TEST_ENGINE_FIXED_FPS");var expected:String="none"
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("expected-fps="):expected=argument.trim_prefix("expected-fps=")
	check(marker==expected,"Child-only explicit engine-mode marker matches independently declared test expectation");print("ENGINE_MODE marker=",marker," expected=",expected," failures=",failures);quit(0 if failures.is_empty() else 1)
