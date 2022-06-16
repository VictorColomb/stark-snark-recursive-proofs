p := 52435875175126190479447740508185965837690552500527637822603658699938581184513
dbg_p := 18446744073709551359

gen_constants:
	python3 generate_parameters_grain.sage.py 1 0 255 5 8 60 ${p} > param.rs

dbg:
	python3 generate_parameters_grain.sage.py 1 0 64 24 8 42 ${dbg_p} > param.txt
