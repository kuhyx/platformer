std = "luajit+love"
max_line_length = 100
max_code_line_length = 100
max_cyclomatic_complexity = 10
files["params.lua"] = { ignore = { "631" } } -- generated
files["spec"] = { std = "+busted" }
files["conf.lua"] = { read_globals = { love = { fields = { "_os" } } } }
exclude_files = { "node_modules/", "dist/", "build/" } -- vendored / build output
