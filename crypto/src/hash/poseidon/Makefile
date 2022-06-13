p := 52435875175126190479447740508185965837690552500527637822603658699938581184513

gen_constants:
	python3 generate_parameters_grain.sage.py 1 0 255 3 8 57 ${p} > param.rs

test:
	python3 test_parameters.py 1 0 255 3 8 57 ${p} > param.txt