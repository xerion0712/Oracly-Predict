// Borrowed from Aptos

/// Defines a fixed-point numeric type with a 64-bit integer part and
/// a 64-bit fractional part.

module legato::fixed_point64 {

    /// Define a fixed-point numeric type with 64 fractional bits.
    /// This is just a u128 integer but it is wrapped in a struct to
    /// make a unique type. This is a binary representation, so decimal
    /// values may not be exactly representable, but it provides more
    /// than 9 decimal digits of precision both before and after the
    /// decimal point (18 digits total). For comparison, double precision
    /// floating-point has less than 16 decimal digits of precision, so
    /// be careful about using floating-point to convert these values to
    /// decimal.
    struct FixedPoint64 has copy, drop, store { value: u128 }

    const MAX_U128: u256 = 340282366920938463463374607431768211455;

    /// The denominator provided was zero
    const EDENOMINATOR: u64 = 0x10001;
    /// The quotient value would be too large to be held in a `u128`
    const EDIVISION: u64 = 0x20002;
    /// The multiplied value would be too large to be held in a `u128`
    const EMULTIPLICATION: u64 = 0x20003;
    /// A division by zero was encountered
    const EDIVISION_BY_ZERO: u64 = 0x10004;
    /// The computed ratio when converting to a `FixedPoint64` would be unrepresentable
    const ERATIO_OUT_OF_RANGE: u64 = 0x20005;
    /// Abort code on calculation result is negative.
    const ENEGATIVE_RESULT: u64 = 0x10006;

    /// Returns x - y. x must be not less than y.
    public fun sub(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
        let x_raw = get_raw_value(x);
        let y_raw = get_raw_value(y);
        assert!(x_raw >= y_raw, ENEGATIVE_RESULT);
        create_from_raw_value(x_raw - y_raw)
    } 

    /// Returns x + y. The result cannot be greater than MAX_U128.
    public fun add(x: FixedPoint64, y: FixedPoint64): FixedPoint64 {
        let x_raw = get_raw_value(x);
        let y_raw = get_raw_value(y);
        let result = (x_raw as u256) + (y_raw as u256);
        assert!(result <= MAX_U128, ERATIO_OUT_OF_RANGE);
        create_from_raw_value((result as u128))
    } 

    /// Multiply a u128 integer by a fixed-point number, truncating any
    /// fractional part of the product. This will abort if the product
    /// overflows.
    public fun multiply_u128(val: u128, multiplier: FixedPoint64): u128 {
        // The product of two 128 bit values has 256 bits, so perform the
        // multiplication with u256 types and keep the full 256 bit product
        // to avoid losing accuracy.
        let unscaled_product = (val as u256) * (multiplier.value as u256);
        // The unscaled product has 64 fractional bits (from the multiplier)
        // so rescale it by shifting away the low bits.
        let product = unscaled_product >> 64;
        // Check whether the value is too large.
        assert!(product <= MAX_U128, EMULTIPLICATION);
        (product as u128)
    } 

    /// Divide a u128 integer by a fixed-point number, truncating any
    /// fractional part of the quotient. This will abort if the divisor
    /// is zero or if the quotient overflows.
    public fun divide_u128(val: u128, divisor: FixedPoint64): u128 {
        // Check for division by zero.
        assert!(divisor.value != 0, EDIVISION_BY_ZERO);
        // First convert to 256 bits and then shift left to
        // add 64 fractional zero bits to the dividend.
        let scaled_value = (val as u256) << 64;
        let quotient = scaled_value / (divisor.value as u256);
        // Check whether the value is too large.
        assert!(quotient <= MAX_U128, EDIVISION);
        // the value may be too large, which will cause the cast to fail
        // with an arithmetic error.
        (quotient as u128)
    } 

    /// Create a fixed-point value from a rational number specified by its
    /// numerator and denominator. Calling this function should be preferred
    /// for using `Self::create_from_raw_value` which is also available.
    /// This will abort if the denominator is zero. It will also
    /// abort if the numerator is nonzero and the ratio is not in the range
    /// 2^-64 .. 2^64-1. When specifying decimal fractions, be careful about
    /// rounding errors: if you round to display N digits after the decimal
    /// point, you can use a denominator of 10^N to avoid numbers where the
    /// very small imprecision in the binary representation could change the
    /// rounding, e.g., 0.0125 will round down to 0.012 instead of up to 0.013.
    public fun create_from_rational(numerator: u128, denominator: u128): FixedPoint64 {
        // If the denominator is zero, this will abort.
        // Scale the numerator to have 64 fractional bits, so that the quotient will have 64
        // fractional bits.
        let scaled_numerator = (numerator as u256) << 64;
        assert!(denominator != 0, EDENOMINATOR);
        let quotient = scaled_numerator / (denominator as u256);
        assert!(quotient != 0 || numerator == 0, ERATIO_OUT_OF_RANGE);
        // Return the quotient as a fixed-point number. We first need to check whether the cast
        // can succeed.
        assert!(quotient <= MAX_U128, ERATIO_OUT_OF_RANGE);
        FixedPoint64 { value: (quotient as u128) }
    } 

