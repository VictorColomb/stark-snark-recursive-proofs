
from sage.all_cmdline import *   # import sage library

_sage_const_7 = Integer(7); _sage_const_1 = Integer(1); _sage_const_2 = Integer(2); _sage_const_3 = Integer(3); _sage_const_4 = Integer(4); _sage_const_5 = Integer(5); _sage_const_6 = Integer(6); _sage_const_0 = Integer(0); _sage_const_8 = Integer(8); _sage_const_160 = Integer(160); _sage_const_62 = Integer(62); _sage_const_51 = Integer(51); _sage_const_38 = Integer(38); _sage_const_23 = Integer(23); _sage_const_13 = Integer(13); _sage_const_12 = Integer(12); _sage_const_10 = Integer(10); _sage_const_30 = Integer(30)# Remark: This script contains functionality for GF(2^n), but currently works only over GF(p)! A few small adaptations are needed for GF(2^n).
from sage.rings.polynomial.polynomial_gf2x import GF2X_BuildIrred_list

# Note that R_P is increased to the closest multiple of t
# GF(p), alpha=3, N = 1536, n = 64, t = 24, R_F = 8, R_P = 42: sage generate_parameters_grain.sage 1 0 64 24 8 42 0xfffffffffffffeff
# GF(p), alpha=5, N = 1524, n = 254, t = 6, R_F = 8, R_P = 60: sage generate_parameters_grain.sage 1 0 254 6 8 60 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
# GF(p), x^(-1), N = 1518, n = 253, t = 6, R_F = 8, R_P = 60: sage generate_parameters_grain.sage 1 1 253 6 8 60 0x1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed

# GF(p), alpha=5, N = 765, n = 255, t = 3, R_F = 8, R_P = 57: sage generate_parameters_grain.sage 1 0 255 3 8 57 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
# GF(p), alpha=5, N = 1275, n = 255, t = 5, R_F = 8, R_P = 60: sage generate_parameters_grain.sage 1 0 255 5 8 60 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
# GF(p), alpha=5, N = 762, n = 254, t = 3, R_F = 8, R_P = 57: sage generate_parameters_grain.sage 1 0 254 3 8 57 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001
# GF(p), alpha=5, N = 1270, n = 254, t = 5, R_F = 8, R_P = 60: sage generate_parameters_grain.sage 1 0 254 5 8 60 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001

# GF(2^n), alpha=5, N = 768, n = 256, t = 3, R_F = 8, R_P = 57: sage generate_parameters_grain.sage 0 0 256 3 8 57 0x0

if len(sys.argv) < _sage_const_7 :
    print("Usage: <script> <field> <s_box> <field_size> <num_cells> <R_F> <R_P> (<prime_number_hex>)")
    print("field = 1 for GF(p)")
    print("s_box = 0 for x^alpha, s_box = 1 for x^(-1)")
    exit()

# Parameters
FIELD = int(sys.argv[_sage_const_1 ]) # 0 .. GF(2^n), 1 .. GF(p)
SBOX = int(sys.argv[_sage_const_2 ]) # 0 .. x^alpha, 1 .. x^(-1)
FIELD_SIZE = int(sys.argv[_sage_const_3 ]) # n
NUM_CELLS = int(sys.argv[_sage_const_4 ]) # t
R_F_FIXED = int(sys.argv[_sage_const_5 ])
R_P_FIXED = int(sys.argv[_sage_const_6 ])
C = 2


INIT_SEQUENCE = []

PRIME_NUMBER = _sage_const_0 
if FIELD == _sage_const_1  and len(sys.argv) != _sage_const_8 :
    print("Please specify a prime number (in hex format)!")
    exit()
elif FIELD == _sage_const_1  and len(sys.argv) == _sage_const_8 :
    PRIME_NUMBER = int(sys.argv[_sage_const_7 ]) # BaseElement.g. 0xa7, 0xFFFFFFFFFFFFFEFF, 0xa1a42c3efd6dbfe08daa6041b36322ef
elif FIELD == _sage_const_0 :
    PRIME_NUMBER = GF(_sage_const_2 )['x'](GF2X_BuildIrred_list(FIELD_SIZE))

