// Copyright (c) Tamago Blockchain Labs, Inc.
// SPDX-License-Identifier: MIT

module legato::event {

    use sui::event::emit;
    use sui::object::ID;

    public struct MintEvent has copy, drop {
        global: ID,
        input_amount: u64,
        vault_share: u64,
        sender: address,
        epoch: u64
    }

    public struct RequestRedeemEvent has copy, drop {
        global: ID,
        vault_amount: u64,
        withdraw_amount: u64,
        sender: address,
        epoch: u64
    }

    public struct RedeemEvent has copy, drop {
        global: ID,
        withdraw_amount: u64,
        sender: address,
        epoch: u64
    }

    public(package) fun mint_event(
        global: ID,
        input_amount: u64,
        vault_share: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            MintEvent {
                global,
                input_amount,
                vault_share,
                sender,
                epoch
            }
        )
    }

    public(package) fun request_redeem_event(
        global: ID,
        vault_amount: u64,
        withdraw_amount: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            RequestRedeemEvent {
                global,
                vault_amount,
                withdraw_amount,
                sender,
                epoch
            }
        )
    }

    public(package) fun redeem_event(
        global: ID,
        withdraw_amount: u64,
        sender: address,
        epoch: u64
    ) {
        emit(
            RedeemEvent {
                global,
                withdraw_amount,
                sender,
                epoch
            }
        )
    }

}