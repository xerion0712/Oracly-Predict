// Copyright 2022 OmniBTC Authors. Licensed under Apache-2.0 License.
module legato::event {
    use std::string::String;

    use sui::event::emit;
    use sui::object::ID;

    friend legato::interface;

    /// Liquidity pool added event.
    struct AddedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64,
    }

    /// Liquidity pool removed event.
    struct RemovedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64,
    }

    /// Liquidity pool swapped event.
    struct SwappedEvent has copy, drop {
        global: ID,
        lp_name: String,
        coin_x_in: u64,
        coin_x_out: u64,
        coin_y_in: u64,
        coin_y_out: u64,
    }

    public(friend) fun added_event(
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64
    ) {
        emit(
            AddedEvent {
                global,
                lp_name,
                coin_x_val,
                coin_y_val,
                lp_val
            }
        )
    }

    public(friend) fun removed_event(
        global: ID,
        lp_name: String,
        coin_x_val: u64,
        coin_y_val: u64,
        lp_val: u64
    ) {
        emit(
            RemovedEvent {
                global,
                lp_name,
                coin_x_val,
                coin_y_val,
                lp_val
            }
        )
    }

    public(friend) fun swapped_event(
        global: ID,
        lp_name: String,
        coin_x_in: u64,
        coin_x_out: u64,
        coin_y_in: u64,
        coin_y_out: u64
    ) {
        emit(
            SwappedEvent {
                global,
                lp_name,
                coin_x_in,
                coin_x_out,
                coin_y_in,
                coin_y_out
            }
        )
    }

}