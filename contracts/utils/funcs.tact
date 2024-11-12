/*
 * Contract for organizing early rounds, presales, firelaunches and token listing on DEX.
 * https://multixplatform.io
 * 
 * By using this contract, you agree that you have carefully studied the logic of this contract and understand that working 
 * with cryptocurrency carries risks that you assume entirely on yourself.
 * 
 * Modification of this contract for commercial purposes outside of our official repository is prohibited.
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
 * IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Copyright © Multix. All rights reserved. 
 */

import "./storage_structs.tact";

const nanoTons: Int =  1000000000;
const milliTons: Int = 1000000;
const killoTons: Int = 1000;
const hectoTons: Int = 100;

const kDaysAYear: Int = 365;
const kUnlockDays: Int = 365;
const kCapMaxInaccuracy: Int = ton("0.5");

//Asset type
const kAssetTypeJetton: Int = 1;
const kAssetTypeTON: Int = 3;

//Sale type
const kSaleTypePresale: Int = 1;            //presale
const kSaleTypeFairlunch: Int = 3;          //fairlunch
const kSaleTypeEarlyRound: Int = 5;         //early round

//DEX
const kDEXDedust: Int = 1005;               //Dedust

//Other
const kMaxDAOHoldersSize: Int = 1000;
const kMaxDaoNotAllocatedForAutoListing: Int = ton("100");      //Autolisting will happen even if there are still so many coins free

@name(calculate_user_jetton_wallet_address)
native calculate_user_jetton_wallet_address(owner_address: Slice, jetton_master_address: Slice, jetton_wallet_code: Cell): Slice;

/*
 * This function calculates the total unlocked amount of tokens based on the unlock options and current time.
 * It takes into account the initial unlock percentage at the TGE (unlockStartTime) and applies vesting
 * cycles to unlock additional tokens. Each cycle unlocks a specified percentage (cyclePercent) after a
 * certain number of days (cyclesDays).
 *
 * Parameters:
 *  - totalAmount: The total amount of tokens initially locked.
 *  - unlockOptions: Struct containing vesting parameters such as unlockStartTime, unlockPercent, cyclesDays, and cyclePercent.
 *  - currentTime: The current time in seconds (UNIX timestamp).
 *
 * Returns:
 *  - The total amount of tokens that are unlocked by the current time.
 */
