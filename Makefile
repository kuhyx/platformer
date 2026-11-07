.PHONY: hygiene line-cap check-params gen-params gen-rooms gen-check

hygiene: line-cap check-params gen-check

# The shared 250-line gate (~/src/utils); CI runs the same checker from kuhyx/utils.
line-cap:
	scripts/check_file_length.sh --all

check-params:
	python3 tools/validate_params.py

gen-params:
	python3 tools/gen_params.py

gen-rooms:
	python3 tools/gen_rooms.py

gen-check: gen-params gen-rooms
	git diff --exit-code -- ':(glob)proto-*/params.json' ':(glob)proto-*/params.lua' ':(glob)proto-*/params.h' \
	  ':(glob)proto-*/rooms.json' ':(glob)proto-*/rooms.lua' ':(glob)proto-*/rooms.h'