F = None
if FIELD == _sage_const_1 :
    F = GF(PRIME_NUMBER)
elif FIELD == _sage_const_0 :
    F = GF(_sage_const_2 **FIELD_SIZE, name='x', modulus = PRIME_NUMBER, names=('x',)); (x,) = F._first_ngens(1)

def to_u256(b):
    string = "BaseElement(U256("
    t = []
    a = int(b)
    while a != 0:
        t.append(a%(2**64))
        a//=2**64
    while len(t) != 4:
        t.append(0)
    string += str(t)
    string += "))"
    return string


def grain_sr_generator():
    bit_sequence = INIT_SEQUENCE
    for _ in range(_sage_const_0 , _sage_const_160 ):
        new_bit = bit_sequence[_sage_const_62 ] ^ bit_sequence[_sage_const_51 ] ^ bit_sequence[_sage_const_38 ] ^ bit_sequence[_sage_const_23 ] ^ bit_sequence[_sage_const_13 ] ^ bit_sequence[_sage_const_0 ]
        bit_sequence.pop(_sage_const_0 )
        bit_sequence.append(new_bit)
        
    while True:
        new_bit = bit_sequence[_sage_const_62 ] ^ bit_sequence[_sage_const_51 ] ^ bit_sequence[_sage_const_38 ] ^ bit_sequence[_sage_const_23 ] ^ bit_sequence[_sage_const_13 ] ^ bit_sequence[_sage_const_0 ]
        bit_sequence.pop(_sage_const_0 )
        bit_sequence.append(new_bit)
        while new_bit == _sage_const_0 :
            new_bit = bit_sequence[_sage_const_62 ] ^ bit_sequence[_sage_const_51 ] ^ bit_sequence[_sage_const_38 ] ^ bit_sequence[_sage_const_23 ] ^ bit_sequence[_sage_const_13 ] ^ bit_sequence[_sage_const_0 ]
            bit_sequence.pop(_sage_const_0 )
            bit_sequence.append(new_bit)
            new_bit = bit_sequence[_sage_const_62 ] ^ bit_sequence[_sage_const_51 ] ^ bit_sequence[_sage_const_38 ] ^ bit_sequence[_sage_const_23 ] ^ bit_sequence[_sage_const_13 ] ^ bit_sequence[_sage_const_0 ]
            bit_sequence.pop(_sage_const_0 )
            bit_sequence.append(new_bit)
        new_bit = bit_sequence[_sage_const_62 ] ^ bit_sequence[_sage_const_51 ] ^ bit_sequence[_sage_const_38 ] ^ bit_sequence[_sage_const_23 ] ^ bit_sequence[_sage_const_13 ] ^ bit_sequence[_sage_const_0 ]
        bit_sequence.pop(_sage_const_0 )
        bit_sequence.append(new_bit)
        yield new_bit
grain_gen = grain_sr_generator()
        
def grain_random_bits(num_bits):
    random_bits = [next(grain_gen) for i in range(_sage_const_0 , num_bits)]
    # random_bits.reverse() ## Remove comment to start from least significant bit
    random_int = int("".join(str(i) for i in random_bits), _sage_const_2 )
    return random_int

def init_generator(field, sbox, n, t, R_F, R_P):
    # Generate initial sequence based on parameters
    bit_list_field = [_ for _ in (bin(FIELD)[_sage_const_2 :].zfill(_sage_const_2 ))]
    bit_list_sbox = [_ for _ in (bin(SBOX)[_sage_const_2 :].zfill(_sage_const_4 ))]
    bit_list_n = [_ for _ in (bin(FIELD_SIZE)[_sage_const_2 :].zfill(_sage_const_12 ))]
    bit_list_t = [_ for _ in (bin(NUM_CELLS)[_sage_const_2 :].zfill(_sage_const_12 ))]
    bit_list_R_F = [_ for _ in (bin(R_F)[_sage_const_2 :].zfill(_sage_const_10 ))]
    bit_list_R_P = [_ for _ in (bin(R_P)[_sage_const_2 :].zfill(_sage_const_10 ))]
    bit_list_1 = [_sage_const_1 ] * _sage_const_30 
    global INIT_SEQUENCE
    INIT_SEQUENCE = bit_list_field + bit_list_sbox + bit_list_n + bit_list_t + bit_list_R_F + bit_list_R_P + bit_list_1
    INIT_SEQUENCE = [int(_) for _ in INIT_SEQUENCE]

