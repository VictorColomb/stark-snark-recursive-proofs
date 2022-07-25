use uint::construct_uint;
use super::u256::U256;

construct_uint! {
    /// 512-bit unsigned integer
    pub struct U512(8);
}

impl U512 {
    pub fn low_u256(&self) -> U256 {
        let mut slice = [0u64; 4];
        slice.copy_from_slice(&self.0[..4]);
        U256(slice)
    }
}

impl From<U256> for U512 {
    fn from(value: U256) -> Self {
        let mut slice = [0u64; 8];
        slice[..4].copy_from_slice(&value.0);
        Self(slice)
    }
}

#[cfg(test)]
mod tests {
    use super::{U256, U512};

    #[test]
    fn low_u256() {
        let a = U512([1, 2, 3, 4, 5, 6, 7, 8]);
        assert_eq!(
            a.low_u256(),
            U256([1, 2, 3, 4])
        );
    }
}