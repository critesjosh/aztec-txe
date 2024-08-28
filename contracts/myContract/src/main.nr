mod test;
mod coffin;
mod stake;

contract Vanhelsing {
    use dep::token::Token;
    use dep::aztec::{prelude::{PublicMutable, AztecAddress, Map}};
    use crate::coffin::{Vampire, Coffin};

    #[aztec(storage)]
    struct Storage {
        coffins: Map<u64, PublicMutable<Coffin>>,
        coffinId:  PublicMutable<u64>,
        feeTo: PublicMutable<AztecAddress>,
    }

    #[aztec(public)]
    #[aztec(initializer)]
    fn constructor(
        feeTo: AztecAddress,
    ) {
        storage.feeTo.write(feeTo);
    }

    #[aztec(public)]
    fn createCoffin(
        stakingToken: AztecAddress,
        rewardsToken: AztecAddress,
        periodInDays: Field,
        rewardsAmount: Field,
        nonce: Field
    ) {

        Token::at(rewardsToken).transfer_public(
            context.msg_sender(),
            context.this_address(),
            rewardsAmount,
            nonce
        ).call(&mut context);
        let currentcoffinId = storage.coffinId.read();

        let coffin_storage = storage.coffins.at(currentcoffinId);
        println(coffin_storage);
        let mut coffin_data = coffin_storage.read(); // <======== Failed assertion
    }

}