fun calculateUnlockedAmount(totalAmount: Int, unlockOptions: UnlockOptions, currentTime: Int): Int {
    // If the current time is before TGE, nothing is unlocked
    if (currentTime < unlockOptions.unlockStartTime) {
        return 0;
    }

    // Unlock TGE only
    if (unlockOptions.unlockPercentHecto >= 100 * hectoTons) {
        return totalAmount;
    }

    // Amount unlocked at TGE
    let unlockedAmount: Int = (totalAmount * unlockOptions.unlockPercentHecto) / (100 * hectoTons);

    // Time elapsed since unlockStartTime, in seconds
    let timeElapsed: Int = currentTime - unlockOptions.unlockStartTime;

    // Convert elapsed time to days (86400 seconds in one day)
    let daysElapsed: Int = timeElapsed / 86400;

    // Unlock calculation for phase A
    if ((unlockOptions.cycleDaysOffsetA > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetA) && (unlockOptions.cyclesDaysA > 0)) {
        let activeDaysA = daysElapsed - unlockOptions.cycleDaysOffsetA + 1;

        // If phase B exists and has started, limit activeDaysA to the start of phase B
        if ((unlockOptions.cycleDaysOffsetB > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetB) && (unlockOptions.cyclesDaysB > 0)) {
            activeDaysA = unlockOptions.cycleDaysOffsetB - unlockOptions.cycleDaysOffsetA + 1;
        }

        let completedCyclesA = activeDaysA / unlockOptions.cyclesDaysA;
        unlockedAmount += (totalAmount * unlockOptions.cyclePercentHectoA * completedCyclesA) / (100 * hectoTons);
    }

    // Unlock calculation for phase B
    if ((unlockOptions.cycleDaysOffsetB > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetB) && (unlockOptions.cyclesDaysB > 0)) {
        let activeDaysB = daysElapsed - unlockOptions.cycleDaysOffsetB + 1;

        // If phase C exists and has started, limit activeDaysB to the start of phase C
        if ((unlockOptions.cycleDaysOffsetC > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetC) && (unlockOptions.cyclesDaysC > 0)) {
            activeDaysB = unlockOptions.cycleDaysOffsetC - unlockOptions.cycleDaysOffsetB + 1;
        }

        let completedCyclesB = activeDaysB / unlockOptions.cyclesDaysB;
        unlockedAmount += (totalAmount * unlockOptions.cyclePercentHectoB * completedCyclesB) / (100 * hectoTons);
    }

    // Unlock calculation for phase C
    if ((unlockOptions.cycleDaysOffsetC > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetC) && (unlockOptions.cyclesDaysC > 0)) {
        let activeDaysC = daysElapsed - unlockOptions.cycleDaysOffsetC + 1;

        // If phase D exists and has started, limit activeDaysC to the start of phase D
        if ((unlockOptions.cycleDaysOffsetD > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetD) && (unlockOptions.cyclesDaysD > 0)) {
            activeDaysC = unlockOptions.cycleDaysOffsetD - unlockOptions.cycleDaysOffsetC + 1;
        }

        let completedCyclesC = activeDaysC / unlockOptions.cyclesDaysC;
        unlockedAmount += (totalAmount * unlockOptions.cyclePercentHectoC * completedCyclesC) / (100 * hectoTons);
    }

    // Unlock calculation for phase D
    if ((unlockOptions.cycleDaysOffsetD > 0) && (daysElapsed >= unlockOptions.cycleDaysOffsetD) && (unlockOptions.cyclesDaysD > 0)) {
        let activeDaysD = daysElapsed - unlockOptions.cycleDaysOffsetD + 1;
        let completedCyclesD = activeDaysD / unlockOptions.cyclesDaysD;
        unlockedAmount += (totalAmount * unlockOptions.cyclePercentHectoD * completedCyclesD) / (100 * hectoTons);
    }

    // Cap the unlocked amount to the total amount (security check)
    if (unlockedAmount > totalAmount) {
        return totalAmount;
    }

    return unlockedAmount;
}

fun calculateUnlockedDaysElapsed(unlockOptions: UnlockOptions, currentTime: Int): Int {
    // If the current time is before TGE, nothing is unlocked
    if (currentTime < unlockOptions.unlockStartTime) {
        return 0;
    }

    // Unlock TGE only
    if (unlockOptions.unlockPercentHecto >= 100 * hectoTons) {
        return 0;
    }

    // Time elapsed since unlockStartTime, in seconds
    let timeElapsed: Int = currentTime - unlockOptions.unlockStartTime;

    // Convert elapsed time to days (86400 seconds in one day)
    let daysElapsed: Int = timeElapsed / 86400;
    return daysElapsed;
}

