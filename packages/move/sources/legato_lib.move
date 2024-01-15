module legato::legato_lib {

    // use legato::amm::{Self, Pool};

    friend legato::legato;

    struct VaultBalances has store {
        principal: u64,
        principal_rewards: u64, // accumulated rewards at the time of conversion"
        debt: u64
    }

    public(friend) fun calculate_pt_debt_from_epoch(apy: u64, from_epoch: u64, to_epoch: u64, input_amount: u64): u64 {
        let for_epoch = to_epoch-from_epoch;
        let (for_epoch, apy, input_amount) = ((for_epoch as u128), (apy as u128), (input_amount as u128));
        let result = (for_epoch*apy*input_amount) / (365_000_000_000);
        (result as u64)
    }

    public(friend) fun empty_balances() : VaultBalances {
        VaultBalances {
            principal: 0,
            principal_rewards: 0,
            debt: 0
        }
    }

    public(friend) fun increment_balances(balances : &mut VaultBalances, principal_amount: u64, rewards_amount: u64, debt_amount: u64) {
        balances.principal = balances.principal+principal_amount;
        balances.principal_rewards = balances.principal_rewards+rewards_amount;
        balances.debt = balances.debt+debt_amount;
    }

    public(friend) fun decrement_balances(balances: &mut VaultBalances, principal_amount: u64, rewards_amount: u64) {
        balances.principal = balances.principal-principal_amount;
        
        let diff =
            if (rewards_amount >= balances.principal_rewards)
                rewards_amount-balances.principal_rewards
            else 0;
        
        balances.principal_rewards =
            if (balances.principal_rewards >= rewards_amount)
                balances.principal_rewards-rewards_amount
            else 0;
        
        balances.debt = 
            if (balances.debt >= diff)
                balances.debt-diff
            else 0;

    }

    // public(friend) fun pt_to_yt<Y, X>(_pool: &mut Pool<Y, X>, input_amount: u64) : u64 {
    //     let (coin_x_reserve, coin_y_reserve, _lp) = amm::get_reserves_size(pool);
        
    //     let output_x_amount = get_amount_out(
    //         input_amount,
    //         coin_y_reserve,
    //         coin_x_reserve,
    //     );

    //     output_x_amount
    // }

    public fun get_balances(balances: &VaultBalances): (u64, u64, u64) {
        (balances.principal, balances.principal_rewards, balances.debt)
    }



}