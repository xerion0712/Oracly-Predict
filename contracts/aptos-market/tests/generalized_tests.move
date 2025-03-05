

#[test_only]
module legato_market::generalized_tests {

    use std::signer;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;
 
    use legato_market::generalized::{Self};
    use legato_market::mock_usdc_fa::{Self};
    
    #[test_only]
    const MARKET_ID: u64 = 0;

    #[test_only]
    const ROUND_ID: u64 = 0;

    #[test_only]
    const ROUND_DURATION: u64 = 604800;

    // Setting up markets
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_setup_markets(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);
 
        let bet_token_metadata = generalized::get_market_bet_token_metadata(0); 
        assert!( mock_usdc_fa::get_metadata() == bet_token_metadata, 0)
    }

    // Testing basic flow
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_basic_flow(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);

        timestamp::fast_forward_seconds(1000);

        // Place bets
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 0, 100_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 1, 100_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 2, 100_000000 );

        // Checking market liquidity
        assert!( generalized::get_market_outcome_bet_amount(MARKET_ID, 0) == 100_000000, 1);
        assert!( generalized::get_market_outcome_bet_amount(MARKET_ID, 1) == 100_000000, 2);
        assert!( generalized::get_market_outcome_bet_amount(MARKET_ID, 2) == 100_000000, 3);
        let (total_balance, _, _,_,_) = generalized::get_market_data( MARKET_ID );
        assert!( total_balance == 300_000000, 4);

        // Checking bet positions
        let (_,_,_,bet_amount_1, user_address_1, _,_)  = generalized::get_bet_position(0);
        assert!( bet_amount_1 == 100_000000 &&  signer::address_of( user_1 ) == user_address_1 , 4);
        let (_,_,_,bet_amount_2, user_address_2, _,_)  = generalized::get_bet_position(1);
        assert!( bet_amount_2 == 100_000000 &&  signer::address_of( user_2 ) == user_address_2 , 5);
        let (_,_,_,bet_amount_3, user_address_3, _,_)  = generalized::get_bet_position(2);
        assert!( bet_amount_3 == 100_000000 &&  signer::address_of( user_3 ) == user_address_3 , 6);
        
        // Finalize the market and fast-forwards the system clock
        generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[0,1,2], vector[10000,10000,10000]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, ROUND_ID, vector[0,2], vector[]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        let payout_amount_1 = generalized::check_payout_amount(0); 
        assert!(  payout_amount_1 == 150_000000 , 7); // 150 USDC

        let payout_amount_2 = generalized::check_payout_amount(1); 
        assert!(  payout_amount_2 == 0 , 8);

        let payout_amount_3 = generalized::check_payout_amount(2); 
        assert!(  payout_amount_3 == 150_000000 , 9); // 150 USDC

        generalized::claim_prize( user_1, 0 );
        generalized::claim_prize( user_2, 1 );
        generalized::claim_prize( user_3, 2 );

        assert!(  (primary_fungible_store::balance(signer::address_of(user_1),  mock_usdc_fa::get_metadata() )) == 145_000001 , 10); // 145 USDC
        assert!(  (primary_fungible_store::balance(signer::address_of(user_2),  mock_usdc_fa::get_metadata() )) == 0 , 11); // 0 USDC
        assert!(  (primary_fungible_store::balance(signer::address_of(user_3),  mock_usdc_fa::get_metadata() )) == 145_000001 , 12); // 145 USDC
    }

    // Testing different weighted outcomes in the same round
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_different_weighted_outcomes(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);

        timestamp::fast_forward_seconds(1000);

        // Place bets
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 0, 100_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 1, 100_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 2, 100_000000 );

        // Finalize the market and fast-forwards the system clock
        generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[0,1,2], vector[5000,10000,15000]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, ROUND_ID, vector[0,2], vector[]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        let payout_amount_1 = generalized::check_payout_amount(0); 
        assert!(  payout_amount_1 == 75_000000 , 13); // 75 USDC

        let payout_amount_2 = generalized::check_payout_amount(1); 
        assert!(  payout_amount_2 == 0 , 14);

        let payout_amount_3 = generalized::check_payout_amount(2); 
        assert!(  payout_amount_3 == 225_000000 , 15); // 225 USDC

    }

    // Testing consecutive rounds when the first is weight to 50%
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_consecutive_rounds(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);

        timestamp::fast_forward_seconds(1000);

        // Place bets
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 0, 100_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 1, 50_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 2, 50_000000 );

        // Finalize the market and fast-forwards the system clock
        generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[0,1,2], vector[10000,10000,10000]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, ROUND_ID, vector[0], vector[]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        generalized::update_round_weights( deployer, 0, 0, 5000);

        generalized::claim_prize( user_1, 0 );
        generalized::claim_prize( user_2, 1 );
        generalized::claim_prize( user_3, 2 );

        let (total_bets, total_paid) = generalized::get_market_round_bet_amount(0 , 0);
        let available_amount = total_bets-total_paid;
        assert!(  available_amount == 100_000000 , 16); // 100 USDC

        generalized::place_bet(user_2, MARKET_ID, 1, 3, 50_000000 );
        generalized::place_bet(user_3, MARKET_ID, 1, 4, 50_000000 );

        // Finalize the market and fast-forwards the system clock
        generalized::finalize_market( deployer, MARKET_ID, 1, vector[3,4], vector[10000,10000]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, 1, vector[3,4], vector[]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        let payout_amount_3 = generalized::check_payout_amount(3); 
        assert!(  payout_amount_3 == 100_000000 , 17); // 100 USDC

        let payout_amount_4 = generalized::check_payout_amount(4); 
        assert!(  payout_amount_4 == 100_000000 , 18); // 100 USDC

    }   

    // Testing dispute cases
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_dispute_cases(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
        
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);

        timestamp::fast_forward_seconds(1000);

        // Place bets
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 0, 100_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 1, 100_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 2, 100_000000 );

        // Finalize the market and fast-forwards the system clock
        generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[0,1,2], vector[10000,10000,10000]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, ROUND_ID, vector[0], vector[1,2]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        let payout_amount_1 = generalized::check_payout_amount(0); 
        assert!(  payout_amount_1 == 100_000000 , 19); // 100 USDC

        generalized::refund( user_2, 1 );
        generalized::refund( user_3, 2 );

        // Each get 100 USDC back
        assert!(  (primary_fungible_store::balance(signer::address_of(user_2),  mock_usdc_fa::get_metadata() )) == 100_000000 , 20); // 100 USDC
        assert!(  (primary_fungible_store::balance(signer::address_of(user_3),  mock_usdc_fa::get_metadata() )) == 100_000000 , 21); // 100 USDC
    }

    // Testing with actual testnet data
    #[test(aptos_framework = @aptos_framework, deployer = @legato_market, user_1 = @0x1111, user_2 = @0x2222, user_3 = @0x3333 )]
    fun test_testnet_data_cases(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {
    
        setup_markets(aptos_framework, deployer, user_1, user_2, user_3);

        timestamp::fast_forward_seconds(1000);

        // Place bets
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 1, 10_000000 );
        generalized::place_bet(user_1, MARKET_ID, ROUND_ID, 3, 3_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 4, 1_000000 );
        generalized::place_bet(user_2, MARKET_ID, ROUND_ID, 5, 1_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 6, 3_000000 );
        generalized::place_bet(user_3, MARKET_ID, ROUND_ID, 7, 3_000000 );

        generalized::update_round_weights(deployer , MARKET_ID, ROUND_ID, 10000 );
    
        // Finalize the market and fast-forwards the system clock
        // generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[1,2,3,4,5,6,7,8], vector[2000,1000,800,1000,1200,800,1500,700]);
        generalized::finalize_market( deployer, MARKET_ID, ROUND_ID, vector[2,8,1,3,4,5,6,7], vector[1000,700,2000,800,1000,1200,800,1500]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);

        // Resolves the market and fast-forwards the system clock
        generalized::resolve_market( deployer, MARKET_ID, ROUND_ID, vector[2,6,9], vector[1,3,4]);
        timestamp::fast_forward_seconds(1*ROUND_DURATION);


        generalized::place_bet(user_1, MARKET_ID, 2, 10, 10_000000 );
        generalized::place_bet(user_1, MARKET_ID, 2, 11, 3_000000 );
        generalized::place_bet(user_2, MARKET_ID, 2, 13, 2_000000 );
        generalized::place_bet(user_2, MARKET_ID, 2, 14, 7_000000 );
        generalized::place_bet(user_3, MARKET_ID, 2, 18, 10_000000 );
        generalized::place_bet(user_3, MARKET_ID, 2, 7, 3_000000 );        

        let payout_amount_1 = generalized::check_payout_amount(4); 
        assert!(  payout_amount_1 == 556289 , 20); // 0.55 USDC
        
    }

    #[test_only]
    public fun setup_markets(aptos_framework: &signer, deployer: &signer, user_1: &signer, user_2: &signer, user_3: &signer) {

        timestamp::set_time_has_started_for_testing(aptos_framework);

        generalized::init_module_for_testing(deployer);
        mock_usdc_fa::init_module_for_testing(deployer);

        let user_1_address = signer::address_of(user_1);
        let user_2_address = signer::address_of(user_2);
        let user_3_address = signer::address_of(user_3); 

        account::create_account_for_test(user_1_address);  
        account::create_account_for_test(user_2_address); 
        account::create_account_for_test(user_3_address);
        account::create_account_for_test( generalized::get_pool_object_address());

        // Mint 100 USDC per each
        mock_usdc_fa::mint( deployer, user_1_address, 100_000000 );
        mock_usdc_fa::mint( deployer, user_2_address, 100_000000 );
        mock_usdc_fa::mint( deployer, user_3_address, 100_000000 );

        generalized::add_market(deployer, mock_usdc_fa::get_metadata(), 100_000000);
        
    }


}