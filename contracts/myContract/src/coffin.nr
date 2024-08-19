use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};
use dep::aztec::{protocol_types::{traits::{ToField, FromField}, constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL}};
use dep::token::Token;

global STAKE_THRESHOLD = 8;

struct Vampire {
    wallet: AztecAddress,
    firstStakeStart: u64,// start day of fist stake
    numberOfStakers: u32,
    alive: bool,
}

impl Vampire {
    pub fn is_initialized(self) -> bool {
        !self.wallet.is_zero()
    }
}

global VAMPIRE_SERIALIZED_LEN: Field = 4;

impl Deserialize<VAMPIRE_SERIALIZED_LEN> for Vampire {
    fn deserialize(fields: [Field; VAMPIRE_SERIALIZED_LEN]) -> Vampire {
        let wallet =  AztecAddress::from_field(fields[0]);
        let firstStakeStart = fields[1] as u64;
        let numberOfStakers = fields[2] as u32;
        let alive = fields[3] as bool;
        
        Vampire {
            wallet,
            firstStakeStart,
            numberOfStakers,
            alive
        }
    }
}

struct Coffin {
        vampire: Vampire,
        currentFee: U128,
        stakingToken: AztecAddress,
        rewardsToken: AztecAddress,
        rewardsReserve: U128,
        periodInDays: u64,
        rewardsPerDay: u64, 
        firstStakeStart: u64, // start timestamp of fist stake
        stakesEndMax: u64, // maximum end time of stakes
        idleDays: u64, // idle time in days
        allStakesNumber:u64,
        activeStakesNumber:u64,
        isActive: bool 
}

// impl FromField for Coffin {
//     fn from_field(field: Field) -> Coffin {

//     }
// }

impl ToField for Coffin {
 fn to_field(self) -> Field {
        self.vampire.wallet.to_field()  +  
        self.vampire.firstStakeStart as Field  +  
        self.vampire.numberOfStakers as Field  +  
        self.vampire.alive as Field  +  
        self.currentFee.to_integer()  +   
        self.stakingToken.to_field()   +   
        self.rewardsToken.to_field()  + 
        self.rewardsReserve.to_integer()   + 
        self.periodInDays as Field  + 
        self.rewardsPerDay as Field  + 
        self.firstStakeStart as Field  + 
        self.stakesEndMax as Field  + 
        self.idleDays as Field  + 
        self.idleDays as Field  + 
        self.allStakesNumber as Field  + 
        self.activeStakesNumber as Field  + 
        (self.stakingToken.to_field())*65536
    }
}

#[test]
fn test_to_from_field() {
    let field = 1234567890;
    // let coffin = Coffin::from_field(field);
    // assert(coffin.to_field() == field);
}

global COFFIN_SERIALIZED_LEN: Field = 16;

impl Serialize<COFFIN_SERIALIZED_LEN> for Coffin {
    fn serialize(Coffin: Coffin) -> [Field; COFFIN_SERIALIZED_LEN] {
        [
            Coffin.vampire.wallet.to_field(),
            Coffin.vampire.alive as Field,
            Coffin.currentFee.lo,
            Coffin.currentFee.hi,
            Coffin.stakingToken.to_field(),
            Coffin.rewardsToken.to_field(),
            Coffin.rewardsReserve.lo,
            Coffin.rewardsReserve.hi,
            Coffin.periodInDays as Field,
            Coffin.rewardsPerDay as Field,
            Coffin.firstStakeStart as Field,
            Coffin.stakesEndMax as Field,
            Coffin.idleDays as Field,
            Coffin.allStakesNumber as Field,
            Coffin.activeStakesNumber as Field,
            Coffin.isActive as Field
        ]
    }
}