    /// Create a fixedpoint value from a raw value.
    public fun create_from_raw_value(value: u128): FixedPoint64 {
        FixedPoint64 { value }
    } 

    /// Accessor for the raw u128 value. Other less common operations, such as
    /// adding or subtracting FixedPoint64 values, can be done using the raw
    /// values directly.
    public fun get_raw_value(num: FixedPoint64): u128 {
        num.value
    }

    /// Returns true if the ratio is zero.
    public fun is_zero(num: FixedPoint64): bool {
        num.value == 0
    }

    /// Returns the smaller of the two FixedPoint64 numbers.
    public fun min(num1: FixedPoint64, num2: FixedPoint64): FixedPoint64 {
        if (num1.value < num2.value) {
            num1
        } else {
            num2
        }
    } 

    /// Returns the larger of the two FixedPoint64 numbers.
    public fun max(num1: FixedPoint64, num2: FixedPoint64): FixedPoint64 {
        if (num1.value > num2.value) {
            num1
        } else {
            num2
        }
    } 

    /// Returns true if num1 <= num2
    public fun less_or_equal(num1: FixedPoint64, num2: FixedPoint64): bool {
        num1.value <= num2.value
    } 

    /// Returns true if num1 < num2
    public fun less(num1: FixedPoint64, num2: FixedPoint64): bool {
        num1.value < num2.value
    }

    /// Returns true if num1 >= num2
    public fun greater_or_equal(num1: FixedPoint64, num2: FixedPoint64): bool {
        num1.value >= num2.value
    } 

    /// Returns true if num1 > num2
    public fun greater(num1: FixedPoint64, num2: FixedPoint64): bool {
        num1.value > num2.value
    } 

    /// Returns true if num1 = num2
    public fun equal(num1: FixedPoint64, num2: FixedPoint64): bool {
        num1.value == num2.value
    } 

    /// Returns true if num1 almost equals to num2, which means abs(num1-num2) <= precision
    public fun almost_equal(num1: FixedPoint64, num2: FixedPoint64, precision: FixedPoint64): bool {
        if (num1.value > num2.value) {
            (num1.value - num2.value <= precision.value)
        } else {
            (num2.value - num1.value <= precision.value)
        }
    }

    /// Create a fixedpoint value from a u128 value.
    public fun create_from_u128(val: u128): FixedPoint64 {
        let value = (val as u256) << 64;
        assert!(value <= MAX_U128, ERATIO_OUT_OF_RANGE);
        FixedPoint64 {value: (value as u128)}
    }


    /// Returns the largest integer less than or equal to a given number.
    public fun floor(num: FixedPoint64): u128 {
        num.value >> 64
    }


    /// Rounds up the given FixedPoint64 to the next largest integer.
    public fun ceil(num: FixedPoint64): u128 {
        let floored_num = floor(num) << 64;
        if (num.value == floored_num) {
            return floored_num >> 64
        };
        let val = ((floored_num as u256) + (1 << 64));
        (val >> 64 as u128)
    }


    /// Returns the value of a FixedPoint64 to the nearest integer.
    public fun round(num: FixedPoint64): u128 {
        let floored_num = floor(num) << 64;
        let boundary = floored_num + ((1 << 64) / 2);
        if (num.value < boundary) {
            floored_num >> 64
        } else {
            ceil(num)
        }
    }
    

    // #[test]
    // public entry fun test_sub() {
    //     let x = create_from_rational(9, 7);
    //     let y = create_from_rational(1, 3);
    //     let result = sub(x, y);
    //     // 9/7 - 1/3 = 20/21
    //     let expected_result = create_from_rational(20, 21);
    //     assert_approx_the_same((get_raw_value(result) as u256), (get_raw_value(expected_result) as u256), 16);
    // }

    // #[test]
    // #[expected_failure(abort_code = 0x10006, location = Self)]
    // public entry fun test_sub_should_abort() {
    //     let x = create_from_rational(1, 3);
    //     let y = create_from_rational(9, 7);
    //     let _ = sub(x, y);
    // }

    // #[test_only]
    // /// For functions that approximate a value it's useful to test a value is close
    // /// to the most correct value up to last digit
    // fun assert_approx_the_same(x: u256, y: u256, precission: u128) {
    //     if (x < y) {
    //         let tmp = x;
    //         x = y;
    //         y = tmp;
    //     };
    //     let mult = 1u256;
    //     let n = 10u256;
    //     while (precission > 0) {
    //         if (precission % 2 == 1) {
    //             mult = mult * n;
    //         };
    //         precission = precission / 2;
    //         n = n * n;
    //     };
    //     assert!((x - y) * mult < x, 0);
    // }

}
