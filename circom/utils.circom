// TODO: find a faster exponentiation implementation

pragma circom 2.0.4;

include "./poseidon/poseidon.circom";

// b0 * a + (1 - b0)
template Pow(a) {
    signal input in;
    signal output out;

    signal inter[a - 1];

    if (a == 1) {
        out <== in;
    } else {
        inter[0] <== in * in;

        for (var i = 1; i < a - 1; i++) {
            inter[i] <== inter[i-1] * in;
        }


        out <== inter[a-2];
    }

}

template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc1=0;

    var e2=1;
    for (var i = 0; i<n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] -1 ) === 0;
        lc1 += out[i] * e2;
        e2 = e2+e2;
    }

    lc1 === in;
}

template RemoveDuplicates(input_len,output_len){
    signal input in[input_len];
    signal output out[output_len];
    var inter[output_len];

    // compute a list without duplicates
    var dup;
    var k = 0;
    for(var i = 0; i < input_len; i++){ 
        dup = 1;
        for (var j = 0; j < k; j++){
            dup *= in[i] - inter[j];
        }

        if(dup != 0 && k < output_len) {
            inter[k] = in[i];
            k += 1;
        }
    }

    // prove the elements of this list do come from the input
    // TODO: this only proves the elements are ok, implement the verification that the order is correct
    component mul[output_len - 1];
    out[0] <-- inter[0];
    out[0] === in[0];
    for (var i = 1; i < output_len; i++) {
        out[i] <-- inter[i];
        mul[i-1] = MultiplierN(input_len - 1);
        for (var j = 1; j < input_len; j++) {
            mul[i-1].in[j-1] <== out[i] - in[j];
        }
        mul[i-1].out === 0;
    }
}

template Multiplier2(){
   //Declaration of signals.
   signal input in1;
   signal input in2;
   signal output out;

   //Statements.
   out <== in1 * in2;
}

template MultiplierN (N){
   signal input in[N];
   signal output out;
   component comp[N-1];

   for(var i = 0; i < N-1; i++){
       comp[i] = Multiplier2();
   }
   comp[0].in1 <== in[0];
   comp[0].in2 <== in[1];
   for(var i = 0; i < N-2; i++){
       comp[i+1].in1 <== comp[i].out;
       comp[i+1].in2 <== in[i+2];

   }
   out <== comp[N-2].out; 
}


component main = RemoveDuplicates(500,5);