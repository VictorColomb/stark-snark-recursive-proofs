"""
For the query positions we draw values from PRNG until we get as many unique values as specified by num_queries
As checking if for dupplicates would be of quadratic complexity drawing 1000 values would generate 1 000 000 constraints
The following function gives us the number of times we have to drawo to obtain a 2**-128 probability of drawing enough values
"""
from math import factorial


DOMAIN_SIZE = 128
NUM_QUERIES = 32

def step(x,n,memo = {}):
    if not (x,n) in memo.keys():
        if x == NUM_QUERIES:
            memo[(x,n)] = 1
        elif n == 0:
            memo[(x,n)] = 0
        else:
            memo[(x,n)] = (((DOMAIN_SIZE - x )/ DOMAIN_SIZE) * step(x+1, n-1) + x / DOMAIN_SIZE * step(x, n-1))
    return memo[(x,n)]

t = 0
while (1 - step(0,t))/2**-128  > 1 :
    t += 1
print(t)