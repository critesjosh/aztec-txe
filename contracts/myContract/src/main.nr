mod coffin;
mod stake;
mod test;

contract Vanhelsing {
    use dep::token::Token;
    use crate::coffin::{Vampire, Coffin};
    use crate::stake::Stake;
    use dep::aztec::{prelude::{PublicMutable, AztecAddress, Map}};

    #[aztec(storage)]
    struct Storage {
        coffins: Map<Field, PublicMutable<Coffin>>,
        stakes: Map<Field, PublicMutable<Stake>>,
        feeTo: PublicMutable<AztecAddress>,
        currentFee:  PublicMutable<Field>,
        minCoffinPeriod:  PublicMutable<Field>,
        maxCoffinPeriod:  PublicMutable<Field>,
        minStakePeriod:  PublicMutable<Field>,
        maxStakePeriod:  PublicMutable<Field>,
    }

    #[aztec(public)]
    #[aztec(initializer)]
    fn constructor(
        feeTo: AztecAddress,
        currentFee: Field,
        minCoffinPeriod: Field,
        maxCoffinPeriod: Field,
        minStakePeriod: Field,
        maxStakePeriod: Field
    ) {
        storage.feeTo.write(feeTo);
        storage.currentFee.write(currentFee);
        storage.minCoffinPeriod.write(minCoffinPeriod);
        storage.maxCoffinPeriod.write(maxCoffinPeriod);
        storage.minStakePeriod.write(minStakePeriod);
        storage.maxStakePeriod.write(maxStakePeriod);
    }

    #[aztec(public)]
    fn createCoffin(
        stakingToken: AztecAddress,
        rewardsToken: AztecAddress,
        periodInDays: Field,
        rewardsAmount: Field,
        nonce: Field
    ) {
        assert(!stakingToken.is_zero(), "Staking token is zero");
        assert(!rewardsToken.is_zero(), "Rewards token is zero");
        assert(U128::from_integer(rewardsAmount) > U128::from_integer(0), "Wrong rewards amount");
        assert(
            U128::from_integer(periodInDays) >= U128::from_integer(storage.minCoffinPeriod.read()), "The period is too short"
        );
        assert(
            U128::from_integer(periodInDays) <= U128::from_integer(storage.maxCoffinPeriod.read()), "The period is too long"
        );
        // transfer reward to this contract
        println(context.msg_sender());
        println(context.this_address());
        println(rewardsToken);

        Token::at(rewardsToken).transfer_public(
            context.msg_sender(),
            context.this_address(),
            rewardsAmount,
            nonce
        ).call(&mut context);

    }

}