/*
 * Checks the correctness of filling in the field "unlockOptions"
 * It is necessary that there are no incorrect data in the contract
 * Additionally, conduct a self-diagnosis, so that after 3 years all funds will be unblocked
*/
fun checkUnlockOptions(unlockOptions: UnlockOptions): Int {
    if (unlockOptions.unlockStartTime != 0) {
        return -100;
    }

    if (unlockOptions.unlockPercentHecto == 100 * hectoTons) {
        if (
            unlockOptions.cyclesDaysA != 0 ||
            unlockOptions.cyclesDaysB != 0 ||
            unlockOptions.cyclesDaysC != 0 ||
            unlockOptions.cyclesDaysD != 0
        ) {
            return -3000;
        }
        if (
            unlockOptions.cycleDaysOffsetA != 0 ||
            unlockOptions.cycleDaysOffsetB != 0 ||
            unlockOptions.cycleDaysOffsetC != 0 ||
            unlockOptions.cycleDaysOffsetD != 0
        ) {
            return -3001;
        }
        if (
            unlockOptions.cyclePercentHectoA != 0 ||
            unlockOptions.cyclePercentHectoB != 0 ||
            unlockOptions.cyclePercentHectoC != 0 ||
            unlockOptions.cyclePercentHectoD != 0
        ) {
            return -3002;
        }

        //Additional self-diagnostics are performed
        if (calculateUnlockedAmount(12345, unlockOptions, 86400 * 365 * 3) != 12345) {
            return -3020;
        }
        if (calculateUnlockedAmount(nanoTons, unlockOptions, 86400 * 365 * 100) != nanoTons) {
            return -3021;
        }
        
        return 1;
    }

    if (unlockOptions.unlockPercentHecto < 0 || unlockOptions.unlockPercentHecto > 100 * hectoTons) {
        return -1000;
    }

    if (unlockOptions.cyclesDaysA <= 0) {
        return -1001;
    }
    if (unlockOptions.cyclesDaysA > 365) {
        return -1002;
    }
    if (unlockOptions.cycleDaysOffsetA <= 0 || unlockOptions.cycleDaysOffsetA > 365) {
        return -1003;
    }
    if (unlockOptions.cyclePercentHectoA <= 0 || unlockOptions.cyclePercentHectoA > 100 * hectoTons) {
        return -1004;
    }

    if (
        ((unlockOptions.cycleDaysOffsetD != 0) && (unlockOptions.cycleDaysOffsetD < unlockOptions.cycleDaysOffsetC)) ||
        ((unlockOptions.cycleDaysOffsetC != 0) && (unlockOptions.cycleDaysOffsetC < unlockOptions.cycleDaysOffsetB)) ||
        ((unlockOptions.cycleDaysOffsetB != 0) && (unlockOptions.cycleDaysOffsetB < unlockOptions.cycleDaysOffsetA))
    ) {
        return -1005;
    }

    if (unlockOptions.cycleDaysOffsetB > 0) {
        if (
            (unlockOptions.cyclesDaysB <= 0) || (unlockOptions.cyclesDaysB > 365) ||
            (unlockOptions.cyclePercentHectoB <= 0) || (unlockOptions.cyclePercentHectoB > 100 * hectoTons)
        ) {
            return -1010;
        }
    }

    if (unlockOptions.cycleDaysOffsetC > 0) {
        if (
            (unlockOptions.cyclesDaysC <= 0) || (unlockOptions.cyclesDaysC > 365) ||
            (unlockOptions.cyclePercentHectoC <= 0) || (unlockOptions.cyclePercentHectoC > 100 * hectoTons)
        ) {
            return -1011;
        }
    }

    if (unlockOptions.cycleDaysOffsetD > 0) {
        if (
            (unlockOptions.cyclesDaysD <= 0) || (unlockOptions.cyclesDaysD > 365) ||
            (unlockOptions.cyclePercentHectoD <= 0) || (unlockOptions.cyclePercentHectoD > 100 * hectoTons)
        ) {
            return -1012;
        }
    }

    /*
     * Additional self-diagnostics are performed
     * After 3 years, all funds must be 100% unblocked
    */
    if (calculateUnlockedAmount(12345, unlockOptions, 86400 * 365 * 3) != 12345) {
        return -1020;
    }
    if (calculateUnlockedAmount(nanoTons, unlockOptions, 86400 * 365 * 100) != nanoTons) {
        return -1021;
    }

    return 1;
}

