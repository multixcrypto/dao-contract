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

struct StateMessage {
    contractVersion: Int as uint32;                 //0. Contract version
    contractReady: Bool;                            //1. Contract ready for work
    
    contractID: Int as uint64;                      //2. Local contract ID
    jettonWalletAddress: Address?;                  //3. Contract that stores jettons
    creator: Address;                               //4. The wallet address from which the contract was created

    totalSupply: Int as coins;                      //5. Maximum number of jettons

    isTradeActive: Bool;                            //6. Flag that the contract was successfully initialized
    isTradeStopped: Bool;                           //7. Flag that participation in token sales is no longer available

    comissionAddress: Address;                      //8. Comission address
    comissionValue: Int as uint32;                  //9. Amount of transferred commission, milliTons

    airdropStarted: Bool;                           //10. Spread jetton A to jetton B started

    dexKey: Int;                                    //11. DEX Key

    dexPrepareWaitUntilTime: Int;                   //12. DEX wait after preparing pools
    dexClaimWaitUntilTime: Int;                     //13. DEX wait after listing

    sales: map<Int, SaleDetails>;                   //14. List of current sales
    salesCounter: Int;                              //15. How many sales were added
    
    salesSupply: Int;                               //16. Tokens allocated for sales
    salesClaimedTokens: Int;                        //17. How many tokens from "salesSupply" were taken by buyers
    salesFreeTokens: Int;                           //18. How many tokens from "salesSupply" available for claim

    daoSupply: Int;                                 //19. Tokens allocated to DAO (all other tokens)
    daoHoldersCoins: Int;                           //20. How much of coins has been allocated has owners
    daoHoldersTON: Int;                             //21. How much of TONs has been allocated has owners

    buyers: map<Int, SaleBuyers>;                   //22. List of buyers
    dexSettings: DEXSettings;                       //23. DEX listing options
    salesEx: map<Int, SaleDetailsEx>;               //24. List of current sales with additional details
    daoHoldersRecords: map<Int, DAOHolderRecord>;   //25. List of asset records in the DAO

    contractLocks: ContractLocks;                   //26. The state of the locks in the contract

    salesStat: SalesStat;                           //27. Current sales statistics
    isAutoListingAvailable: Bool;                   //28. Will there be an auto listing on DEX after the sale is completed
    burnedTokens: Int;                              //29. How many tokens were burned

    daoVetoState: DAOVetoState;                     //30. DAO Veto system state

    daoVetoEnabled: Bool;                           //31. DAO Veto module enabled
    botProtectionEnabled: Bool;                     //32. Bot protection module enabled
}

struct ContractLocks {
    daoHoldersLocked: Bool = false;           //Blocks the ability to add or delete records in the DAO
    salesLocked: Bool = false;                //Blocks the ability to add or cancel sales
}

/*
 * Notification of successful participation in the token sale
*/
struct SaleParticipateSuccess {
    opcode: Int as uint32 = 0x1099;

    storageAddress: Address;
    realBuyAmount: Int as coins;

    storageState: StorageStateMessage;
    commentPrefix: Int as uint32;
    comment: Slice;
}

/*
 * Notification of successful collection of token sale result
*/
struct SaleClaimSuccess {
    opcode: Int as uint32 = 0x3099;

    storageAddress: Address;
    
    haveCoins: Bool = false;
    assetAmount: Int as coins;

    storageState: StorageStateMessage;
    commentPrefix: Int as uint32;
    comment: Slice;
}

struct SaleOptions {
    saleIndex: Int as uint32;
    saleType: Int as uint8;                         //kSaleTypePresale - presale, kSaleTypeFairlunch - fairlunch, kSaleTypeEarlyRound - early round

    timeStart: Int as uint64;
    timeEnd: Int as uint64;
    isDateSet: Bool;

    capMin: Int as coins;
    capMax: Int as coins;

    buyPrice: Int as coins;
    minBuyTONAmount: Int as coins;
    maxBuyTONAmount: Int as coins;

    jettonsReserved: Int as coins;
}

