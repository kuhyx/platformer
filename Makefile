.PHONY: hygiene line-cap check-params gen-params gen-check

hygiene: line-cap check-params gen-check

# The shared 250-line gate (~/utils); CI runs the same checker from kuhyx/utils.
line-cap:
	scripts/check_file_length.sh --all

check-params:
	python3 tools/validate_params.py

gen-params:
	python3 tools/gen_params.py

gen-check: gen-params
	git diff --exit-code -- ':(glob)proto-*/params.json' ':(glob)proto-*/params.lua' ':(glob)proto-*/params.h'
