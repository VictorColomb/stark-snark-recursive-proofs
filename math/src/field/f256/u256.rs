use uint::construct_uint;

construct_uint! {
    /// 256-bit unsigned integer
    pub struct U256(4);
}

#[cfg(test)]
mod tests {
    use super::U256;

    #[test]
    fn add() {
        // a = 2^256 - 1
        let a = U256::max_value();
        // check overflowing add
        assert_eq!(a.overflowing_add(U256::from(1)).0, U256::zero());
    }

    #[test]
    fn low() {
        let a = [1, 1, 1, 1];
        let e = U256(a);

        assert_eq!(
            e.low_u128(),
            a[0] as u128 + ((a[1] as u128) << 64)
        );

        assert_eq!(
            (e >> 128).low_u128(),
            a[2] as u128 + ((a[3] as u128) << 64)
        )
    }
}
