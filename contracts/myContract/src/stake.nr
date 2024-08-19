use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize, ToField}};
use crate::coffin::Vampire;

struct Stake {
    staker:  AztecAddress,
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
        self.targetedVampire.wallet.to_field()  +  
        self.targetedVampire.firstStakeStart as Field  +  
        self.targetedVampire.numberOfStakers as Field  +  
        self.targetedVampire.alive as Field  +  
        self.stakeAmount.to_integer()  +   
        self.start as Field  + 
        self.end as Field  + 
        self.isActive as Field  + 
        self.awarded.to_integer()
    }
}

global STAKE_SERIALIZED_LEN: Field = 11;

impl Serialize<STAKE_SERIALIZED_LEN> for Stake {
    fn serialize(stake: Stake) -> [Field; STAKE_SERIALIZED_LEN] {
        [
            stake.staker.to_field(),
            stake.targetedVampire.wallet.to_field(),
            stake.targetedVampire.firstStakeStart as Field,
            stake.targetedVampire.numberOfStakers as Field,
            stake.targetedVampire.alive as Field,
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
        let vampire = Vampire::deserialize([fields[1], fields[2], fields[3], fields[4]]);
        let stakeAmount =  U128 { lo: fields[5], hi: fields[6] };
        let start =  fields[6] as u64;
        let end = fields[7] as u64;
        let isActive = fields[8] as bool;
        let awarded = U128 { lo: fields[9], hi: fields[10] };

        Stake {
            staker,
            targetedVampire: vampire,
            stakeAmount,
            start,
            end,
            isActive,
            awarded,
        }
    }
}

impl Stake {}
