/// Standard math utilities missing in the Move Language.
module legato::math64 {

    use legato::fixed_point32::FixedPoint32;
    use legato::fixed_point32;

    /// Cannot log2 the value 0
    const EINVALID_ARG_FLOOR_LOG2: u64 = 1;

    /// Return the largest of two numbers.
    public fun max(a: u64, b: u64): u64 {
        if (a >= b) a else b
    }

    /// Return the smallest of two numbers.
    public fun min(a: u64, b: u64): u64 {
        if (a < b) a else b
    }

    /// Return the average of two.
    public fun average(a: u64, b: u64): u64 {
        if (a < b) {
            a + (b - a) / 2
        } else {
            b + (a - b) / 2
        }
    }

    /// Returns a * b / c going through u128 to prevent intermediate overflow
    public fun mul_div(a: u64, b: u64, c: u64): u64 {
        // Inline functions cannot take constants, as then every module using it needs the constant
        assert!(c != 0, 4);
        (((a as u128) * (b as u128) / (c as u128)) as u64)
    }

    /// Return x clamped to the interval [lower, upper].
    public fun clamp(x: u64, lower: u64, upper: u64): u64 {
        min(upper, max(lower, x))
    }

    /// Return the value of n raised to power e
    public fun pow(n: u64, e: u64): u64 {
        if (e == 0) {
            1
        } else {
            let p = 1;
            while (e > 1) {
                if (e % 2 == 1) {
                    p = p * n;
                };
                e = e / 2;
                n = n * n;
            };
            p * n
        }
    }

    /// Returns floor(lg2(x))
    public fun floor_log2(x: u64): u8 {
        let res = 0;
        assert!(x != 0, EINVALID_ARG_FLOOR_LOG2);
        // Effectively the position of the most significant set bit
        let n = 32;
        while (n > 0) {
            if (x >= (1 << n)) {
                x = x >> n;
                res = res + n;
            };
            n = n >> 1;
        };
        res
    }

    // Returns log2(x)
    public fun log2(x: u64): FixedPoint32 {
        let integer_part = floor_log2(x);
        // Normalize x to [1, 2) in fixed point 32.
        let y = (if (x >= 1 << 32) {
            x >> (integer_part - 32)
        } else {
            x << (32 - integer_part)
        } as u128);
        let frac = 0;
        let delta = 1 << 31;
        while (delta != 0) {
            // log x = 1/2 log x^2
            // x in [1, 2)
            y = (y * y) >> 32;
            // x is now in [1, 4)
            // if x in [2, 4) then log x = 1 + log (x / 2)
            if (y >= (2 << 32)) { frac = frac + delta; y = y >> 1; };
            delta = delta >> 1;
        };
        fixed_point32::create_from_raw_value (((integer_part as u64) << 32) + frac)
    }

    /// Returns square root of x, precisely floor(sqrt(x))
    public fun sqrt(x: u64): u64 {
        if (x == 0) return 0;
        // Note the plus 1 in the expression. Let n = floor_lg2(x) we have x in [2^n, 2^(n+1)> and thus the answer in
        // the half-open interval [2^(n/2), 2^((n+1)/2)>. For even n we can write this as [2^(n/2), sqrt(2) 2^(n/2)>
        // for odd n [2^((n+1)/2)/sqrt(2), 2^((n+1)/2>. For even n the left end point is integer for odd the right
        // end point is integer. If we choose as our first approximation the integer end point we have as maximum
        // relative error either (sqrt(2) - 1) or (1 - 1/sqrt(2)) both are smaller then 1/2.
        let res = 1 << ((floor_log2(x) + 1) >> 1);
        // We use standard newton-rhapson iteration to improve the initial approximation.
        // The error term evolves as delta_i+1 = delta_i^2 / 2 (quadratic convergence).
        // It turns out that after 4 iterations the delta is smaller than 2^-32 and thus below the treshold.
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;
        res = (res + x / res) >> 1;
        min(res, x / res)
    }

    public fun ceil_div(x: u64, y: u64): u64 {
        // ceil_div(x, y) = floor((x + y - 1) / y) = floor((x - 1) / y) + 1
        // (x + y - 1) could spuriously overflow. so we use the later version
        if (x == 0) {
            // Inline functions cannot take constants, as then every module using it needs the constant
            assert!(y != 0, 4);
            0
        }
        else (x - 1) / y + 1
    }
 
}