def generate_constants(field, n, t, R_F, R_P, prime_number):
    round_constants = []
    num_constants = (R_F + R_P) * t

    if field == _sage_const_0 :
        for i in range(_sage_const_0 , num_constants):
            random_int = grain_random_bits(n)
            round_constants.append(random_int)
    elif field == _sage_const_1 :
        for i in range(_sage_const_0 , num_constants):
            random_int = grain_random_bits(n)
            while random_int >= prime_number:
                # print("[Info] Round constant is not in prime field! Taking next one.")
                random_int = grain_random_bits(n)
            round_constants.append(random_int)
    return round_constants

def print_round_constants(round_constants, n, field):
    print("pub const ROUND_CONSTANTS: [BaseElement;",len(round_constants),"] =",str([to_u256(entry) for entry in round_constants]).replace("'",""),";\n")

def create_mds_p(n, t):
    M = matrix(F, t, t)

    # Sample random distinct indices and assign to xs and ys
    while True:
        flag = True
        rand_list = [F(grain_random_bits(n)) for _ in range(_sage_const_0 , _sage_const_2 *t)]
        while len(rand_list) != len(set(rand_list)): # Check for duplicates
            rand_list = [F(grain_random_bits(n)) for _ in range(_sage_const_0 , _sage_const_2 *t)]
        xs = rand_list[:t]
        ys = rand_list[t:]
        # xs = [F(ele) for ele in range(0, t)]
        # ys = [F(ele) for ele in range(t, 2*t)]
        for i in range(_sage_const_0 , t):
            for j in range(_sage_const_0 , t):
                if (flag == False) or ((xs[i] + ys[j]) == _sage_const_0 ):
                    flag = False
                else:
                    entry = (xs[i] + ys[j])**(-_sage_const_1 )
                    M[i, j] = entry
        if flag == False:
            continue
        return M

def create_mds_gf2n(n, t):
    M = matrix(F, t, t)

    # Sample random distinct indices and assign to xs and ys
    while True:
        flag = True
        rand_list = [F.fetch_int(grain_random_bits(n)) for _ in range(_sage_const_0 , _sage_const_2 *t)]
        while len(rand_list) != len(set(rand_list)): # Check for duplicates
            rand_list = [F.fetch_int(grain_random_bits(n)) for _ in range(_sage_const_0 , _sage_const_2 *t)]
        xs = rand_list[:t]
        ys = rand_list[t:]
        for i in range(_sage_const_0 , t):
            for j in range(_sage_const_0 , t):
                if (flag == False) or ((xs[i] + ys[j]) == _sage_const_0 ):
                    flag = False
                else:
                    entry = (xs[i] + ys[j])**(-_sage_const_1 )
                    M[i, j] = entry
        if flag == False:
            continue
        return M

def generate_vectorspace(round_num, M, M_round, NUM_CELLS):
    t = NUM_CELLS
    s = _sage_const_1 
    V = VectorSpace(F, t)
    if round_num == _sage_const_0 :
        return V
    elif round_num == _sage_const_1 :
        return V.subspace(V.basis()[s:])
    else:
        mat_temp = matrix(F)
        for i in range(_sage_const_0 , round_num-_sage_const_1 ):
            add_rows = []
            for j in range(_sage_const_0 , s):
                add_rows.append(M_round[i].rows()[j][s:])
            mat_temp = matrix(mat_temp.rows() + add_rows)
        r_k = mat_temp.right_kernel()
        extended_basis_vectors = []
        for vec in r_k.basis():
            extended_basis_vectors.append(vector([_sage_const_0 ]*s + list(vec)))
        S = V.subspace(extended_basis_vectors)

        return S

