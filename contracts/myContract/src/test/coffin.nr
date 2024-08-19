use crate::test::utils;
use crate::Vanhelsing;
use dep::aztec::test::{helpers::{cheatcodes, test_environment::TestEnvironment}};
use dep::aztec::protocol_types::storage::map::derive_storage_slot_in_map;
use dep::aztec::note::note_getter::{MAX_NOTES_PER_PAGE, view_notes};
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::token::Token;
use dep::std::println;

#[test]
unconstrained fn create_coffin() {
    let (
        env,
        reward_token_contract_address,
        staking_token_contract_address,
        vanhelsing_contract_address
    ) = utils::setup_and_mint(false);

    let create_coffin_call_interface = Vanhelsing::at(vanhelsing_contract_address).createCoffin(
        staking_token_contract_address,
        reward_token_contract_address,
        30,
        1000,
        100
    );
   
    env.call_public(create_coffin_call_interface);
}
