.PHONY: hygiene line-cap check-params gen-params gen-check

hygiene: line-cap check-params gen-check

line-cap:
	python3 tools/check_line_cap.py

check-params:
	python3 tools/validate_params.py

gen-params:
	python3 tools/gen_params.py

gen-check: gen-params
	git diff --exit-code -- 'proto-*/params.*'
