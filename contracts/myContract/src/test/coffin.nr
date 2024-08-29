use crate::test::utils;
use crate::Vanhelsing;
use dep::aztec::test::{helpers::{cheatcodes, test_environment::TestEnvironment}};
use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;
use dep::aztec::note::note_getter::{MAX_NOTES_PER_PAGE, view_notes};
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::token::Token;
use dep::std::println;
use dep::authwit::cheatcodes as authwit_cheatcodes;

#[test]
unconstrained fn create_coffin() {
    let (
        env,
        reward_token_contract_address,
        staking_token_contract_address,
        vanhelsing_contract_address,
        owner
    ) = utils::setup_and_mint(true);

    env.impersonate(owner);

    let rewards_amount = 1000;
    let nonce = 100;
    let public_transfer_from_call_interface = Token::at(reward_token_contract_address).transfer_public(owner, vanhelsing_contract_address, rewards_amount, nonce);
    authwit_cheatcodes::add_public_authwit_from_call_interface(
        owner,
        vanhelsing_contract_address,
        public_transfer_from_call_interface
    );

    let create_coffin_call_interface = Vanhelsing::at(vanhelsing_contract_address).createCoffin(
        staking_token_contract_address,
        reward_token_contract_address,
        30,
        rewards_amount,
        nonce
    );
    env.call_public(create_coffin_call_interface);
}
