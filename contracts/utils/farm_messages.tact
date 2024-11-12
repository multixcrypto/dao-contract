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
import "./farm_structs.tact";

/*
 * Contract Initialization Message. Can be called only once.
*/
message(0x337700) InitMessage {
    jettonMasterAddress: Address;
    jettonMasterAddressHash: Slice;

    //Data for initializing tokens
    jettonWalletDataCell: Slice;

    //Dedust transfer messages
    dedustTonTransferAddress: Address;      //TON Vault address from Dedust
    dedustJettonTransferAddress: Address;   //Jetton Vault address from Dedust

    /*
     * When a contract is created for the first time, entries in DAO Holders can be added.
     * This is necessary for the platform to add an entry to receive coins for airdrop.
    */
    daoHolders: map<Int, DAOHolderDetails>;

    //Data for contract self-diagnosis during initialization
    selfTestInitA: Slice;
    selfTestInitB: Slice;
}

/*
 * Notification of receipt of contract tokens
*/
message(0x7362d09c) TransferNotification {
    queryId: Int as uint64;
    jettonAmount: Int as coins;
    fromAddress: Address;
    forwardPayload: Slice as remaining;
}

message(0xd53276db) ExcessesNotification {
    queryId: Int as uint64;
}

/*
 * Used to top up the contract balance
*/
message(0x1177) BalanceReplenishment {
    queryId: Int as uint64;
}

/*
 * Blocks the contract from changes by the creator
 * Must be called when the information is filled in and will not change again
*/
message(0x3355) LockContract {
    queryId: Int as uint64;
    lockDAOHolders: Bool;           //Blocks the ability to add or delete records in the DAO
    lockSales: Bool;                //Blocks the ability to add or cancel sales
}

/*
 * For failback situations, the owner of the contract can unlock it, but only under limited conditions
*/
message(0x3377) UnlockContract {
    queryId: Int as uint64;
    unlockDAOHolders: Bool;           //Unlock the ability to add or delete records in the DAO
    unlockSales: Bool;                //Unlock the ability to add or cancel sales
}

/*
 * Adds a record of the token sale
*/
message(0x7577) SaleStart {
    queryId: Int as uint64;
    saleOptions: SaleOptions;
    unlockOptions: UnlockOptions;
    daoHolder: DAOHolderDetailsSales;
    earlyRoundSign: Slice;
}

/*
 * Edit a record of the token sale
*/
message(0x7585) SaleEdit {
    queryId: Int as uint64;
    saleIndex: Int as uint32;
    saleOptions: SaleOptions;
    unlockOptions: UnlockOptions;
    daoHolder: DAOHolderDetailsSales;
    earlyRoundSign: Slice;
}

/*
 * Cancels a record of a token sale
*/
message(0x7588) SaleStop {
    queryId: Int as uint64;
    saleIndex: Int as uint32;
}

/*
 * Message from a token sale participant to participate in it
*/
message(0x7599) SaleParticipate {
    queryId: Int as uint64;
    saleIndex: Int as uint32;
    saleSign: Slice;
    comment: Slice as remaining;
}

/*
 * Message from a tokensale participant to collect the sale result
*/
message(0x7511) SaleClaim {
    queryId: Int as uint64;
    saleIndex: Int as uint32;
    comment: Slice as remaining;
}

/*
 * Message from the contract initiator about the completion of all trades and the listing of the project on DEX
*/
message(0x999) SalesComplete {
    queryId: Int as uint64;
}

/*
 * Allows the contract initiator to add an asset distribution record to the DAO
*/
message(0x3501) DAOHoldersAdd {
    queryId: Int as uint64;
    daoHoldersRecordsCounter: Int as uint64;
    daoHolders: map<Int, DAOHolderDetails>;
}

/*
 * Allows the contract initiator to cancel the asset distribution record in the DAO
*/
message(0x3505) DAOHoldersDelete {
    queryId: Int as uint64;
    daoHoldersIndexs: map<Int, Bool>;
}

/*
 * Allows to send the owner of the asset record its assets
*/
message(0x3507) DAOHoldersClaim {
    queryId: Int as uint64;
    daoHolderIndex: Int as uint32;
    commentPrefix: Int as uint32;
    comment: Slice as remaining;
}

/*
 * Voting within DAO Veto
*/
message(0x9901) DAOVetoVote {
    queryId: Int as uint64;
    vetoSign: Slice;
    commentPrefix: Int as uint32;
    comment: Slice as remaining;
}