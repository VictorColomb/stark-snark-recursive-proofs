use super::param::*;
use super::poseidon;
use math::fields::f256::{BaseElement, U256};
use math::FieldElement;
use rand_utils::rand_array;

#[test]
fn test_sbox() {
    let state: [BaseElement; T] = rand_array();

    let mut expected = state.clone();
    expected.iter_mut().for_each(|v| *v = v.exp(ALPHA.into()));

    let mut actual = state;
    poseidon::apply_sbox(&mut actual);
    println!("{:?}", actual);
    assert_eq!(expected, actual);
}

#[test]
fn test_mds() {
    let mut state = element_vec(T, &|i| i);

    poseidon::apply_mds(&mut state);

    // expected values are obtained by executing sage reference implementation code

    let expected = [
        BaseElement(U256::from(
            "0xf47a5b360b59a13893b68e1e358334e084358abf3aaa900833200a2c6d1d52d",
        )),
        BaseElement(U256::from(
            "0x19d0095e2c71ff7b76f932791481c7d71ef535a8ed962b52c7648d8171253db8",
        )),
        BaseElement(U256::from(
            "0x3213e05466d7d030b09f48ef6964560bda50374ac5457abac46b3423e3a1e571",
        )),
        BaseElement(U256::from(
            "0x3c962d6b4732a622c8fab64d4b246e851cf3521329c157b99d44bc416fd63f1b",
        )),
        BaseElement(U256::from(
            "0x5e5b33996c55d24b440db9eeae3ec2ca620f0a4774f0091fc5014d7b8ee26a82",
        )),
    ];
    assert_eq!(state, expected)
}

#[test]
fn test_constants() {
    let mut state = element_vec(T, &|i| i);

    poseidon::add_constants(&mut state, 0);

    // expected values are obtained by executing sage reference implementation code
    let expected = [
        BaseElement(U256::from(
            "0x5ee52b2f39e240a4006e97a15a7609dce42fa9aa510d11586a56db98fa925158",
        )),
        BaseElement(U256::from(
            "0x3e92829ce321755f769c6fd0d51e98262d7747ad553b028dbbe98b5274b9c8e2",
        )),
        BaseElement(U256::from(
            "0x7067b2b9b65af0519cef530217d4563543852399c2af1557fcd9eb325b5365e6",
        )),
        BaseElement(U256::from(
            "0x725e66aa00e406f247f00002487d092328c526f2f5a3c456004a71cea83845d8",
        )),
        BaseElement(U256::from(
            "0x72bf92303a9d433709d29979a296d98f147e8e7b8ed0cb452bd9f9508f6e4715",
        )),
    ];

    assert_eq!(state, expected);
}

#[test]
fn test_permutation() {
    let mut state = element_vec(T, &|i| i);

    // expected values are obtained by executing sage reference implementation code
    let expected = [
        BaseElement(U256::from(
            "0x2a918b9c9f9bd7bb509331c81e297b5707f6fc7393dcee1b13901a0b22202e18",
        )),
        BaseElement(U256::from(
            "0x65ebf8671739eeb11fb217f2d5c5bf4a0c3f210e3f3cd3b08b5db75675d797f7",
        )),
        BaseElement(U256::from(
            "0x2cc176fc26bc70737a696a9dfd1b636ce360ee76926d182390cdb7459cf585ce",
        )),
        BaseElement(U256::from(
            "0x4dc4e29d283afd2a491fe6aef122b9a968e74eff05341f3cc23fda1781dcb566",
        )),
        BaseElement(U256::from(
            "0x3ff622da276830b9451b88b85e6184fd6ae15c8ab3ee25a5667be8592cce3b1",
        )),
    ];
    poseidon::permutation(&mut state);
    dbg!(&state);
    assert_eq!(state, expected);
}

#[test]
fn test_hash() {
    let mut state = element_vec(T, &|i| i);

    poseidon::padder(&mut state);

    let output = poseidon::hash(&mut state);

    // expected values are obtained by executing sage reference implementation code
    let expected: [u8; 32] = [
        9, 86, 3, 12, 160, 105, 236, 249, 54, 3, 34, 207, 252, 122, 39, 91, 21, 156, 202, 4, 107,
        88, 95, 45, 61, 24, 40, 254, 16, 78, 58, 42,
    ];
    assert_eq!(expected, output);
}

//HELPER FUNCTION

fn element_vec(n: usize, f: &dyn Fn(usize) -> usize) -> Vec<BaseElement> {
    let mut vec = vec![];
    for i in 0usize..n {
        vec.push(BaseElement::from(f(i) as u128));
    }
    return vec;
}