def subspace_times_matrix(subspace, M, NUM_CELLS):
    t = NUM_CELLS
    V = VectorSpace(F, t)
    subspace_basis = subspace.basis()
    new_basis = []
    for vec in subspace_basis:
        new_basis.append(M * vec)
    new_subspace = V.subspace(new_basis)
    return new_subspace

# Returns True if the matrix is considered secure, False otherwise
def algorithm_1(M, NUM_CELLS):
    t = NUM_CELLS
    s = _sage_const_1 
    r = floor((t - s) / float(s))

    # Generate round matrices
    M_round = []
    for j in range(_sage_const_0 , t+_sage_const_1 ):
        M_round.append(M**(j+_sage_const_1 ))

    for i in range(_sage_const_1 , r+_sage_const_1 ):
        mat_test = M**i
        entry = mat_test[_sage_const_0 , _sage_const_0 ]
        mat_target = matrix.circulant(vector([entry] + ([F(_sage_const_0 )] * (t-_sage_const_1 ))))

        if (mat_test - mat_target) == matrix.circulant(vector([F(_sage_const_0 )] * (t))):
            return [False, _sage_const_1 ]

        S = generate_vectorspace(i, M, M_round, t)
        V = VectorSpace(F, t)

        basis_vectors= []
        for eigenspace in mat_test.eigenspaces_right(format='galois'):
            if (eigenspace[_sage_const_0 ] not in F):
                continue
            vector_subspace = eigenspace[_sage_const_1 ]
            intersection = S.intersection(vector_subspace)
            basis_vectors += intersection.basis()
        IS = V.subspace(basis_vectors)

        if IS.dimension() >= _sage_const_1  and IS != V:
            return [False, _sage_const_2 ]
        for j in range(_sage_const_1 , i+_sage_const_1 ):
            S_mat_mul = subspace_times_matrix(S, M**j, t)
            if S == S_mat_mul:
                print("S.basis():\n", S.basis())
                return [False, _sage_const_3 ]

    return [True, _sage_const_0 ]

# Returns True if the matrix is considered secure, False otherwise
def algorithm_2(M, NUM_CELLS):
    t = NUM_CELLS
    s = _sage_const_1 

    V = VectorSpace(F, t)
    trail = [None, None]
    test_next = False
    I = range(_sage_const_0 , s)
    I_powerset = list(sage.misc.misc.powerset(I))[_sage_const_1 :]
    for I_s in I_powerset:
        test_next = False
        new_basis = []
        for l in I_s:
            new_basis.append(V.basis()[l])
        IS = V.subspace(new_basis)
        for i in range(s, t):
            new_basis.append(V.basis()[i])
        full_iota_space = V.subspace(new_basis)
        for l in I_s:
            v = V.basis()[l]
            while True:
                delta = IS.dimension()
                v = M * v
                IS = V.subspace(IS.basis() + [v])
                if IS.dimension() == t or IS.intersection(full_iota_space) != IS:
                    test_next = True
                    break
                if IS.dimension() <= delta:
                    break
            if test_next == True:
                break
        if test_next == True:
            continue
        return [False, [IS, I_s]]

    return [True, None]

# Returns True if the matrix is considered secure, False otherwise
def algorithm_3(M, NUM_CELLS):
    t = NUM_CELLS
    s = _sage_const_1 

    V = VectorSpace(F, t)

    l = _sage_const_4 *t
    for r in range(_sage_const_2 , l+_sage_const_1 ):
        next_r = False
        res_alg_2 = algorithm_2(M**r, t)
        if res_alg_2[_sage_const_0 ] == False:
            return [False, None]

        # if res_alg_2[1] == None:
        #     continue
        # IS = res_alg_2[1][0]
        # I_s = res_alg_2[1][1]
        # for j in range(1, r):
        #     IS = subspace_times_matrix(IS, M, t)
        #     I_j = []
        #     for i in range(0, s):
        #         new_basis = []
        #         for k in range(0, t):
        #             if k != i:
        #                 new_basis.append(V.basis()[k])
        #         iota_space = V.subspace(new_basis)
        #         if IS.intersection(iota_space) != iota_space:
        #             single_iota_space = V.subspace([V.basis()[i]])
        #             if IS.intersection(single_iota_space) == single_iota_space:
        #                 I_j.append(i)
        #             else:
        #                 next_r = True
        #                 break
        #     if next_r == True:
        #         break
        # if next_r == True:
        #     continue
        # return [False, [IS, I_j, r]]
    
    return [True, None]