/*
 * VaultNative.createDepositLiquidityPayload
*/
fun getDedustTONTransferPayload(asset0Cell: Cell, asset1Cell: Cell, tonAmount: Int, scaleAmount: Int): Cell {
    return beginCell()
        .storeUint(0xd55e4686, 32)                        //storeUint(VaultNative.DEPOSIT_LIQUIDITY, 32)
        .storeUint(0, 64)                                 //storeUint(queryId ?? 0, 64)
        .storeCoins(tonAmount)                            //storeCoins(amount)
        .storeUint(0, 1)                                  //storeUint(poolType, 1)
        .storeSlice(asset0Cell.asSlice())                 //storeSlice(assets[0].toSlice())
        .storeSlice(asset1Cell.asSlice())                 //storeSlice(assets[1].toSlice())
        .storeRef(
            beginCell()
                .storeCoins(0)                                    //storeCoins(minimalLPAmount ?? 0)
                .storeCoins(tonAmount)                            //storeCoins(targetBalances[0])
                .storeCoins(scaleAmount)                          //storeCoins(targetBalances[0])
                .endCell()
        )
        .storeBool(false)                                 //storeMaybeRef(fulfillPayload)
        .storeBool(false)                                 //storeMaybeRef(rejectPayload)
        .endCell();
}

/*
 * VaultJetton.createDepositLiquidityPayload
*/
fun getDedustJettonTransferPayload(asset0Cell: Cell, asset1Cell: Cell, tonAmount: Int, scaleAmount: Int): Cell {
    return beginCell()
        .storeUint(0x40e108d6, 32)                        //storeUint(VaultJetton.DEPOSIT_LIQUIDITY, 32)
        .storeUint(0, 1)                                  //storeUint(poolType, 1)
        .storeSlice(asset0Cell.asSlice())                 //storeSlice(assets[0].toSlice())
        .storeSlice(asset1Cell.asSlice())                 //storeSlice(assets[1].toSlice())
        .storeCoins(0)                                    //storeCoins(minimalLpAmount ?? 0)
        .storeCoins(tonAmount)                            //storeCoins(targetBalances[0])
        .storeCoins(scaleAmount)                          //storeCoins(targetBalances[1])
        .storeBool(false)                                 //storeMaybeRef(fulfillPayload)
        .storeBool(false)                                 //storeMaybeRef(rejectPayload)
        .endCell();
}

/*
 * Jetton Mint Body
*/
fun getJettonMintBody(destination: Address, tonAmount: Int, jettonAmount: Int, fromAddress: Address, forwardAmount: Int): Cell {
    return beginCell()
        .storeUint(21, 32) 					           // OP mint
        .storeUint(0, 64) 	                           // query_id
        .storeAddress(destination)
        .storeCoins(tonAmount)
        .storeRef(
            beginCell()
                .storeUint(0x178d4519, 32)
                .storeUint(0, 64)
                .storeCoins(jettonAmount)
                .storeAddress(fromAddress)
                .storeUint(0, 2)
                .storeCoins(forwardAmount)
                .storeBool(false)
                .endCell()
        )
        .endCell();
}

/*
 * Jetton Revoke Access
*/
fun getJettonRevokeAccessBody(): Cell {
    return beginCell()
        .storeUint(3, 32)
        .storeUint(0, 64) 	// query_id
        .storeAddress(address("0:0000000000000000000000000000000000000000000000000000000000000000"))
        .endCell();
}

fun getSaleTypeName(saleType: Int): String? {
    if (saleType == kSaleTypePresale) {
        return "presale";
    }
    if (saleType == kSaleTypeFairlunch) {
        return "fairlunch";
    }
    if (saleType == kSaleTypeEarlyRound) {
        return "early round";
    }
    return null;
}

fun getDexName(dexKey: Int): String {
    if (dexKey == kDEXDedust) {
        return "Dedust";
    }

    return dexKey.toString();
}

fun getStorageBuyRequestErrorName(errorCode: Int): String {
    if (errorCode == 1000) {
        return "Purchase limit exceeded";
    }
    if (errorCode == 1001) {
        return "Purchase amount is too low";
    }

    return errorCode.toString();
}

fun mathDivisionCeil(a: Int, b: Int): Int {
    return (a % b == 0) ? (a / b) : ((a / b) + 1);
}