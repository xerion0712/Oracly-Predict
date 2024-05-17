// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

// An extension to AMM for LBP, a special pool that allows for a gradual shift in weight per conditions.
// This provides a solution for launching project tokens with reduced capital requirements and less selling pressure.
// In Legato LBP, there are two types of settlement assets available for pairing with project tokens.
// (1) Common coins like USDC or SUI (2) SUI staking rewards via Legato Vault

module legato::lbp {

    use std::option::{Self, Option};
    use legato::fixed_point64::{Self, FixedPoint64};
    use legato::weighted_math;

    const MIN_TRIGGER_AMOUNT: u64 = 10000;
    const MAX_EPOCH_SPAN: u64 = 100;
    /// The integer scaling setting for weights
    const WEIGHT_SCALE: u64 = 10000;

    const ERR_TOO_LOW_VALUE: u64 = 301;
    const ERR_INVALID_WEIGHT: u64 = 302; 
    const ERR_EXCEED_AVAILABLE: u64 = 303; 

    friend legato::amm;
 
    // Defines the settings for the LBP pool.
    struct LBPParams has copy, store, drop {
        is_proj_on_x: bool, // Indicates if the project token is on the X side of the pool.
        start_weight: u64,  // Initial weight of the project token.
        final_weight: u64, // The weight when the pool is stabilized.  
        is_vault: bool, // Determines the settlement asset: false - coins, true - staking rewards.
        target_amount: u64, // The target amount required to fully shift the weight.
        total_amount_collected: u64,  // Total amount accumulated in the pool.
    }

    // Constructs initialization parameters for an LBP
    public(friend) fun construct_init_params(
        proj_on_x: bool, // Indicates whether the project token is on the X or Y side
        start_weight: u64, 
        final_weight: u64,  
        is_vault: bool, // Determines if the pool accepts coins or future staking rewards.
        target_amount: u64
    ) : LBPParams {

        // Check if weights and trigger amount are within valid ranges.
        assert!( start_weight >= 5000 && start_weight < WEIGHT_SCALE, ERR_INVALID_WEIGHT );
        assert!( final_weight >= 5000 && final_weight < WEIGHT_SCALE, ERR_INVALID_WEIGHT );
        assert!( start_weight > final_weight, ERR_INVALID_WEIGHT ); 

        LBPParams {
            is_proj_on_x: proj_on_x,
            start_weight,
            final_weight, 
            is_vault, 
            target_amount,
            total_amount_collected: 0
        }
    }
 

    // Calculates the current weight of the project token.
    // -  decline_ratio = (total_collected / target_amount)^(stablized_weight / start_weight)
    public(friend) fun current_weight(params: &LBPParams ) : (u64, u64) {
 
        // Check if fully shifted 
        let weight_base = if ( params.total_amount_collected >= params.target_amount ) {
            // Use final weight if the target amount is reached
            params.final_weight
        } else if (10000 > params.total_amount_collected  ) {
            // Return the start weight is value is less than 10000
            params.start_weight
        } else {

            // Calculate the weight difference
            let weight_diff = if (params.start_weight > params.final_weight) { 
                params.start_weight-params.final_weight
            } else {
                0
            };

            assert!( weight_diff > 0 , ERR_INVALID_WEIGHT);

            // Ensure the accumulated amount does not exceed the target amount
            let accumulated_amount = if (params.target_amount > params.total_amount_collected) {
                (params.total_amount_collected as u128)
            } else {    
                (params.target_amount as u128)
            };
            let total_target_amount = (params.target_amount as u128);

            // Calculate the decline ratio for weight adjustment
            let decline_ratio = weighted_math::power( fixed_point64::create_from_rational( accumulated_amount, total_target_amount )  , fixed_point64::create_from_rational( (params.final_weight as u128), (params.start_weight as u128) ));
            
            // Adjust the start weight by the decline ratio to get the current weight
            params.start_weight-(fixed_point64::multiply_u128((weight_diff as u128), decline_ratio) as u64)
        };


        let weight_pair = WEIGHT_SCALE-weight_base;

        if ( params.is_proj_on_x ) {
            (weight_base, weight_pair)
        } else {
            (weight_pair, weight_base) 
        } 
    }

    public (friend) fun is_buy(params: &LBPParams) : bool {
        // X -> Y
        if ( params.is_proj_on_x ) {
            false
        } else {
            // Y -> X
            true
        }
    }

    // Verifies and adjusts the amount for weight calculation
    public(friend) fun verify_and_adjust_amount(params: &mut LBPParams, is_buy: bool, amount_in: u64, _amount_out: u64 ) {
        // Works when the weight is not stabilized
        if ( params.target_amount >  params.total_amount_collected) {
            // Triggered by token sold
            if (!params.is_vault) {
                // Considered only buy transactions
                if (is_buy) {
                    // Update the total amount collected
                    params.total_amount_collected = params.total_amount_collected+amount_in;
                };
            } else {
                // Triggered by staking rewards
            };
        };
    }
 

    public fun is_vault(params: &LBPParams) : bool {
        params.is_vault
    }

    public fun total_amount_collected(params: &LBPParams) : u64 {
        params.total_amount_collected
    }

    public fun total_target_amount(params: &LBPParams) : u64 {
        params.target_amount
    }

    public fun proj_on_x(params: &LBPParams) : bool {
        params.is_proj_on_x
    }
 
    fun increase_total_amount_collected(params: &mut LBPParams, amount: u64) {
        params.total_amount_collected = params.total_amount_collected+amount;
    }

    #[test]
    public fun test_current_weight() {

        let params = construct_init_params(
            false,
            9000, // start weight
            6000, // end weight 
            false,
            50000_000000 // 50,000 USDC
        );

        increase_total_amount_collected( &mut params, 2000_000000 ); // 2,000 USDC
        let current_weight = 10000;

        // Keep acquiring
        while ( total_amount_collected(&params) <= 50000_000000) { 
            let (_, weight_pair) = current_weight( &params );
 
            // Check that the weight is continuously declining
            assert!( current_weight >= weight_pair , weight_pair);
            
            current_weight = weight_pair;
            increase_total_amount_collected( &mut params, 2000_000000 );
        };

    }

}