def generate_matrix(FIELD, FIELD_SIZE, NUM_CELLS):
    if FIELD == _sage_const_0 :
        mds_matrix = create_mds_gf2n(FIELD_SIZE, NUM_CELLS)
        result_1 = algorithm_1(mds_matrix, NUM_CELLS)
        result_2 = algorithm_2(mds_matrix, NUM_CELLS)
        result_3 = algorithm_3(mds_matrix, NUM_CELLS)
        while result_1[_sage_const_0 ] == False or result_2[_sage_const_0 ] == False or result_3[_sage_const_0 ] == False:
            mds_matrix = create_mds_p(FIELD_SIZE, NUM_CELLS)
            result_1 = algorithm_1(mds_matrix, NUM_CELLS)
            result_2 = algorithm_2(mds_matrix, NUM_CELLS)
            result_3 = algorithm_3(mds_matrix, NUM_CELLS)
        return mds_matrix
    elif FIELD == _sage_const_1 :
        mds_matrix = create_mds_p(FIELD_SIZE, NUM_CELLS)
        result_1 = algorithm_1(mds_matrix, NUM_CELLS)
        result_2 = algorithm_2(mds_matrix, NUM_CELLS)
        result_3 = algorithm_3(mds_matrix, NUM_CELLS)
        while result_1[_sage_const_0 ] == False or result_2[_sage_const_0 ] == False or result_3[_sage_const_0 ] == False:
            mds_matrix = create_mds_p(FIELD_SIZE, NUM_CELLS)
            result_1 = algorithm_1(mds_matrix, NUM_CELLS)
            result_2 = algorithm_2(mds_matrix, NUM_CELLS)
            result_3 = algorithm_3(mds_matrix, NUM_CELLS)
        return mds_matrix

def print_linear_layer(M, n, t):
    print("pub const T : usize = ", t,";\n")
    print("pub const R_F : usize = ", R_F_FIXED,";")
    print("pub const R_P : usize = ", R_P_FIXED,";")
    if not algorithm_1(M, NUM_CELLS) and algorithm_2(M, NUM_CELLS) and algorithm_3(M, NUM_CELLS):
        print("Unsafe MDS")
        exit()
    hex_length = int(ceil(float(n) / _sage_const_4 )) + _sage_const_2  # +2 for "0x"

    matrix_string = "["
    for i in range(_sage_const_0 , t):
        if FIELD == _sage_const_0 :
            matrix_string += str([to_u256(entry) for entry in M[i]]).replace("'","")
        elif FIELD == _sage_const_1 :
            matrix_string += str([to_u256(entry) for entry in M[i]]).replace("'","")
        if i < (t-_sage_const_1 ):
            matrix_string += ","
    matrix_string = matrix_string
    matrix_string = matrix_string
    print("pub const MDS: [[BaseElement; T];T]  = ", matrix_string,"];\n")

# Init
print("use math::fields::f256::{BaseElement,U256};")

def TYPE(i):
    return str("BaseElement::new("+str(i)+")") 
init_generator(FIELD, SBOX, FIELD_SIZE, NUM_CELLS, R_F_FIXED, R_P_FIXED)

# Round constants
round_constants = generate_constants(FIELD, FIELD_SIZE, NUM_CELLS, R_F_FIXED, R_P_FIXED, PRIME_NUMBER)

# Matrix
linear_layer = generate_matrix(FIELD, FIELD_SIZE, NUM_CELLS)


print_linear_layer(linear_layer, FIELD_SIZE, NUM_CELLS)
print_round_constants(round_constants, FIELD_SIZE, FIELD)

print("pub const RATE : usize = ",NUM_CELLS - C,";\n")
print("pub const ALPHA : u32 = ", 5 ,";\n")





