use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};
use dep::aztec::{protocol_types::{traits::{ToField, FromField}, constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL}};
use dep::token::Token;
use crate::stake::Stake;

global STAKE_THRESHOLD = 8;

struct Vampire {
    wallet: AztecAddress,
    numberOfStakers: u32,
    feeRate: U128,
    isAlive: bool,
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
        let numberOfStakers = fields[1] as u32;
        let feeRate = U128::from_integer(fields[2]);
        let isAlive = fields[3] as bool;
        
        Vampire {
            wallet,
            numberOfStakers,
            feeRate,
            isAlive
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
        lastDistribution: u64,
        firstStakeStart: u64, // start timestamp of fist stake
        stakesEndMax: u64, // maximum end time of all stakes
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
        self.vampire.numberOfStakers as Field  +  
        self.vampire.feeRate.to_field()  +  
        self.vampire.isAlive as Field  +  
        self.currentFee.to_integer()  +   
        self.stakingToken.to_field()   +   
        self.rewardsToken.to_field()  + 
        self.rewardsReserve.to_integer()   + 
        self.periodInDays as Field  + 
        self.rewardsPerDay as Field  + 
        self.lastDistribution.to_field()  + 
        self.firstStakeStart as Field  + 
        self.stakesEndMax as Field  + 
        self.idleDays as Field  + 
        self.allStakesNumber as Field  + 
        self.activeStakesNumber as Field  + 
        (self.isActive as Field )*65536
    }
}

#[test]
fn test_to_from_field() {
    let field = 1234567890;
    // let coffin = Coffin::from_field(field);
    // assert(coffin.to_field() == field);
}

global COFFIN_SERIALIZED_LEN: Field = 18;

impl Serialize<COFFIN_SERIALIZED_LEN> for Coffin {
    fn serialize(Coffin: Coffin) -> [Field; COFFIN_SERIALIZED_LEN] {
        [
            Coffin.vampire.wallet.to_field(),
            Coffin.vampire.numberOfStakers as Field,
            Coffin.vampire.feeRate.to_field(),
            Coffin.vampire.isAlive as Field,
            Coffin.currentFee.lo,
            Coffin.currentFee.hi,
            Coffin.stakingToken.to_field(),
            Coffin.rewardsToken.to_field(),
            Coffin.rewardsReserve.lo,
            Coffin.rewardsReserve.hi,
            Coffin.periodInDays as Field,
            Coffin.rewardsPerDay as Field,
            Coffin.lastDistribution as Field  + 
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

        Coffin {
            vampire,
            currentFee: U128 { lo: fields[4], hi: fields[5] },
            stakingToken: AztecAddress::from_field(fields[6]),
            rewardsToken: AztecAddress::from_field(fields[7]),
            rewardsReserve:  U128 { lo: fields[8], hi: fields[9] },
            periodInDays: fields[10] as u64,
            rewardsPerDay: fields[11] as u64,
            lastDistribution: fields[12] as u64,
            firstStakeStart: fields[13] as u64,
            stakesEndMax: fields[14] as u64,
            idleDays: fields[15] as u64,
            allStakesNumber: fields[16] as u64,
            activeStakesNumber: fields[17] as u64,
            isActive: fields[18] as bool,
        }
    }
}

impl Coffin {
    fn create_coffin(&mut self, coffin: Coffin) -> bool {
        let mut created = false;
        let mut entry = coffin;
        if entry.is_activated() {
            assert(!self.vampire.wallet.eq(coffin.vampire.wallet), "Coffin exists.");
        } else if !created {
            self.vampire = coffin.vampire;
            self.currentFee = coffin.currentFee;
            self.stakingToken = coffin.stakingToken;
            self.rewardsToken = coffin.rewardsToken;
            self.rewardsReserve = coffin.rewardsReserve;
            self.periodInDays = coffin.periodInDays;
            self.rewardsPerDay = coffin.rewardsPerDay;
            self.lastDistribution = coffin.lastDistribution;
            self.firstStakeStart = coffin.firstStakeStart;
            self.stakesEndMax = coffin.stakesEndMax;
            self.idleDays = coffin.idleDays;
            self.allStakesNumber = coffin.allStakesNumber;
            self.activeStakesNumber = coffin.activeStakesNumber;
            self.isActive = true;
            created = true;
        }
        created
    }

