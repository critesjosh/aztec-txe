use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize, ToField}};
use crate::coffin::{Vampire, Coffin};

struct Stake {
    staker:  AztecAddress,
    stakeID:  u64,
    targetedVampire:  Vampire, // reward pool
    stakeAmount: U128,
    start: u64,
    end: u64,
    isActive: bool,
    awarded:U128

}

impl Stake {
    pub fn is_initialized(self) -> bool {
        self.start > 0
    }
}

impl ToField for Stake {
 fn to_field(self) -> Field {
        (self.staker.to_field())*65536  +  
        self.stakeID as Field  + 
        self.targetedVampire.wallet.to_field()  +  
        self.targetedVampire.numberOfStakers as Field  +  
        self.targetedVampire.isAlive as Field  +  
        self.stakeAmount.to_integer()  +   
        self.start as Field  + 
        self.end as Field  + 
        self.isActive as Field  + 
        self.awarded.to_integer()
    }
}

global STAKE_SERIALIZED_LEN: Field = 12;

impl Serialize<STAKE_SERIALIZED_LEN> for Stake {
    fn serialize(stake: Stake) -> [Field; STAKE_SERIALIZED_LEN] {
        [
            stake.staker.to_field(),
            stake.stakeID as Field,
            stake.targetedVampire.wallet.to_field(),
            stake.targetedVampire.numberOfStakers as Field,
            stake.targetedVampire.feeRate.to_field(),
            stake.targetedVampire.isAlive as Field,
            stake.stakeAmount.lo,
            stake.stakeAmount.hi,
            stake.start as Field,
            stake.end as Field,
            stake.isActive as Field,
            stake.awarded.to_integer(),
        ]
    }
}

impl Deserialize<STAKE_SERIALIZED_LEN> for Stake {
    fn deserialize(fields: [Field; STAKE_SERIALIZED_LEN]) -> Stake {
        let staker = AztecAddress::from_field(fields[0]);
        let stakeID =  fields[1] as u64;
        let vampire = Vampire::deserialize([fields[2], fields[3], fields[4], fields[5]]);
        let stakeAmount =  U128 { lo: fields[6], hi: fields[7] };
        let start =  fields[8] as u64;
        let end = fields[9] as u64;
        let isActive = fields[10] as bool;
        let awarded = U128 { lo: fields[10], hi: fields[12] };

        Stake {
            staker,
            stakeID,
            targetedVampire: vampire,
            stakeAmount,
            start,
            end,
            isActive,
            awarded,
        }
    }
}

impl Stake {
    fn start_staking(&mut self, stake: Stake) -> bool {
        let mut created = false;
        let mut entry = stake;
        if entry.is_activated() {
            assert((self.stakeID == 0) & (stake.stakeID > 0 as u64), "Wrong StakeID.");
        } else if !created {
            self.staker= stake.staker;
            self.stakeID= stake.stakeID;
            self.targetedVampire= stake.targetedVampire;
            self.stakeAmount= stake.stakeAmount;
            self.start= stake.start;
            self.end= stake.end;
            self.isActive= stake.isActive;
            self.awarded= stake.awarded;

            created = true;
        }
        created
    }

    pub fn sendRewards(&mut self, feeTo: AztecAddress, coffin: Coffin) {
        let vampire = self.targetedVampire;
        assert(self.isActive == false, "Stake is active");

        let awardedAmount = self.getAwardedAmount();
        let mut theCoffin = coffin;

        if (awardedAmount > U128::from_integer(0)) {
            let mut feeAmount = 0;
            let feeRate = theCoffin.vampire.feeRate;
            if ((!feeTo.is_zero()) & (feeRate > U128::from_integer(0))) {
                let numerator = U128::from_integer(awardedAmount) * feeRate;
                let denominator = 10000;
                feeAmount = theCoffin.preciseDiv(numerator.to_field(), denominator, 0);
            }

            let rewardsBalance = coffin.rewardsReserve - awardedAmount;
            //     ERC20 rewardsToken = ERC20(rewardsTokenAddress);
            //     if (feeTo != address(0) && feeAmount > 0) {
            //         require(
            //             rewardsToken.transfer(feeTo, feeAmount),
            //             "Fee transfer failed"
            //         );
            //     }
            //     require(
            //         rewardsToken.transfer(
            //             vampire.getStakerAddress(stakeID),
            //             awardedAmount - feeAmount
            //         ),
            //         "Rewards transfer failed"
            //     );
        }
        // Close coffin if this is a last stake and coffin period is finished
        // if (
        //     vampire.activeStakesNumber() == 0 &
        //     vampire.getCoffinDaysLeft() == 0
        // ) {
        //     self.autoClose();
        // }
    }

    pub fn is_activated(&mut self) -> bool {
        self.isActive
    }

    pub fn end_staking(&mut self) {
        self.isActive = false;
    }

    pub fn getAwardedAmount(&mut self) -> pub U128 {
        self.awarded / U128::from_integer(1000) // We store awarded multiplied by 1000. Make division to get real amount of rewards
    }
}