impl Deserialize<COFFIN_SERIALIZED_LEN> for Coffin {
    fn deserialize(fields: [Field; COFFIN_SERIALIZED_LEN]) -> Coffin {
        let vampire = Vampire::deserialize([fields[0], fields[1], fields[2], fields[3]]);
        let currentFee = U128 { lo: fields[2], hi: fields[3] };
        let rewardsReserve = U128 { lo: fields[5], hi: fields[6] };

        Coffin {
            vampire,
            currentFee,
            stakingToken: AztecAddress::from_field(fields[3]),
            rewardsToken: AztecAddress::from_field(fields[4]),
            rewardsReserve,
            periodInDays: fields[6] as u64,
            rewardsPerDay: fields[7] as u64,
            firstStakeStart: fields[8] as u64,
            stakesEndMax: fields[9] as u64,
            idleDays: fields[10] as u64,
            allStakesNumber: fields[11] as u64,
            activeStakesNumber: fields[12] as u64,
            isActive: fields[13] as bool,
        }
    }
}

impl Coffin {
    pub fn activateCoffin(&mut self) {
        assert(!self.isActive, "Coffin already started");
        let vampire = self.vampire;
        assert(!vampire.is_initialized(), "Vampire already exists");
        self.isActive = true;
    }

    pub fn addFunds(&mut self, rewardsAmount: Field, currentTime: u64) {
        assert(U128::from_integer(rewardsAmount) > U128::from_integer(0), "Wrong amount");
        assert(self.getCoffinDaysLeft(currentTime) > 0, "Coffin expired");

        // Calculate rewards with old rewardsPerDay till yesterday and store result
        self.distributeRewards();

        // From today we will count rewardsPerDay with the added funds.
        self.updateRewardsPerDayAndRewardsBalance(rewardsAmount, currentTime);
    }

    pub fn getCoffinDaysLeft(&mut self, currentTime: u64) -> u64 {
        let coffinPeriod = self.periodInDays;
        if (U128::from_integer(self.firstStakeStart) == (U128::from_integer(0))) {
            coffinPeriod
        } else {
            let mut activeDaysPassed = 0; // How many days coffin was active (had stakes), the current time is not included
            if ((U128::from_integer(self.stakesEndMax)) < U128::from_integer(currentTime)) {
                // If last stake finished before present moment we have to count active days
                // till the end of last stake
                activeDaysPassed = self.stakesEndMax - self.firstStakeStart + 1;
            } else {
                // In case there are active stakes now we just count days till today as active days, the current day is not included
                activeDaysPassed = currentTime -self.firstStakeStart;
            }

            activeDaysPassed = activeDaysPassed - self.idleDays;

            coffinPeriod - activeDaysPassed
        }
    }

    pub fn updateRewardsPerDayAndRewardsBalance(
        &mut self,
        rewardsAmountAdded: Field,
        currentTime: u64
    ) {
        self.rewardsReserve = self.rewardsReserve + U128::from_integer(rewardsAmountAdded);
        let daysLeft = self.getCoffinDaysLeft(currentTime);
        if (daysLeft > 0) {
            self.rewardsPerDay = self.rewardsPerDay + rewardsAmountAdded as u64 / daysLeft; // we store rewardsPerDay multiplied by 1000
        }
    }

    pub fn checkPeriod(
        &mut self,
        daysLockedUp: Field,
        minStakePeriod: Field,
        maxStakePeriod: Field,
        currentTime: u64
    ) -> bool {
        if ((U128::from_integer(daysLockedUp) < U128::from_integer(minStakePeriod))
            | (U128::from_integer(daysLockedUp) > U128::from_integer(maxStakePeriod))) {
            false
        }
        let coffinDaysLeft = self.getCoffinDaysLeft(currentTime);
        (U128::from_integer(daysLockedUp) <= U128::from_integer(coffinDaysLeft))
    }

    pub fn updateStakeNumbers(&mut self) {
        self.activeStakesNumber += 1;
    }

    pub fn distributeRewards(&mut self) {}

    pub fn sendRewards(&mut self) {}

    pub fn startStaking(&mut self) {}

    pub fn endStaking(&mut self) {}
}