/*
 * Information about the token sale
*/
struct SaleDetails {
    saleOptions: SaleOptions;
    saleIndex: Int;
    active: Bool;
    addTime: Int;
    completed: Bool = false;                                    //Set to true during first coin grab and adding an entry to DEX Holders
    completedSuccess: Bool = false;
    capMaxChecked: Int as coins;                                //This value is used to determine when the trade ends
}

/*
 * Additional information that did not fit due to the cell size
*/
struct SaleDetailsEx {
    unlockOptions: UnlockOptions;
    daoHolder: DAOHolderDetails;
}

struct SalesStat {
    confirmedBuyTONAmountWithoutEarly: Int;                 //Sum of confirmed purchases in sales excluding early round
    unfinishedSalesCount: Int;                              //How many more sales have not reached their completion date
    
    currentlyActiveCount: Int;                              //How many sales are currently ongoing

    firstFinishedSuccessTimeEnd: Int;                       //Date of the first successful token sale
    
    activeAll: Int;                                         //How many all sales are unfinished or successfully completed
    activeFairlunches: Int;                                 //How many fairlunches are unfinished or successfully completed
    
    finishedUncompletedCount: Int;                          //How many sales were successfully finished but not processed
}

struct PendingBuyers {
    clientAddress: Address;
    buyTONAmount: Int as coins;
}

//
const maxPendingBuyersListSize: Int = 30;              //Limit on the number of buyers on the waiting list

/*
 * List of participants in the sale
*/
struct SaleBuyers {
    nextBuyRequestID: Int as uint64 = 1000;

    confirmedBuyCount: Int as uint64 = 0;                //Number of sales transactions (confirmed by StorageContract)
    confirmedBuyTONAmount: Int as coins = 0;             //Total amount purchased (confirmed by StorageContract)

    pendingBuyCount: Int as uint64 = 0;
    pendingBuyTONAmount: Int as coins = 0;

    pendingBuyers: map<Int, PendingBuyers>;             //Buyers and their buyRequestID
}

struct ContractComissions {
    comissionAddress: Address;              //Comission address
    comissionValue: Int as uint32;          //Amount of transferred commission, milliTons
}

/*
 * DEX
*/
struct DEXSettings {
    dexKey: Int as uint16;          //1005 - Dedust
    jettonCount: Int as coins;      //how many tokens are allocated on DEX
    tonPercent: Int as uint64;      //what % of the collection will go to DEX
}

struct DAOHolderRecord {
    holder: DAOHolderDetails;
    holderIndex: Int as uint32;
    active: Bool;
    used: Int as coins = 0;
    saleIndex: Int as int64 = -1;        //Used if the entry is added for sale
}

struct DAOHolderDetails {
    assetType: Int as uint8;         //1 - assetTypeJetton, 3 - assetTypeTON
    count: Int as coins;
    owner: Address;
    onlyAfterDex: Bool;              //Liquidity can only be taken after DEX
    editLocked: Bool;                //This entry cannot be cancelled by anyone
    unlockOptions: UnlockOptions;
}

struct DAOHolderDetailsSales {
    owner: Address;
    unlockOptions: UnlockOptions;
}

/*
 * DAO Veto
*/
struct DAOVetoVoteSuccess {
    opcode: Int as uint32 = 0x559903;

    storageAddress: Address;
    totalCoins: Int as coins;

    storageState: StorageStateMessage;
    commentPrefix: Int as uint32;
    comment: Slice;
}

struct DAOVetoState {
    vetoVotedTokens: Int = 0;
    vetoVotedPercentCurrent: Int = 0;
    vetoVotedPercentTarget: Int = 70;
    vetoActiveTokens: Int = 0;
    vetoActivated: Bool = false;
    vetoActivatedTONLiquidity: Int = 0;
    vetoAvailableTokens: Int = 0;
    vetoPriceNano: Int as coins = 0;
}
struct DAOVetoClaimSuccess {
    opcode: Int as uint32 = 0x779903;
    sellTokensAmount: Int as coins;
    sendTONAmount: Int as coins;
    comment: Slice;
}