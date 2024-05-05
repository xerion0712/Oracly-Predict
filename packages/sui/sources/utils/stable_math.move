
/// Necessary library for setting up and calculating a stablecoin pool.
/// The pool must have equal weights and relies on the formula k = x^3 * y + x * y^3, borrowed from
/// https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/move-examples/swap/sources/liquidity_pool.move

module legato::stable_math {

    use legato::math128;

    // Computes initial LP amount using the formula - total_share = sqrt( amount_x * amount_y )
    public fun compute_initial_lp( 
        amount_x: u64,
        amount_y: u64
    ): u64 {
        ( math128::sqrt(( amount_x  as u128) * ( amount_y as u128) ) as u64 )
    }

    // Calculate the output amount using k = x^3 * y + x * y^3
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64, 
        reserve_out: u64, 
    ) : u64 {
        let k = calculate_constant_k((reserve_in as u256), (reserve_out as u256));
        (((reserve_out as u256) - get_y(((amount_in + reserve_in) as u256), k, (reserve_out as u256))) as u64)
    }

    fun calculate_constant_k(r1: u256, r2: u256): u256 {
        (r1 * r1 * r1 * r2 + r2 * r2 * r2 * r1)
    }

    fun get_y(x0: u256, xy: u256, y: u256): u256 {
        let i = 0;
        while (i < 255) {
            let y_prev = y;
            let k = f(x0, y);
            if (k < xy) {
                let dy = (xy - k) / d(x0, y);
                y = y + dy;
            } else {
                let dy = (k - xy) / d(x0, y);
                y = y - dy;
            };
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y
                }
            } else {
                if (y_prev - y <= 1) {
                    return y
                }
            };
            i = i + 1;
        };
        y
    }

    fun f(x0: u256, y: u256): u256 {
        x0 * (y * y * y) + (x0 * x0 * x0) * y
    }

    fun d(x0: u256, y: u256): u256 {
        3 * x0 * (y * y) + (x0 * x0 * x0)
    }

}