use dep::aztec::{
    hash::compute_secret_hash, prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
    protocol_types::storage::map::derive_storage_slot_in_map,
    note::{note_getter::{MAX_NOTES_PER_PAGE, view_notes}, note_viewer_options::NoteViewerOptions},
    oracle::{execution::{get_block_number, get_contract_address}, unsafe_rand::unsafe_rand, storage::storage_read}
};

use dep::token::{types::{token_note::TokenNote, transparent_note::TransparentNote}, Token};
use crate::Vanhelsing;

pub fn setup(with_account_contracts: bool) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, recipient) = if with_account_contracts {
        let owner = env.create_account_contract(1);
        let recipient = env.create_account_contract(2);
        // Deploy canonical auth registry
        let _auth_registry = env.deploy("./@auth_registry_contract", "AuthRegistry").without_initializer();
        (owner, recipient)
    } else {
        let owner = env.create_account();
        let recipient = env.create_account();
        (owner, recipient)
    };

    // Start the test in the account contract address
    env.impersonate(owner);

    // Deploy staking token contract
    let reward_initializer_call_interface = Token::interface().constructor(
        owner,
        "Reward0000000000000000000000000",
        "RR00000000000000000000000000000",
        18
    );
    let reward_token_contract = env.deploy("../token/@token_contract", "Token").with_public_initializer(reward_initializer_call_interface);
    let reward_token_contract_address = reward_token_contract.to_address();
    env.advance_block_by(1);

    // Deploy staking token contract
    let staking_initializer_call_interface = Token::interface().constructor(
        owner,
        "Stake00000000000000000000000000",
        "SS00000000000000000000000000000",
        18
    );
    let staking_token_contract = env.deploy("../token/@token_contract", "Token").with_public_initializer(staking_initializer_call_interface);
    let staking_token_contract_address = staking_token_contract.to_address();
    env.advance_block_by(1);

    // Deploy Vanhelsing contract
    let initializer_call_interface_2 = Vanhelsing::interface().constructor(owner, 0, 1, 180, 1, 180);
    let vanhelsing_contract = env.deploy_self("Vanhelsing").with_public_initializer(initializer_call_interface_2);
    let vanhelsing_contract_address = vanhelsing_contract.to_address();
    env.advance_block_by(1);
    (
        &mut env, staking_token_contract_address, reward_token_contract_address, vanhelsing_contract_address, owner, recipient
    )
}

pub fn setup_and_mint(with_account_contracts: bool) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, AztecAddress, Field) {
    // Setup
    let (
        env,
        staking_token_contract_address,
        reward_token_contract_address,
        vanhelsing_contract_address,
        owner,
        recipient
         ) = setup(with_account_contracts);

    let mint_amount = 10000;
    // Mint some tokens
    let secret = unsafe_rand();
    let secret_hash = compute_secret_hash(secret);

    //Private
    let mint_reward_private_call_interface = Token::at(reward_token_contract_address).mint_private(mint_amount, secret_hash);
    env.call_public(mint_reward_private_call_interface);

    // Public
    let mint_reward_public_call_interface = Token::at(reward_token_contract_address).mint_public(owner, mint_amount);
    env.call_public(mint_reward_public_call_interface);

    // Time travel so we can read keys from the registry
    env.advance_block_by(6);

    // Store a note in the cache so we can redeem it
    env.store_note_in_cache(
        &mut TransparentNote::new(mint_amount, secret_hash),
        Token::storage().pending_shields.slot,
        reward_token_contract_address
    );

    // Redeem our shielded tokens
    let redeem_shield_call_interface = Token::at(reward_token_contract_address).redeem_shield(owner, mint_amount, secret);
    env.call_private_void(redeem_shield_call_interface);

    (
        env, reward_token_contract_address, staking_token_contract_address, vanhelsing_contract_address, owner, recipient, mint_amount
    )
}