    pub fn is_activated(&mut self) -> bool {
        self.isActive
    }

    pub fn addFunds(&mut self, rewardsAmount: Field, currentTime: u64, stake: Stake) {
        assert(U128::from_integer(rewardsAmount) > U128::from_integer(0), "Wrong amount");
        assert(self.getCoffinDaysLeft(currentTime) > 0, "Coffin expired");

        // Calculate rewards with old rewardsPerDay till yesterday and store result
        self.distributeRewards(currentTime, stake);

        // From current time we will count rewardsPerDay with the added funds.
        self.updateRewardsPerDayAndRewardsBalance(rewardsAmount, currentTime);
    }

    pub fn getCoffinDaysLeft(&mut self, currentTime: u64) -> u64 {
        let coffinPeriod = self.periodInDays;
        if (U128::from_integer(self.firstStakeStart) == (U128::from_integer(0))) {
            coffinPeriod
        } else {
            let mut activeTimePassed = 0; // How long coffin was active (had stakes), the current time is not included
            if ((U128::from_integer(self.stakesEndMax)) < U128::from_integer(currentTime)) {
                // If last stake finished before present moment we have to count active time
                // till the end of last stake
                activeTimePassed = self.stakesEndMax - self.firstStakeStart + 1;
            } else {
                // In case there are active stakes now we just count time till current time as active, the current time is not included
                activeTimePassed = currentTime -self.firstStakeStart;
            }

            activeTimePassed = activeTimePassed - self.idleDays;

            coffinPeriod - activeTimePassed
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
            self.rewardsPerDay = self.rewardsPerDay + (rewardsAmountAdded *1000) as u64 / daysLeft; // we store rewardsPerDay multiplied by 1000
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

    pub fn addStakeNumbers(&mut self) {
        self.activeStakesNumber += 1;
    }

    pub fn reduceStakeNumbers(&mut self) {
        self.activeStakesNumber -= 1;
    }


    pub fn distributeRewards(&mut self, currentTime: u64, stake: Stake) {
        let rewardsPerDay = self.rewardsPerDay;
        let activeStakesNumber = self.activeStakesNumber;
        let lastDistribution = self.lastDistribution;
        let mut theStake = stake;
        // We count rewards till yesterday only, because today we can receive new stakes
        if (rewardsPerDay > 0 & activeStakesNumber > 0 & lastDistribution < (currentTime - 1)) {
            for day in (lastDistribution + 1) .. currentTime {
                let mut dayTotal =0; // total sum for all stakes (stakeAmount * remaining days) for current day to get then share of this total
                // In this loop we calculate total sum for all stakes (stakeAmount * remaining days) to get then share of this total
                if ((theStake.end >= day) & (theStake.start <= day) ) {
                        let daysCoeff = theStake.end - day + 1;
                        let dayStakeFactor = U128::from_integer(daysCoeff as Field) * theStake.stakeAmount ;
                        dayTotal += dayStakeFactor.to_field();
                }
                if (U128::from_integer(dayTotal) > U128::from_integer(0)) {
                    // In this loop we calculate share in this day rewards and add it to awarded field
                    if (theStake.end >= day & theStake.start <= day) {
                        let daysCoeff = theStake.end - day + 1;
                        let dayStakeFactor = daysCoeff as Field * theStake.stakeAmount.to_field();
                        let share = self.preciseDiv( dayStakeFactor, dayTotal, 2 ); // Share in percents
                        let mut todayStakeReward = rewardsPerDay as Field * share;
                        todayStakeReward = todayStakeReward / 100; // Round down. Remaining rewards will be sent to fee receiver
                        theStake.awarded += U128::from_integer(todayStakeReward);
                    }
                }
            }
            self.lastDistribution = currentTime - 1;
        }
    }

    pub fn preciseDiv(&mut self, _numerator: Field, _denominator: Field, _precision: Field) -> pub Field {
        let mut numerator = _numerator * (10.pow_32(_precision + 1));
        // with rounding of last digit
        let quotient = ((numerator / _denominator) + 5) / 10;
        quotient
    }

}
