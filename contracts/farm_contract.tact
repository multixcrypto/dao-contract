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

import "@stdlib/deploy";
import "@stdlib/content";
import "./imports/jetton-utils.fc";
import "./storage_contract.tact";

import "./utils/storage_structs.tact";
import "./utils/farm_messages.tact";
import "./utils/farm_structs.tact";
import "./utils/funcs.tact";

const contractVersion: Int = 5127;
const contractPlatform: String = "© Multix";
const selfTestKey: Int = 0x33333983a3419e8ffb9ac65d6fe99bec81cf4d14b17eb23e16ec184284b83887;

/*
 * [*] security-check - the most important security checks are marked with this tag
*/

contract FarmContract {
    randomKey: Int;                           //Used by our internal system
    creator: Address;                         //The creator of the contract has the right to organize token sales before listing on DEX

    contractLocks: ContractLocks;             //Implements the revocation of the rights of the contract creator
    
    comissions: ContractComissions;           //Commission for listing a project on DEX

    contractID: Int as uint64;                //ID internal from the DBMS
    
    //
    totalSupply: Int as coins;                //How many tokens are created by the contract
    isTradeActive: Bool = false;              //Are the first tokens received
    isTradeStopped: Bool = false;             //If all tokens are sold out

    //
    jettonMasterAddress: Address?;            //Address of the jetton master-contract
    jettonMasterAddressHash: Slice?;          //TON transfer to Dedust
    
    //
    jettonWalletAddress: Address?;            //Jetton wallet-contract address (will be set after initialization)
    jettonWalletDataCell: Slice?;

    //
    dexPrepareWaitUntilTime: Int = 0;
    dexClaimWaitUntilTime: Int = 0;

    //
    dedustTonTransferAddress: Address?;       //TON Vault address from Dedust
    dedustJettonTransferAddress: Address?;    //Jetton Vault address from Dedust 

    //
    airdropStarted: Bool = false;
    airdropCanBeStarted: Bool = false;

    //
    sales: map<Int, SaleDetails>;
    salesEx: map<Int, SaleDetailsEx>;
    buyers: map<Int, SaleBuyers>;
    salesCounter: Int = 0;

    //supply
    salesSupply: Int as coins = 0;
    salesClaimedTokens: Int as coins = 0;   //How many tokens from "salesSupply" were taken by buyers
    daoSupply: Int as coins = 0;            //daoSupply = totalSupply - salesSupply - dexSettings.jettonCount

    //
    daoHoldersCoins: Int as coins = 0;      //daoHoldersCoins = daoSupply - daoNotAllocated
    daoHoldersTON: Int as coins = 0;
    daoClaimedTokens: Int as coins = 0;

    //
    daoHoldersRecords: map<Int, DAOHolderRecord>;
    daoHoldersRecordsCounter: Int = 0;

    //Stores listing parameters on DEX
    dexSettings: DEXSettings;

    //Stores parameters for contract self-diagnosis during initialization
    selfTest: Int;

    //How many tokens were burned
    burnedTokens: Int = 0;
    burnedTokensSales: Int = 0;

    //How many tokens used the right of veto
    daoVetoState: DAOVetoState = DAOVetoState{};

    //Optional modules
    daoVetoEnabled: Bool;
    botProtectionEnabled: Bool;

    /* The jetton contract is integrated into this contract. The compliance of the compiled code can be verified either
     * by independently compiling the original contract, or by making sure that the tokens created by this contract have a verified code.
     *
     * https://github.com/ton-blockchain/TEPs/blob/master/text/0074-jettons-standard.md
     * https://github.com/ton-blockchain/minter-contract/blob/main/contracts/jetton-minter.fc
     * https://github.com/ton-blockchain/minter-contract/blob/main/contracts/jetton-wallet.fc
    */
    jettonMinterCode: Cell = cell("te6cckECDQEAApwAART/APSkE/S88sgLAQIBYgIKAgLMAwkC8dkGOASS+B8ADoaYGAuNhJL4HwfSB9IBj9ABi465D9ABj9ABgBaY/pn/aiaH0AfSBqahhACqk4XUcZmpqbGyiaY4L5cCSBfSB9AGoYEGhAMGuQ/QAYEogaKCF4BQpQKBnkKAJ9ASxni2ZmZPaqcEEIPe7L7yk4XXGBQEBgHANjc3AfoA+kD4KFQSBnBUIBNUFAPIUAT6AljPFgHPFszJIsjLARL0APQAywDJ+QBwdMjLAsoHy//J0FAGxwXy4EqhA0VFyFAE+gJYzxbMzMntVAH6QDAg1wsBwwCRW+MNBQA+ghDVMnbbcIAQyMsFUAPPFiL6AhLLassfyz/JgEL7AAGmghAsdrlzUnC64wI1NzcjwAOOGjNQNccF8uBJA/pAMFnIUAT6AljPFszMye1U4DUCwASOGFEkxwXy4EnUMEMAyFAE+gJYzxbMzMntVOBfBYQP8vAHAf42XwOCCJiWgBWgFbzy4EsC+kDTADCVyCHPFsmRbeKCENFzVABwgBjIywVQBc8WJPoCFMtqE8sfFMs/I/pEMHC6jjP4KEQDcFQgE1QUA8hQBPoCWM8WAc8WzMkiyMsBEvQA9ADLAMn5AHB0yMsCygfL/8nQzxaWbCJwAcsB4vQACAAKyYBA+wAAk7XwUIgG4KhAJqgoB5CgCfQEsZ4sA54tmZJFkZYCJegB6AGWAZJB8gDg6ZGWBZQPl/+ToO8AMZGWCrGeLKAJ9AQnltYlmZmS4/YBAgN6YAsMAH2tvPaiaH0AfSBqahg2GPwUALgqEAmqCgHkKAJ9ASxniwDni2ZkkWRlgIl6AHoAZYBk/IA4OmRlgWUD5f/k6EAAH68W9qJofQB9IGpqGD+qkEBOmjtA");
    jettonWalletCode: Cell = cell("te6cckECEQEAAyMAART/APSkE/S88sgLAQIBYgIQAgLMAwYCAdQEBQDDCDHAJJfBOAB0NMDAXGwlRNfA/AM4PpA+kAx+gAxcdch+gAx+gAwc6m0AALTH4IQD4p+pVIgupUxNFnwCeCCEBeNRRlSILqWMUREA/AK4DWCEFlfB7y6k1nwC+BfBIQP8vCAAET6RDBwuvLhTYAIBIAcPAgEgCAoB8VA9M/+gD6QCHwAe1E0PoA+kD6QNQwUTahUirHBfLiwSjC//LiwlQ0QnBUIBNUFAPIUAT6AljPFgHPFszJIsjLARL0APQAywDJIPkAcHTIywLKB8v/ydAE+kD0BDH6ACDXScIA8uLEd4AYyMsFUAjPFnD6AhfLaxPMgJAJ6CEBeNRRnIyx8Zyz9QB/oCIs8WUAbPFiX6AlADzxbJUAXMI5FykXHiUAioE6CCCcnDgKAUvPLixQTJgED7ABAjyFAE+gJYzxYBzxbMye1UAgEgCw4C9ztRND6APpA+kDUMAjTP/oAUVGgBfpA+kBTW8cFVHNtcFQgE1QUA8hQBPoCWM8WAc8WzMkiyMsBEvQA9ADLAMn5AHB0yMsCygfL/8nQUA3HBRyx8uLDCvoAUaihggiYloBmtgihggiYloCgGKEnlxBJEDg3XwTjDSXXCwGAMDQBwUnmgGKGCEHNi0JzIyx9SMMs/WPoCUAfPFlAHzxbJcYAQyMsFJM8WUAb6AhXLahTMyXH7ABAkECMAfMMAI8IAsI4hghDVMnbbcIAQyMsFUAjPFlAE+gIWy2oSyx8Syz/JcvsAkzVsIeIDyFAE+gJYzxYBzxbMye1UANc7UTQ+gD6QPpA1DAH0z/6APpAMFFRoVJJxwXy4sEnwv/y4sIFggkxLQCgFrzy4sOCEHvdl97Iyx8Vyz9QA/oCIs8WAc8WyXGAGMjLBSTPFnD6AstqzMmAQPsAQBPIUAT6AljPFgHPFszJ7VSAAg9QBBrkPaiaH0AfSB9IGoYAmmPwQgLxqKMqRBdQQg97svvCd0JWPlxYumfmP0AGAnQKBHkKAJ9ASxniwDni2Zk9qpAAboPYF2omh9AH0gfSBqGG7XEd1");

    init(
        randomKey: Int,
        contractID: Int,
        totalSupply: Int,

        comissionAddress: Address,
        comissionValue: Int,

        dexSettings: DEXSettings,

        daoVetoEnabled: Bool,
        botProtectionEnabled: Bool,

        selfTest: Int
    ) {
        require(contractID > 0, "contractID need > 0");

        require(comissionValue > 0, "comissionValue > 0");
        require((dexSettings.dexKey == kDEXDedust), "wrong dexKey");
        require(dexSettings.jettonCount > 0, "dexSettings.jettonCount > 0");
        require(dexSettings.tonPercent > 0, "dexSettings.tonPercent > 0");
        require(selfTest != 0, "wrong selfTest");

        self.randomKey = randomKey;
        self.creator = sender();                                                    //[*] security-check
        self.totalSupply = totalSupply;
        self.sales = emptyMap();
        self.salesEx = emptyMap();
        self.buyers = emptyMap();
        self.daoHoldersRecords = emptyMap();

        self.selfTest = selfTest;

        self.comissions = ContractComissions{
            comissionAddress: comissionAddress,
            comissionValue: comissionValue
        };

        self.contractLocks = ContractLocks{};

        self.contractID = contractID;

        self.dexSettings = dexSettings;
        self.daoSupply = totalSupply - dexSettings.jettonCount;

        self.daoVetoEnabled = daoVetoEnabled;
        self.botProtectionEnabled = botProtectionEnabled;

        //post checks
        require(self.daoSupply > 0, "daoSupply > 0");
    }

    get fun state(): StateMessage {
        let ready: Bool = (self.jettonWalletAddress != null);

        let salesFreeTokens: Int = self.salesSupply - self.salesClaimedTokens;

        let salesStat: SalesStat = self.getSalesStat();

        return StateMessage{
            contractVersion: contractVersion,
            contractReady: ready,
            
            contractID: self.contractID,
            creator: self.creator,
            jettonWalletAddress: self.jettonWalletAddress,

            totalSupply: self.totalSupply,

            isTradeActive: self.isTradeActive,
            isTradeStopped: self.isTradeStopped,

            comissionAddress: self.comissions.comissionAddress,
            comissionValue: self.comissions.comissionValue,

            airdropStarted: self.airdropStarted,

            dexKey: self.dexSettings.dexKey,

            dexPrepareWaitUntilTime: self.dexPrepareWaitUntilTime,
            dexClaimWaitUntilTime: self.dexClaimWaitUntilTime,

            sales: self.sales,
            salesCounter: self.salesCounter,

            salesSupply: self.salesSupply,
            salesClaimedTokens: self.salesClaimedTokens,
            salesFreeTokens: salesFreeTokens,

            daoSupply: self.daoSupply,
            
            daoHoldersCoins: self.daoHoldersCoins,
            daoHoldersTON: self.daoHoldersTON,

            buyers: self.buyers,

            dexSettings: self.dexSettings,
            salesEx: self.salesEx,
            daoHoldersRecords: self.daoHoldersRecords,

            contractLocks: self.contractLocks,

            salesStat: salesStat,

            isAutoListingAvailable: self.isAutoListingAvailable(salesStat),
            burnedTokens: self.burnedTokens,

            daoVetoState: self.daoVetoState,

            daoVetoEnabled: self.daoVetoEnabled,
            botProtectionEnabled: self.botProtectionEnabled
        };
    }

    get fun getClientStorageAddress(clientAddress: Address, saleIndex: Int): Address {
        let init: StateInit = initOf StorageContract(myAddress(), clientAddress, saleIndex);
        return contractAddress(init);
    }

    fun notifyGreedy(body: Cell) {
        let toSend: Int = context().value - context().readForwardFee() * 2 - ton("0.05");
        if (toSend <= 0) {
            return;                                                                     //[*] security-check
        }

        send(SendParameters{
            to: sender(),
            value: toSend,
            mode: 0,
            body: body
        });
    }

    fun notifyZero(body: Cell) {
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: body
        });
    }

    receive(msg: InitMessage) {
        require(self.jettonWalletAddress == null, "already init");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                           //[*] security-check

        //At least 51% must go to DEX listing
        if (self.dexSettings.tonPercent < 51 * milliTons) {
            self.notifyGreedy("At least 51% must go to DEX listing".asComment());
            return;
        }

        //
        self.jettonMasterAddress = msg.jettonMasterAddress;
        self.jettonMasterAddressHash = msg.jettonMasterAddressHash;                   //address.hash
        self.jettonWalletDataCell = msg.jettonWalletDataCell;

        self.dedustTonTransferAddress = msg.dedustTonTransferAddress;
        self.dedustJettonTransferAddress = msg.dedustJettonTransferAddress;

        //Init  address
        let jettonMasterAddress: Address = contractAddressExt(0, self.jettonMinterCode, (self.jettonWalletDataCell!!).asCell());
        self.jettonWalletAddress = calculate_user_jetton_wallet_address(myAddress().asSlice(), jettonMasterAddress.asSlice(), self.jettonWalletCode).loadAddress();

        //Self-testing
        let selfTestStr: StringBuilder = beginString();
        selfTestStr.append("Self-testing: ");
        selfTestStr.append(self.randomKey.toString());
        selfTestStr.append(self.comissions.comissionAddress.toString());
        selfTestStr.append(self.comissions.comissionValue.toString());
        selfTestStr.append(self.contractID.toString());
        selfTestStr.append(self.totalSupply.toString());

        /*
         * Add DAO holders
         * Used to add entry to farm coins
        */
        let daoHolders: map<Int, DAOHolderDetails> = msg.daoHolders;

        //
        let addCoins: Int = 0;

        //Calc added coins
        foreach (key, daoHolder in daoHolders) {
            require(daoHolder.count > 0, "wrong count");
            require((daoHolder.assetType == kAssetTypeJetton), "wrong type");
            require(daoHolder.onlyAfterDex, "wrong onlyAfterDex");
            require(daoHolder.editLocked, "wrong editLocked");

            let checkUnlockOptionsResultA = checkUnlockOptions(daoHolder.unlockOptions);
            if (checkUnlockOptionsResultA != 1) {
                let strError: StringBuilder = beginComment();
                strError.append("wrong daoHolder.unlockOptions, error: ");
                strError.append(checkUnlockOptionsResultA.toString());
                self.notifyGreedy(strError.toCell());
                return;
            }

            if (daoHolder.assetType == kAssetTypeJetton) {
                addCoins = addCoins + daoHolder.count;
            }
        }

        //
        require(addCoins > 0, "DAO holder entry is required");

        //Checks
        let daoHoldersCoinsWillBe: Int = self.daoHoldersCoins + addCoins;
        if (daoHoldersCoinsWillBe > self.daoSupply) {
            self.notifyGreedy("Not enough coins in DAO to distribute".asComment());
            return;
        }

        //
        let str: StringBuilder = beginComment();
        str.append("DAO holders added: ");

        //Save changes
        let idx: Int = 0;
        foreach (key, daoHolder in daoHolders) {
            let daoHolderIndex: Int = self.daoHoldersRecordsCounter;
            
            if (daoHolderIndex > 10) {
                self.notifyGreedy("Too many holders".asComment());
                return;
            }

            self.daoHoldersRecords.set(daoHolderIndex, DAOHolderRecord{
                active: true,
                holderIndex: daoHolderIndex,
                holder: daoHolder
            });

            self.daoHoldersRecordsCounter = self.daoHoldersRecordsCounter + 1;

            if (daoHolder.assetType == kAssetTypeJetton) {
                self.daoHoldersCoins = self.daoHoldersCoins + daoHolder.count;
            } else {
                self.daoHoldersTON = self.daoHoldersTON + daoHolder.count;
            }

            if (idx > 0) {
                str.append(", ");
            }

            str.append((daoHolderIndex).toString());
            str.append(". ");
            str.append(daoHolder.count.toCoinsString());

            selfTestStr.append((daoHolderIndex).toString());
            selfTestStr.append(" -> ");
            selfTestStr.append(daoHolder.count.toCoinsString());

            if (daoHolder.assetType == kAssetTypeJetton) {
                selfTestStr.append(" tokens");
            } else {
                selfTestStr.append(" TON");
            }

            selfTestStr.append("; ");

            idx = idx + 1;
        }

        if (idx == 0) {
            str.append("no holders");
        }

        /*
         * This is necessary to facilitate the verification of contract codes in the network
         * When initializing a contract, it is checked that the contract parameters and initialization data match each other
        */
        let addressSign: Int = sha256(myAddress().toString());
        require(sha256(selfTestStr.toString()) == self.selfTest, "wrong selfTest");
        require(checkSignature(self.selfTest, msg.selfTestInitA, selfTestKey), "wrong selfTest");
        require(checkSignature(addressSign, msg.selfTestInitB, selfTestKey), "wrong selfTest");

        //
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });        
        
        /*
         * Create jetton
        */
        send(SendParameters{
            to: jettonMasterAddress,
            value: ton("0.01"),
            bounce: false,
            mode: SendPayGasSeparately,
            code: self.jettonMinterCode,
            data: self.jettonWalletDataCell!!.asCell()
        });
        send(SendParameters{
            to: jettonMasterAddress,
            value: ton("0.04"),
            mode: 0,
            body: getJettonMintBody(myAddress(), ton("0.03"), self.totalSupply, myAddress(), ton("0.025"))
        });
        send(SendParameters{
            to: jettonMasterAddress,
            value: ton("0.01"),
            mode: 0,
            body: getJettonRevokeAccessBody()
        });
    }

    /*
    * Used to top up the contract balance
    */
    receive(msg: BalanceReplenishment) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                                  //[*] security-check

        //
        if (context().value > ton("100")) {
            self.notifyGreedy("The top-up amount is too large".asComment());
            return;
        }

        //
        let str: StringBuilder = beginComment();
        str.append("Balance replenished: ");
        str.append(context().value.toCoinsString());
        str.append(" TON");

        //
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });
    }

    /*
    * Blocks the contract from changes by the creator
    * Must be called when the information is filled in and will not change again
    */
    receive(msg: LockContract) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                                  //[*] security-check

        if (self.isTradeStopped) {
            self.notifyGreedy("Sales completed".asComment());
            return;
        }
        
        //It is allowed to block sales only if there are no active sales without a date
        if (msg.lockSales) {
            let haveSalesWithoutDate: Bool = self.isHaveActiveSalesWithoutDate();
            if (haveSalesWithoutDate) {
                self.notifyGreedy("There are active sales without a date".asComment());
                return;
            }
        }

        let contractLocks: ContractLocks = self.contractLocks;

        let str: StringBuilder = beginComment();
        str.append("Lock contract: ");

        //Requesting a record lock in DAO
        if (msg.lockDAOHolders) {
            str.append("DAO entries locked");

            contractLocks.daoHoldersLocked = true;                                          //[*] security-check         
        }

        //Request to block sales list
        if (msg.lockSales) {
            if (msg.lockDAOHolders) {
                str.append(", ");
            }

            str.append("sales locked");

            contractLocks.salesLocked = true;                                               //[*] security-check         
        }

        //save changes
        self.contractLocks = contractLocks;

        //
        self.notifyGreedy(str.toCell());
        return;
    }

    /*
    * For failback situations, the owner of the contract can unlock it, but only under limited conditions
    * Unblocking is only possible if there is NO active sale and NO successful sale
    */
    receive(msg: UnlockContract) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                                         //[*] security-check

        //
        let salesStat: SalesStat = self.getSalesStat();
        if (salesStat.currentlyActiveCount > 0) {                                                   //[*] security-check
            self.notifyGreedy("Unable to unlock because there are active sales now".asComment());
            return;
        }
        if (salesStat.unfinishedSalesCount > 0) {                                                   //[*] security-check
            self.notifyGreedy("Unable to unlock because there are pending token sales".asComment());
            return;
        }
        if (salesStat.confirmedBuyTONAmountWithoutEarly > 0) {                                      //[*] security-check
            self.notifyGreedy("Unable to unlock because there are successful collections".asComment());
            return;
        }

        if (self.isTradeStopped) {
            self.notifyGreedy("Sales completed".asComment());
            return;
        }

        let contractLocks: ContractLocks = self.contractLocks;

        let str: StringBuilder = beginComment();
        str.append("Unlock contract: ");

        //Requesting a record unlock in DAO
        if (msg.unlockDAOHolders) {
            str.append("DAO entries unlocked");

            contractLocks.daoHoldersLocked = false;
        }

        //Request to unlock sales list
        if (msg.unlockSales) {
            if (msg.unlockDAOHolders) {
                str.append(", ");
            }

            str.append("sales unlocked");

            contractLocks.salesLocked = false;
        }

        //save changes
        self.contractLocks = contractLocks;

        //
        self.notifyGreedy(str.toCell());
        return;
    }

    /*
    * Launches a token sale
    */
    receive(msg: SaleStart) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                           //[*] security-check

        //
        if (self.isTradeStopped) {
            self.notifyGreedy("Sales completed".asComment());
            return;
        }

        if (self.contractLocks.salesLocked) {                                         //[*] security-check
            self.notifyGreedy("Sales locked".asComment());
            return;
        }
        if (!self.contractLocks.daoHoldersLocked) {                                   //[*] security-check
            self.notifyGreedy("DAO entries need to be locked".asComment());
            return;
        }

        //
        require(self.airdropCanBeStarted == false, "airdropCanBeStarted == false");
        require(self.airdropStarted == false, "airdropStarted == false");
       
        //
        if (msg.saleOptions.saleIndex != self.salesCounter) {
            self.notifyGreedy("wrong saleIndex".asComment());
            return;
        }

        //
        if (!self.checkSaleOptions(msg.saleOptions, msg.unlockOptions, msg.daoHolder, msg.earlyRoundSign)) {
            return;
        }

        //Before using "daoSupply" complete sales that can be completed
        self.completeSales();
        
        //
        let saleOptions: SaleOptions = msg.saleOptions;
        let daoSupplyWillBe: Int = self.daoSupply - saleOptions.jettonsReserved;
        if (daoSupplyWillBe < self.daoHoldersCoins) {
            self.notifyGreedy("no tokens left for DAO".asComment());
            return;
        }

        //
        let salesStat: SalesStat = self.getSalesStat();

        /*
         * Early round can only be held if there are no other sales
        */
        if ((msg.saleOptions.saleType == kSaleTypeEarlyRound) && (salesStat.activeAll > 0)) {
            self.notifyGreedy("Early round can only be held at the beginning".asComment());
            return;
        }

        /*
         * After the fairlunch, no presale or early round can be held
        */
        if ((msg.saleOptions.saleType != kSaleTypeFairlunch) && (salesStat.activeFairlunches > 0)) {
            self.notifyGreedy("After the fairlunch no presale or early round can be held".asComment());
            return;
        }

        /*
         * Additional funds on the contract balance are required to activate DEX
        */
        if ((self.dexPrepareWaitUntilTime == 0) && (myBalance() < ton("0.5"))) {
            self.notifyGreedy("Contract balance is less than 0.5 TON".asComment());
            return;
        }

        /*
         * The parameter says that liquidity can be taken only after listing on DEX.
         * But an exception is made for early round - the project can take liquidity before listing on DEX.
        */
        let onlyAfterDex: Bool = true;
        if (msg.saleOptions.saleType == kSaleTypeEarlyRound) {
            onlyAfterDex = false;
        }

        //
        let saleIndex: Int = self.salesCounter;
        self.sales.set(self.salesCounter, SaleDetails{
            saleOptions: saleOptions,
            saleIndex: saleIndex,
            active: true,
            addTime: now(),
            capMaxChecked: saleOptions.capMax - kCapMaxInaccuracy
        });
        let daoHolderRecord: DAOHolderDetails = DAOHolderDetails{
            assetType: kAssetTypeTON,
            count: 0,
            owner: msg.daoHolder.owner,
            onlyAfterDex: onlyAfterDex,
            editLocked: false,
            unlockOptions: msg.daoHolder.unlockOptions
        };
        self.salesEx.set(self.salesCounter, SaleDetailsEx{
            unlockOptions: msg.unlockOptions,
            daoHolder: daoHolderRecord
        });
        self.buyers.set(self.salesCounter, SaleBuyers{
            pendingBuyers: emptyMap()
        });


        //
        self.salesCounter = self.salesCounter + 1;
        self.salesSupply += saleOptions.jettonsReserved;
        self.daoSupply -= saleOptions.jettonsReserved;

        //As soon as there are funds on the balance, activate DEX
        if (self.dexPrepareWaitUntilTime == 0) {
            self.activateDEX();
        }

        //
        let str: StringBuilder = beginComment();
        str.append("Sales launched: ");
        str.append(getSaleTypeName(saleOptions.saleType)!!);
        str.append(", index: ");
        str.append((self.salesCounter - 1).toString());

        //
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });
    }

    /*
     * Checks fields when adding and editing a sale
    */
    fun checkSaleOptions(
        saleOptions: SaleOptions,
        unlockOptions: UnlockOptions,
        daoHolder: DAOHolderDetailsSales,
        earlyRoundSign: Slice
    ): Bool {
        require(saleOptions.saleType == kSaleTypePresale || saleOptions.saleType == kSaleTypeFairlunch || saleOptions.saleType == kSaleTypeEarlyRound, "wrong saleType");

        //
        let msgSign: StringBuilder = beginString();
        msgSign.append(saleOptions.saleIndex.toString());
        msgSign.append(getSaleTypeName(saleOptions.saleType)!!);
        msgSign.append(myAddress().toString());
        
        if (!checkSignature(sha256(msgSign.toString()), earlyRoundSign, selfTestKey)) {
            self.notifyGreedy("wrong sign".asComment());
            return false;
        }

        //
        if (saleOptions.isDateSet) {
            if (saleOptions.timeStart < (now() - 86400) || saleOptions.timeStart > saleOptions.timeEnd) {
                self.notifyGreedy("wrong timeStart".asComment());
                return false;
            }
            if (saleOptions.timeEnd < (now() + 60)) {
                self.notifyGreedy("wrong timeEnd".asComment());
                return false;
            }
        } else {
            if (saleOptions.timeStart != 0 || saleOptions.timeEnd != 0) {
                self.notifyGreedy("wrong timeStart and timeEnd, need 0".asComment());
                return false;
            }
        }        

        //
        if (saleOptions.jettonsReserved <= 0) {
            self.notifyGreedy("wrong jettonsReserved <= 0".asComment());
            return false;
        }

        if (saleOptions.saleType == kSaleTypeFairlunch) {
            if (saleOptions.buyPrice != 0) {
                self.notifyGreedy("wrong buyPrice != 0".asComment());
                return false;
            }
        } else {
            if (saleOptions.buyPrice <= 0) {
                self.notifyGreedy("wrong buyPrice <= 0".asComment());
                return false;
            }
            
            /*
             * The number of reserved tokens is calculated relative to the maximum capitalization and the price per token
            */
            let jettonsReservedNanoMustBe = mathDivisionCeil(saleOptions.capMax, saleOptions.buyPrice) * nanoTons;
            if (jettonsReservedNanoMustBe != saleOptions.jettonsReserved) {
                let str: StringBuilder = beginComment();
                str.append("wrong saleOptions.jettonsReserved, ");
                str.append(saleOptions.jettonsReserved.toCoinsString());
                str.append(" != ");
                str.append((jettonsReservedNanoMustBe).toCoinsString());
                self.notifyGreedy(str.toCell());
                return false;
            }
        }

        //Check soft cap and hard cap
        if (saleOptions.capMax <= kCapMaxInaccuracy) {
            let str: StringBuilder = beginComment();
            str.append("wrong saleOptions.capMax, need > ");
            str.append(kCapMaxInaccuracy.toString());
            self.notifyGreedy(str.toCell());
            return false;
        }
        if ((saleOptions.capMin <= 0) || (saleOptions.capMax <= 0) || (saleOptions.capMax <= saleOptions.capMin)) {
            self.notifyGreedy("wrong capMin, capMax".asComment());
            return false;
        }

        //
        let needMinBuyTONAmount = ton("0.2");
        if (saleOptions.minBuyTONAmount < needMinBuyTONAmount) {
            let str: StringBuilder = beginComment();
            str.append("wrong saleOptions.minBuyTONAmount, need > ");
            str.append(needMinBuyTONAmount.toString());
            self.notifyGreedy(str.toCell());
            return false;
        }

        //check msg.unlockOptions
        let checkUnlockOptionsResultA = checkUnlockOptions(unlockOptions);
        if (checkUnlockOptionsResultA != 1) {
            let str: StringBuilder = beginComment();
            str.append("wrong msg.unlockOptions, error: ");
            str.append(checkUnlockOptionsResultA.toString());
            self.notifyGreedy(str.toCell());
            return false;
        }

        //check msg.daoHolder.unlockOptions
        let checkUnlockOptionsResultB = checkUnlockOptions(daoHolder.unlockOptions);
        if (checkUnlockOptionsResultB != 1) {
            let str: StringBuilder = beginComment();
            str.append("wrong msg.daoHolder.unlockOptions, error: ");
            str.append(checkUnlockOptionsResultB.toString());
            self.notifyGreedy(str.toCell());
            return false;
        }

        return true;
    }

    /*
    * Edits a token sale entry
    */
    receive(msg: SaleEdit) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                           //[*] security-check

        //
        if (self.isTradeStopped) {
            self.notifyGreedy("Sales completed".asComment());
            return;
        }

        if (self.contractLocks.salesLocked) {                                         //[*] security-check
            self.notifyGreedy("Sales locked".asComment());
            return;
        }
        if (!self.contractLocks.daoHoldersLocked) {                                   //[*] security-check
            self.notifyGreedy("DAO entries need to be locked".asComment());
            return;
        }

        //
        require(self.airdropCanBeStarted == false, "airdropCanBeStarted == false");
        require(self.airdropStarted == false, "airdropStarted == false");
        require(msg.saleOptions.saleType == kSaleTypePresale || msg.saleOptions.saleType == kSaleTypeFairlunch || msg.saleOptions.saleType == kSaleTypeEarlyRound, "wrong saleType");

        //Check sale options
        if (!self.checkSaleOptions(msg.saleOptions, msg.unlockOptions, msg.daoHolder, msg.earlyRoundSign)) {
            return;
        }

        if (msg.saleIndex < 0 || msg.saleIndex >= self.salesCounter) {
            self.notifyGreedy("wrong saleIndex".asComment());
            return;
        }

        let sale: SaleDetails = self.sales.get(msg.saleIndex)!!;
        let saleEx: SaleDetailsEx = self.salesEx.get(msg.saleIndex)!!;
        let saleBuyers: SaleBuyers = self.buyers.get(msg.saleIndex)!!;

        require(msg.saleIndex == sale.saleIndex, "wrong saleIndex");
        require(msg.saleOptions.saleIndex == sale.saleIndex, "wrong saleIndex");

        let saleOptionsPrev: SaleOptions = sale.saleOptions;

        if (!sale.active) {
            self.notifyGreedy("already cancelled".asComment());
            return;
        }

        if (sale.completed) {
            self.notifyGreedy("already completed by state".asComment());
            return;
        }

        if ((saleOptionsPrev.timeStart <= now()) && saleOptionsPrev.isDateSet) {
            self.notifyGreedy("already started".asComment());
            return;
        }

        //
        let saleOptionsNew: SaleOptions = msg.saleOptions;
        let daoSupplyWillBe: Int = self.daoSupply + saleOptionsPrev.jettonsReserved - saleOptionsNew.jettonsReserved;
        if (daoSupplyWillBe < self.daoHoldersCoins) {
            self.notifyGreedy("no tokens left for DAO".asComment());
            return;
        }

        //
        if (saleOptionsNew.saleIndex != sale.saleIndex) {
            self.notifyGreedy("wrong saleOptionsNew.saleIndex".asComment());
            return;
        }

        //
        if (saleOptionsNew.saleType != saleOptionsPrev.saleType) {
            self.notifyGreedy("Unable to change sale type".asComment());
            return;
        }

        //
        let onlyAfterDex: Bool = true;
        if (saleOptionsNew.saleType == kSaleTypeEarlyRound) {
            onlyAfterDex = false;
        }
        
        //
        let saleIndex: Int = msg.saleIndex;
        self.sales.set(saleIndex, SaleDetails{
            saleOptions: saleOptionsNew,
            saleIndex: saleIndex,
            active: true,
            addTime: sale.addTime,
            capMaxChecked: saleOptionsNew.capMax - kCapMaxInaccuracy
        });
        let daoHolderRecord: DAOHolderDetails = DAOHolderDetails{
            assetType: kAssetTypeTON,
            count: 0,
            owner: msg.daoHolder.owner,
            onlyAfterDex: onlyAfterDex,
            editLocked: false,
            unlockOptions: msg.daoHolder.unlockOptions
        };
        self.salesEx.set(saleIndex, SaleDetailsEx{
            unlockOptions: msg.unlockOptions,
            daoHolder: daoHolderRecord
        });

        //
        self.salesSupply -= saleOptionsPrev.jettonsReserved;
        self.daoSupply += saleOptionsPrev.jettonsReserved;

        //
        self.salesSupply += saleOptionsNew.jettonsReserved;
        self.daoSupply -= saleOptionsNew.jettonsReserved;

        //As soon as there are funds on the balance, activate DEX
        if (self.dexPrepareWaitUntilTime == 0) {
            self.activateDEX();
        }

        //
        let str: StringBuilder = beginComment();
        str.append("Sales edited: ");
        str.append(getSaleTypeName(saleOptionsNew.saleType)!!);
        str.append(", index: ");
        str.append(saleIndex.toString());

        //
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });
    }

    /*
    * Stopping token sales
    */
    receive(msg: SaleStop) {
        require(self.jettonWalletAddress != null, "contract not inited");

        //
        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                           //[*] security-check

        if (self.isTradeStopped) {
            self.notifyGreedy("Sales completed".asComment());
            return;
        }
        
        /*
         * Stopping sales is allowed even if the sales listing is blocked
         * This is necessary for the exclusive return of funds from the sale
         * if (self.contractLocks.salesLocked) { ... }
        */
        
        //
        if (msg.saleIndex < 0 || msg.saleIndex >= self.salesCounter) {
            self.notifyGreedy("wrong saleIndex".asComment());
            return;
        }

        let sale: SaleDetails = self.sales.get(msg.saleIndex)!!;
        let saleBuyers: SaleBuyers = self.buyers.get(msg.saleIndex)!!;

        require(msg.saleIndex == sale.saleIndex, "wrong saleIndex");

        let saleOptions: SaleOptions = sale.saleOptions;

        if (!sale.active) {
            self.notifyGreedy("already cancelled".asComment());
            return;
        }

        /*
         * Early round sales cannot be cancelled once they have been successfully completed
         * Remaining sales may be canceled at any time prior to listing on the DEX
        */
        if (saleOptions.saleType == kSaleTypeEarlyRound) {
            if (sale.completed) {
                self.notifyGreedy("already completed by state".asComment());
                return;
            }

            if ((saleOptions.timeEnd <= now()) && saleOptions.isDateSet) {
                self.notifyGreedy("already completed by time".asComment());
                return;
            }

            let isFinishedByCap: Bool = (saleBuyers.confirmedBuyTONAmount >= sale.capMaxChecked);
            if (isFinishedByCap) {
                self.notifyGreedy("already completed by cap".asComment());
                return;
            }
        }

        //
        sale.active = false;

        //Сompleting the sale starts all over again
        if (sale.completed && sale.completedSuccess) {
            sale.completed = false;
        }

        //
        self.sales.set(sale.saleIndex, sale);

        //
        self.completeSales();

        //
        let str: StringBuilder = beginComment();
        str.append("Sales stopped: ");
        str.append(getSaleTypeName(saleOptions.saleType)!!);
        str.append(", index: ");
        str.append(sale.saleIndex.toString());

        //
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });
    }

    fun activateDEX() {
        if (self.airdropCanBeStarted) {
            self.notifyGreedy("Already started".asComment());
            return;
        }

        if (self.dexSettings.dexKey == kDEXDedust) {
            if ((self.dedustTonTransferAddress == null) || (self.dedustJettonTransferAddress == null)) {
                self.notifyGreedy("Wrong DEX Address".asComment());
                return;
            }

            //
            let asset0Cell: Cell = beginCell()
                .storeUint(0, 4)                                     //(AssetType_1.AssetType.NATIVE, 4);
                .endCell();

            let asset1Cell: Cell = beginCell()
                .storeUint(1, 4)                                     //(AssetType_1.AssetType.JETTON, 4);
                .storeInt(0, 8)                                      //storeInt(this.address.workChain, 8)
                .storeSlice(self.jettonMasterAddressHash!!)          //storeBuffer(this.address.hash)
                .endCell();

            //
            let factoryAddress: Address = newAddress(0, 0x5f0564fb5f604783db57031ce1cf668a88d4d4d6da6de4db222b4b920d6fd800);

            //factory.sendCreateVault
            send(SendParameters{
                to: factoryAddress,
                value: ton("0.1"),
                mode: SendPayGasSeparately,
                body: beginCell()
                    .storeUint(0x21cfe02b, 32)                        //storeUint(Factory.CREATE_VAULT, 32)
                    .storeUint(0, 64)                                 //storeUint(queryId ?? 0, 64)
                    .storeSlice(asset1Cell.asSlice())                 //storeSlice(asset.toSlice())
                    .endCell()
            });

            //factory.sendCreateVolatilePool
            send(SendParameters{
                to: factoryAddress,
                value: ton("0.25"),
                mode: SendPayGasSeparately,
                body: beginCell()
                    .storeUint(0x97d51f2f, 32)                        //storeUint(Factory.CREATE_VOLATILE_POOL, 32)
                    .storeUint(0, 64)                                 //storeUint(queryId ?? 0, 64)
                    .storeSlice(asset0Cell.asSlice())                 //storeSlice(assets[0].toSlice())
                    .storeSlice(asset1Cell.asSlice())                 //storeSlice(assets[1].toSlice())
                    .endCell()
            });

            //
            self.dexPrepareWaitUntilTime = now() + 60 * 2;
        }
    }

    /*
     * Checks if there are any active sales that have not yet been scheduled
    */
    fun isHaveActiveSalesWithoutDate(): Bool {
        let i: Int = 0;
        let haveSalesWithoutDate: Bool = false;
        while(i < self.salesCounter) {
            let sale: SaleDetails = self.sales.get(i)!!;
            if (sale.active && !sale.saleOptions.isDateSet) {
                haveSalesWithoutDate = true;
            }

            i += 1;
        }

        return haveSalesWithoutDate;
    }

    /*
     * Returns statistics of sales records
     * Necessary to understand how much has already been collected, as well as whether there are active sales at the moment, etc
    */
    fun getSalesStat(): SalesStat {
        let confirmedBuyTONAmountWithoutEarly: Int = 0;
        let unfinishedSalesCount: Int = 0;
        let currentlyActiveCount: Int = 0;

        let firstFinishedSuccessTimeEnd: Int = 0;

        let activeAll: Int = 0;
        let activeFairlunches: Int = 0;

        let finishedUncompletedCount: Int = 0;
        foreach (saleIndex, sale in self.sales) {
            let saleBuyers: SaleBuyers = self.buyers.get(saleIndex)!!;

            if (sale.active) {
                let saleOptions: SaleOptions = sale.saleOptions;
                let isFinishedByTime: Bool = (saleOptions.timeEnd <= now()) && saleOptions.isDateSet;
                let isFinishedByState: Bool = !sale.active;
                let isFinishedByCap: Bool = (saleBuyers.confirmedBuyTONAmount >= sale.capMaxChecked);

                //The start date has arrived, but the end date has not yet been reached
                let isStarted: Bool = (saleOptions.timeStart <= now()) && !isFinishedByTime && saleOptions.isDateSet;

                //
                let isFinished: Bool = (isFinishedByTime || isFinishedByState || isFinishedByCap) && saleOptions.isDateSet;
                if (!isFinished || !sale.completed) {
                    unfinishedSalesCount += 1;
                }

                if (isStarted) {
                    currentlyActiveCount += 1;
                }

                //
                let isTargetCapReached: Bool = (saleBuyers.confirmedBuyTONAmount >= saleOptions.capMin);
                let isFinishedSuccess: Bool = isFinished && sale.active && isTargetCapReached;

                //Count incomplete or successfully completed all sales
                if (!isFinished || isFinishedSuccess) {
                    activeAll += 1;
                }

                //Count incomplete and successfully completed fairlunches
                if ((saleOptions.saleType == kSaleTypeFairlunch) && (!isFinished || isFinishedSuccess)) {
                    activeFairlunches += 1;
                }

                
                //How many sales were finished but not processed
                if (isFinished && !sale.completed && (saleBuyers.pendingBuyTONAmount <= 0)) {
                    finishedUncompletedCount += 1;
                }            

                //
                if (isFinishedSuccess) {
                    let saleBuyerItem: SaleBuyers = self.buyers.get(saleIndex)!!;

                    //Completed sales excluding early round
                    if (sale.completed && (saleOptions.saleType != kSaleTypeEarlyRound)) {
                        confirmedBuyTONAmountWithoutEarly += saleBuyerItem.confirmedBuyTONAmount;
                    }                    

                    //Date of the first successful token sale
                    if ((firstFinishedSuccessTimeEnd > saleOptions.timeEnd) || (firstFinishedSuccessTimeEnd == 0)) {
                        firstFinishedSuccessTimeEnd = saleOptions.timeEnd;
                    }
                }
            }
        }

        return SalesStat{
            confirmedBuyTONAmountWithoutEarly: confirmedBuyTONAmountWithoutEarly,
            unfinishedSalesCount: unfinishedSalesCount,

            currentlyActiveCount: currentlyActiveCount,

            firstFinishedSuccessTimeEnd: firstFinishedSuccessTimeEnd,

            activeAll: activeAll,
            activeFairlunches: activeFairlunches,

            finishedUncompletedCount: finishedUncompletedCount
        };
    }

    /*
    * Stops trading and starts the process of transferring liquidity to DEX
    * A portion of the funds in the amount of "projectComission" goes as a commission for listing
    * Everything that remains on the contract goes to the DAO management
    */
    receive(msg: SalesComplete) {
        require(self.jettonWalletAddress != null, "contract not inited");

        /*
        * A year after the first successful token sale, any user may cancel the sale if tokens have not been sent to the DEX
        * This is necessary so that the owner of the contract cannot block funds for a long time
        */
        let salesStat: SalesStat = self.getSalesStat();
        let firstFinishedSuccessTimeEnd: Int = salesStat.firstFinishedSuccessTimeEnd;
        let timeFromSuccessFinish: Int = now() - firstFinishedSuccessTimeEnd;
        let daysFromSuccessFinish: Int = timeFromSuccessFinish / 86400;
        if (firstFinishedSuccessTimeEnd <= 0) {
            daysFromSuccessFinish = 0;
        }
        let isManuallyCancelAllSales: Bool = (firstFinishedSuccessTimeEnd > 0) && (daysFromSuccessFinish >= kUnlockDays);    //[*] security-check

        //
        if ((self.creator != sender()) && !isManuallyCancelAllSales) {
            let dayToManuallyCancel = kUnlockDays - daysFromSuccessFinish;

            let str: StringBuilder = beginComment();
            str.append("Access denied, wait ");
            str.append(dayToManuallyCancel.toString());
            str.append(" days");
            self.notifyGreedy(str.toCell());
            return;
        }

        /*
         * Allow all sales that were not successful to be completed
         * Checks a field that is set to true if the DEX listing was successful
        */
        if (isManuallyCancelAllSales) {
            //If the listing on DEX was successful with confirmation, then it cannot be executed
            if (self.airdropStarted) {
                self.notifyGreedy("Already completed".asComment());
                return;
            }

            //
            let i: Int = 0;
            let firstInit: Bool = true;

            let str: StringBuilder = beginComment();
            str.append("Manual sales completion: ");

            while(i < self.salesCounter) {
                let sale: SaleDetails = self.sales.get(i)!!;

                if (sale.active) {
                    let saleBuyers: SaleBuyers = self.buyers.get(i)!!;
                    let saleOptions: SaleOptions = sale.saleOptions;
                    
                    //
                    sale.active = false;

                    //
                    if (firstInit) {
                        firstInit = false;
                    } else {
                        str.append(", ");
                    }
                    str.append(i.toString());

                    //save
                    self.sales.set(i, sale);
                }

                i += 1;
            }

            if (firstInit) {
                str.append("no sales to complete");
            }

            self.notifyGreedy(str.toCell());
            return;
        }

        //
        require(self.creator == sender(), "access denied");                                     //[*] security-check

        //
        self.dexListing(salesStat);
    }

    fun fillUnlockOptionsDates() {
        let currentTime: Int = now();

        //sales
        foreach (saleIndex, sale in self.sales) {
            if (sale.active) {
                let saleEx: SaleDetailsEx = self.salesEx.get(saleIndex)!!;

                saleEx.unlockOptions.unlockStartTime = currentTime;
                saleEx.daoHolder.unlockOptions.unlockStartTime = currentTime;

                self.salesEx.set(saleIndex, saleEx);
            }
        }

        //dao holders
        foreach (key, daoHolderRecord in self.daoHoldersRecords) {
            daoHolderRecord.holder.unlockOptions.unlockStartTime = currentTime;

            self.daoHoldersRecords.set(key, daoHolderRecord);
        }
    }

    fun dexListing(salesStat: SalesStat) {
        if (self.isTradeStopped) {
            self.notifyZero("Already completed".asComment());
            return;
        }

        //
        if (salesStat.unfinishedSalesCount > 0) {
            self.notifyZero("There are unfinished sales".asComment());
            return;
        }
        if (salesStat.confirmedBuyTONAmountWithoutEarly <= 0) {
            self.notifyZero("Not enough confirmed funds excluding early round".asComment());
            return;
        }

        //There must be at least 1 TON on the contract balance
        if (myBalance() < ton("1")) {
            self.notifyZero("Minimum contract balance: 1 TON".asComment());
            return;
        }

        //
        let dexSettings: DEXSettings = self.dexSettings;
        let tradeBalance: Int = salesStat.confirmedBuyTONAmountWithoutEarly;
        let projectComissionAmount: Int = (tradeBalance * self.comissions.comissionValue) / (100 * milliTons);

        //How much money is going to come out of the contract
        let transferAmount: Int = tradeBalance - projectComissionAmount;

        //How much money will be placed on the DEX
        let dexLiquidity: Int = (transferAmount * dexSettings.tonPercent) / (100 * milliTons);

        //How much remains at the disposal of DAO participants
        let daoHoldersAmount: Int = transferAmount - dexLiquidity;

        //
        let jettonComission: Int = ton("0.5");
        let minTonAmount: Int = jettonComission + ton("0.1") + ton("0.3");
        let sendTonAmount: Int = dexLiquidity + minTonAmount;

        //
        if (myBalance() <= sendTonAmount || sendTonAmount <= 0) {
            let str: StringBuilder = beginComment();
            str.append("Insufficient balance, need: ");
            str.append(sendTonAmount.toCoinsString());
            str.append(" TON");
            self.notifyZero(str.toCell());
            return;
        }
        if (self.airdropCanBeStarted) {
            self.notifyZero("Already started".asComment());
            return;
        }
        if (self.dexPrepareWaitUntilTime == 0) {
            self.notifyZero("Preparation not started".asComment());
            return;
        }
        if (now() < self.dexPrepareWaitUntilTime) {
            self.notifyZero("Wait after preparation".asComment());
            return;
        }

        //The unlock date is set from the start of the listing
        self.fillUnlockOptionsDates();

        //Tokens that are not distributed in the DAO will be burned
        let daoNotAllocated: Int = self.daoSupply - self.daoHoldersCoins;

        //Blocking the possibility of changes in the contract
        self.contractLocks = ContractLocks{
            daoHoldersLocked: true,                                                     //[*] security-check
            salesLocked: true                                                           //[*] security-check
        };

        //
        let str: StringBuilder = beginComment();
        str.append("Listing on DEX. ");
        str.append(getDexName(dexSettings.dexKey));
        str.append(", tokens: ");
        str.append(dexSettings.jettonCount.toCoinsString());
        str.append(", total collected: ");
        str.append(tradeBalance.toCoinsString());
        str.append(" TON, listing fee: ");
        str.append(projectComissionAmount.toCoinsString());
        str.append(" TON (");
        str.append((self.comissions.comissionValue / milliTons).toString());
        str.append("%)");
        str.append(", DAO holders: ");
        str.append(daoHoldersAmount.toCoinsString());
        str.append(" TON, liquidity: ");
        str.append(dexLiquidity.toCoinsString());
        str.append(" TON (");
        str.append((dexSettings.tonPercent / milliTons).toString());
        str.append("%)");
        str.append(", tokens burned: ");
        str.append(daoNotAllocated.toCoinsString());

        //
        let sendJettonAmount: Int = dexSettings.jettonCount;
        if (self.dexSettings.dexKey == kDEXDedust) {
            if ((self.dedustTonTransferAddress == null) || (self.dedustJettonTransferAddress == null)) {
                self.notifyZero("Wrong DEX Address".asComment());
                return;
            }

            let asset0Cell: Cell = beginCell()
                .storeUint(0, 4)
                .endCell();

            let asset1Cell: Cell = beginCell()
                .storeUint(1, 4)
                .storeInt(0, 8)
                .storeSlice(self.jettonMasterAddressHash!!)
                .endCell();

            let tonTransfer: Cell = getDedustTONTransferPayload(asset0Cell, asset1Cell, dexLiquidity, sendJettonAmount);
            let jettonTransfer: Cell = getDedustJettonTransferPayload(asset0Cell, asset1Cell, dexLiquidity, sendJettonAmount);

            send(SendParameters{
                to: self.dedustTonTransferAddress!!,                                    //[*] security-check
                value: dexLiquidity + ton("0.3"),
                mode: SendPayGasSeparately,
                body: tonTransfer
            });

            send(SendParameters{
                to: self.jettonWalletAddress!!,
                value: jettonComission,
                mode: 0,
                bounce: false,
                body: TransferMessageWithPayload{
                    queryId: 0,
                    jettonAmount: sendJettonAmount,
                    toAddress: self.dedustJettonTransferAddress!!,                      //[*] security-check
                    responseAddress: myAddress(),
                    forwardAmount: ton("0.4"),
                    payload: jettonTransfer.asSlice()
                }.toCell()
            });

            self.airdropCanBeStarted = true;
            self.isTradeStopped = true;   
            self.dexClaimWaitUntilTime = now() + 60;
        }

        //Burn the remaining tokens
        self.burnedTokensSales = self.calcSalesBurnedTokens();
        self.burnTokens(self.burnedTokensSales + daoNotAllocated);

        //
        self.daoVetoState.vetoActiveTokens = self.salesSupply - self.burnedTokensSales;
        
        //Send project comission
        send(SendParameters{
            to: self.comissions.comissionAddress,
            value: projectComissionAmount,
            mode: SendPayGasSeparately,
            bounce: false,
            body: str.toCell()
        });
    }

    /*
     * Burns a certain amount of tokens
    */
    fun burnTokens(burnAmount: Int) {
        if (burnAmount <= 0) {
            return;
        }

        self.burnedTokens += burnAmount;

        send(SendParameters{
            to: self.jettonWalletAddress!!,
            value: ton("0.1"),
            mode: SendPayGasSeparately,
            bounce: false,
            body: BurnMessage{
                queryId: 0,
                jettonAmount: burnAmount,
                responseAddress: myAddress()
            }.toCell()
        });
    }

    /*
     * Carrying out final actions - for example, creating a record in DEX holders
    */
    fun completeSales() {
        let str: StringBuilder = beginComment();
        str.append("Completed sales: ");

        let noCompleted: Bool = true;
        foreach (saleIndex, sale in self.sales) {
            let saleEx: SaleDetailsEx = self.salesEx.get(saleIndex)!!;
            let saleBuyers: SaleBuyers = self.buyers.get(saleIndex)!!;

            let saleOptions: SaleOptions = sale.saleOptions;

            if (!sale.completed && (saleBuyers.pendingBuyTONAmount <= 0)) {
                let isFinishedByTime: Bool = (saleOptions.timeEnd <= now()) && saleOptions.isDateSet;
                let isFinishedByState: Bool = !sale.active;
                let isFinishedByCap: Bool = (saleBuyers.confirmedBuyTONAmount >= sale.capMaxChecked);

                //
                let isFinished: Bool = (isFinishedByTime || isFinishedByState || isFinishedByCap) && saleOptions.isDateSet;

                //
                let isTargetCapReached: Bool = (saleBuyers.confirmedBuyTONAmount >= saleOptions.capMin);
                let isFinishedSuccess: Bool = isFinished && sale.active && isTargetCapReached;

                //Create an entry in the DAO so that liquidity can be withdrawn
                if (isFinishedSuccess) {
                    let daoHolder: DAOHolderDetails = saleEx.daoHolder;
                    let projectComissionAmount: Int = (saleBuyers.confirmedBuyTONAmount * self.comissions.comissionValue) / (100 * milliTons);

                    //How much money is going to come out of the contract
                    let transferAmount: Int = saleBuyers.confirmedBuyTONAmount - projectComissionAmount;

                    //Percentage of liquidity sent to DEX
                    let useTonPercent: Int = self.dexSettings.tonPercent;

                    //Early round money is not sent to the liquidity pool on DEX
                    if (saleOptions.saleType == kSaleTypeEarlyRound) {
                        useTonPercent = 0;
                    }

                    //How much money will be placed on the DEX
                    let dexLiquidity: Int = (transferAmount * useTonPercent) / (100 * milliTons);

                    //
                    let usedJettons: Int = 0;
                    if (saleOptions.saleType == kSaleTypeFairlunch) {
                        usedJettons = saleOptions.jettonsReserved;
                    } else {
                        usedJettons = (saleBuyers.confirmedBuyTONAmount * nanoTons) / saleOptions.buyPrice;
                    }

                    //
                    let burnedTokens = saleOptions.jettonsReserved - usedJettons;
                    if (burnedTokens < 0) {
                        burnedTokens = 0;
                    }
                    
                    //
                    daoHolder.count = transferAmount - dexLiquidity;
                    daoHolder.assetType = kAssetTypeTON;
                    daoHolder.editLocked = true;

                    //
                    let daoHolderIndex: Int = self.daoHoldersRecordsCounter;
                    self.daoHoldersRecords.set(daoHolderIndex, DAOHolderRecord{
                        active: true,
                        holderIndex: daoHolderIndex,
                        holder: daoHolder,
                        saleIndex: sale.saleIndex
                    });

                    self.daoHoldersRecordsCounter = self.daoHoldersRecordsCounter + 1;
                    self.daoHoldersTON = self.daoHoldersTON + daoHolder.count;

                    //
                    noCompleted = false;

                    //
                    str.append(saleIndex.toString());
                    str.append(". ");
                    str.append(getSaleTypeName(saleOptions.saleType)!!);
                    str.append(", collected: ");
                    str.append(saleBuyers.confirmedBuyTONAmount.toCoinsString());
                    str.append(" TON, listing fee: ");
                    str.append(projectComissionAmount.toCoinsString());
                    str.append(" TON (");
                    str.append((self.comissions.comissionValue / milliTons).toString());
                    str.append("%), DEX liquidity: ");
                    str.append(dexLiquidity.toCoinsString());
                    str.append(" TON (");
                    str.append((useTonPercent / milliTons).toString());
                    str.append("%)");
                    str.append(", tokens burned: ");
                    str.append(burnedTokens.toCoinsString());
                    str.append("; ");                    
                }

                //Returning tokens back to DAO
                if (isFinished && !isFinishedSuccess) {
                    noCompleted = false;

                    let daoEntriesCancelled: Int = 0;

                    //Canceling entries in a DAO
                    foreach (daoEntryKey, daoHolderRecord in self.daoHoldersRecords) {
                        if (daoHolderRecord.active && (daoHolderRecord.saleIndex == sale.saleIndex)) {
                            daoHolderRecord.active = false;

                            if (daoHolderRecord.holder.assetType == kAssetTypeJetton) {
                                self.daoHoldersCoins = self.daoHoldersCoins - daoHolderRecord.holder.count;
                            } else {
                                self.daoHoldersTON = self.daoHoldersTON - daoHolderRecord.holder.count;
                            }

                            daoEntriesCancelled += 1;

                            self.daoHoldersRecords.set(daoEntryKey, daoHolderRecord);
                        }
                    }

                    //
                    str.append(saleIndex.toString());
                    str.append(". ");
                    str.append(getSaleTypeName(saleOptions.saleType)!!);
                    str.append(", tokens returned to DAO: ");
                    str.append(saleOptions.jettonsReserved.toCoinsString());
                    str.append(", DAO entries cancelled: ");
                    str.append(daoEntriesCancelled.toString());
                    str.append("; ");

                    //
                    self.salesSupply -= saleOptions.jettonsReserved;
                    self.daoSupply += saleOptions.jettonsReserved;
                }

                //Save changes
                if (isFinished) {                                                               //[*] security-check
                    sale.completed = true;
                    sale.completedSuccess = isFinishedSuccess;
                    self.sales.set(saleIndex, sale);
                }
            }
        }

        //
        if (noCompleted) {
            return;
        }

        //Notify platform
        send(SendParameters{
            to: self.comissions.comissionAddress,
            value: 0,
            mode: SendPayGasSeparately,
            bounce: false,
            body: str.toCell()
        });
    }

    /*
     * Calculates how many sale tokens will be burned during the DEX listing
    */
    fun calcSalesBurnedTokens(): Int {
        let burnedTokensAll: Int = 0;

        let saleIndex: Int = 0;
        while(saleIndex < self.salesCounter) {
            let sale: SaleDetails = self.sales.get(saleIndex)!!;
            let saleBuyers: SaleBuyers = self.buyers.get(saleIndex)!!;

            let saleOptions: SaleOptions = sale.saleOptions;

            let isFinishedByTime: Bool = (saleOptions.timeEnd <= now()) && saleOptions.isDateSet;
            let isFinishedByState: Bool = !sale.active;
            let isFinishedByCap: Bool = (saleBuyers.confirmedBuyTONAmount >= sale.capMaxChecked);

            //
            let isFinished: Bool = (isFinishedByTime || isFinishedByState || isFinishedByCap) && saleOptions.isDateSet;

            //
            let isTargetCapReached: Bool = (saleBuyers.confirmedBuyTONAmount >= saleOptions.capMin);
            let isFinishedSuccess: Bool = isFinished && sale.active && isTargetCapReached;

            //Create an entry in the DAO so that liquidity can be withdrawn
            if (isFinishedSuccess) {
                let usedJettons: Int = 0;
                if (saleOptions.saleType == kSaleTypeFairlunch) {
                    usedJettons = saleOptions.jettonsReserved;
                } else {
                    usedJettons = (saleBuyers.confirmedBuyTONAmount * nanoTons) / saleOptions.buyPrice;
                }

                //
                let burnedTokens = saleOptions.jettonsReserved - usedJettons;
                if (burnedTokens < 0) {
                    burnedTokens = 0;
                }
                
                burnedTokensAll += burnedTokens;
            }

            saleIndex += 1;
        }

        return burnedTokensAll;
    }

    /*
     * Participate in sales
    */
    receive(msg: SaleParticipate) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (msg.saleIndex < 0 || msg.saleIndex >= self.salesCounter) {
            self.notifyGreedy("wrong saleIndex".asComment());
            return;
        }

        let sale: SaleDetails = self.sales.get(msg.saleIndex)!!;
        let saleBuyers: SaleBuyers = self.buyers.get(msg.saleIndex)!!;

        require(msg.saleIndex == sale.saleIndex, "wrong saleIndex");

        //Checking the sales start time
        let saleOptions: SaleOptions = sale.saleOptions;
        if (!saleOptions.isDateSet) {
            self.notifyGreedy("Start date not set".asComment());
            return;
        }

        if (saleOptions.timeStart > now()) {
            let waitTime: Int = saleOptions.timeStart - now();

            //
            let str: StringBuilder = beginComment();
            str.append("Sales not started, wait ");
            str.append(waitTime.toString());
            str.append(" sec");
            self.notifyGreedy(str.toCell());
            return;
        }

        //
        if (!sale.active) {
            self.notifyGreedy("Sales stopped".asComment());
            return;
        }

        //Checking the sales end time (sales completion at time)
        if ((saleOptions.timeEnd <= now()) && sale.completed) {
            self.notifyGreedy("Sales completed by time".asComment());
            return;
        }

        //Completion of trading upon reaching the hard cap, "sale.capMaxChecked" value is used 
        let buyTONAmountPending: Int = saleBuyers.confirmedBuyTONAmount + saleBuyers.pendingBuyTONAmount;
        if ((buyTONAmountPending >= sale.capMaxChecked) && sale.completed) {
            self.notifyGreedy("Sales completed by hard cap".asComment());
            return;
        }

        //Bot protection mode
        if (self.botProtectionEnabled) {
            let signMessage: StringBuilder = beginString();
            signMessage.append(myAddress().toString());
            signMessage.append(sender().toString());
            if (!checkSignature(sha256(signMessage.toString()), msg.saleSign, selfTestKey)) {
                self.notifyZero("Bot protection module enabled".asComment());
                return;
            }
        }

        //
        let tonAmount: Int = context().value;
        let buyRequestID: Int = saleBuyers.nextBuyRequestID;
        let pendingBuyers: map<Int, PendingBuyers> = saleBuyers.pendingBuyers;

        /*
         * Checking the maximum cap (sales completion at cap)
         * When buying, it uses a check by value "saleOptions.capMax"
         * The "sale.capMaxChecked" value is used to determine the purchase status which is less by kCapMaxInaccuracy
        */
        let buyTONAmountPendingWillBe: Int = buyTONAmountPending + tonAmount;
        let availableTON: Int = saleOptions.capMax - buyTONAmountPending;

        //
        if (buyTONAmountPendingWillBe > saleOptions.capMax) {
            let str: StringBuilder = beginComment();
            str.append("Hard cap will be exceeded. Available: ");
            str.append(availableTON.toCoinsString());
            str.append(" TON");
            self.notifyGreedy(str.toCell());
            return;
        }

        //Check minimum purchase amount
        if (tonAmount < saleOptions.minBuyTONAmount) {
            let salesStat: SalesStat = self.getSalesStat();
            if (salesStat.finishedUncompletedCount > 0) {
                self.completeSales();
            }

            //
            let str: StringBuilder = beginComment();
            str.append("Minimum purchase amount: ");
            str.append(saleOptions.minBuyTONAmount.toCoinsString());
            str.append(" TON");
            self.notifyGreedy(str.toCell());
            return;
        }

        //
        if (saleBuyers.pendingBuyCount > maxPendingBuyersListSize) {
            let str: StringBuilder = beginComment();
            str.append("Too many buyers on the waiting list");
            self.notifyGreedy(str.toCell());
            return;
        }
        
        //Adding a buyer to the pending list
        pendingBuyers.set(buyRequestID, PendingBuyers{
            clientAddress: sender(),
            buyTONAmount: tonAmount
        });
        saleBuyers.pendingBuyTONAmount += tonAmount;
        saleBuyers.pendingBuyCount += 1;
        saleBuyers.pendingBuyers = pendingBuyers;
        saleBuyers.nextBuyRequestID = buyRequestID + 1;

        //Saving sales information
        self.buyers.set(sale.saleIndex, saleBuyers);

        //
        let limitTotalAmount: Int = saleOptions.maxBuyTONAmount;

        //
        let init: StateInit = initOf StorageContract(myAddress(), sender(), sale.saleIndex);
        let storageContractAddress: Address = contractAddress(init);
        send(SendParameters{
            to: storageContractAddress,
            body: BuyRequest{
                buyRequestID: buyRequestID,
                limitTotalAmount: limitTotalAmount,
                comment: msg.comment
            }.toCell(),
            value: 0,
            mode: SendRemainingValue,
            code: init.code,
            data: init.data
        });
    }

    /*
     * Buy answer
    */
    receive(msg: BuyRequestAnswer) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let init: StateInit = initOf StorageContract(myAddress(), msg.storageState.clientAddress, msg.storageState.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //Security check
        if (storageContractAddress != sender()) {                                               //[*] security-check
            self.notifyGreedy("wrong contract address".asComment());
            return;
        }

        //
        let saleBuyers: SaleBuyers = self.buyers.get(msg.storageState.saleIndex)!!;
        let pendingBuyers: map<Int, PendingBuyers> = saleBuyers.pendingBuyers;
        let pendingBuyerItem: PendingBuyers = pendingBuyers.get(msg.buyRequestID)!!;

        //
        if (pendingBuyerItem.clientAddress != msg.storageState.clientAddress) {
            self.notifyGreedy("wrong clientAddress".asComment());
            return;
        }

        //
        saleBuyers.pendingBuyTONAmount -= pendingBuyerItem.buyTONAmount;
        saleBuyers.pendingBuyCount -= 1;

        //
        if (msg.successAnswer) {
            saleBuyers.confirmedBuyTONAmount += msg.realBuyAmount;
            saleBuyers.confirmedBuyCount += 1;
        }
        
        //
        pendingBuyers.del(msg.buyRequestID);
        saleBuyers.pendingBuyers = pendingBuyers;

        //Saving sales information
        self.buyers.set(msg.storageState.saleIndex, saleBuyers);

        //Writing to storage failed with error
        if (!msg.successAnswer) {
            let salesStat: SalesStat = self.getSalesStat();
            if (salesStat.finishedUncompletedCount > 0) {
                self.completeSales();
            }

            //
            let str: StringBuilder = beginComment();
            str.append("Error: ");
            str.append(getStorageBuyRequestErrorName(msg.errorCode));
            send(SendParameters{
                to: msg.storageState.clientAddress,
                value: 0,
                bounce: false,
                mode: SendRemainingValue,       //it is important to return the balance to the client
                body: str.toCell()
            });
            return;
        }

        //Preparing a welcome message
        let str: StringBuilder = beginComment();
        str.append("Thanks! Total amount: ");
        str.append(msg.storageState.buyAssetAmount.toCoinsString());
        str.append(" TON");

        send(SendParameters{
            to: self.creator,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SaleParticipateSuccess{
                storageAddress: storageContractAddress,
                realBuyAmount: msg.realBuyAmount,

                storageState: msg.storageState,
                commentPrefix: 0,
                comment: msg.comment
            }.toCell()
        });

        send(SendParameters{
            to: msg.storageState.clientAddress,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });

        //
        let salesStat: SalesStat = self.getSalesStat();

        /*
         * If there are unprocessed sales, process them
         * This is necessary for the early round to add a record to DAO Holders
        */
        if (salesStat.finishedUncompletedCount > 0) {
            self.completeSales();
            salesStat = self.getSalesStat();
        }

        /*
         * Automatic token listing if there are no coins left for sale
        */
        if (self.isAutoListingAvailable(salesStat)) {
            self.dexListing(salesStat);
        }
    }

    fun isAutoListingAvailable(salesStat: SalesStat): Bool {
        let daoNotAllocated: Int = self.daoSupply - self.daoHoldersCoins;
        return (salesStat.unfinishedSalesCount <= 0) && 
            (salesStat.confirmedBuyTONAmountWithoutEarly > 0) && 
            (myBalance() >= ton("1.5")) &&
            (daoNotAllocated <= kMaxDaoNotAllocatedForAutoListing);
    }

    /*
     * Returns either tokens or makes a return in TONs
    */
    receive(msg: SaleClaim) {
        require(self.jettonWalletAddress != null, "contract not inited");
        require(context().value >= ton("0.15"), "too small amount");

        if (msg.saleIndex < 0 || msg.saleIndex >= self.salesCounter) {
            self.notifyGreedy("wrong saleIndex".asComment());
            return;
        }

        let sale: SaleDetails = self.sales.get(msg.saleIndex)!!;
        let saleEx: SaleDetailsEx = self.salesEx.get(msg.saleIndex)!!;
        let saleBuyers: SaleBuyers = self.buyers.get(msg.saleIndex)!!;

        require(msg.saleIndex == sale.saleIndex, "wrong saleIndex");

        //Checking the sales start time
        let saleOptions: SaleOptions = sale.saleOptions;

        if (!saleOptions.isDateSet) {
            self.notifyGreedy("Start date not set".asComment());
            return;
        }
        
        if (saleOptions.timeStart > now()) {
            self.notifyGreedy("Sales not started".asComment());
            return;
        }

        //
        let isFinishedByTime: Bool = (saleOptions.timeEnd <= now()) && saleOptions.isDateSet;
        let isFinishedByState: Bool = !sale.active;
        let isFinishedByCap: Bool = (saleBuyers.confirmedBuyTONAmount >= sale.capMaxChecked);

        //
        let isFinished: Bool = (isFinishedByTime || isFinishedByState || isFinishedByCap) && saleOptions.isDateSet;
        if (!isFinished) {
            self.notifyGreedy("Sales not finished".asComment());
            return;
        }

        //
        let salesStat: SalesStat = self.getSalesStat();
        
        /*
         * If there are unprocessed sales, process them
         * This is necessary for the early round to add a record to DAO Holders
        */
        if (salesStat.finishedUncompletedCount > 0) {
            self.completeSales();
        }

        //
        let isTargetCapReached: Bool = (saleBuyers.confirmedBuyTONAmount >= saleOptions.capMin);
        let isFinishedSuccess: Bool = sale.active && isTargetCapReached;

        //
        let init: StateInit = initOf StorageContract(myAddress(), sender(), sale.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //
        if (!isFinishedSuccess) {
            send(SendParameters{
                to: storageContractAddress,
                body: ClaimRequestFull{
                    queryId: msg.queryId,
                    contractTONBalance: myBalance(),
                    comment: msg.comment
                }.toCell(),
                value: 0,
                mode: SendRemainingValue,
                code: init.code,
                data: init.data
            });
            return;
        }

        //
        if (!self.airdropStarted) {
            self.notifyGreedy("Available only after listing on DEX".asComment());
            return;
        }

        /*
         * After listing do not allow tokens to be taken immediately
        */
        if ((now() < self.dexClaimWaitUntilTime) || (self.dexClaimWaitUntilTime == 0)) {
            let waitTime: Int = self.dexClaimWaitUntilTime - now();
            let str: StringBuilder = beginComment();
            str.append("Listing not completed, wait ");
            str.append(waitTime.toString());
            str.append(" sec");
            return;
        }

        /*
         * The price in the storage contract is transferred in millis - this increases the accuracy of calculations
        */
        let itemPriceMilli: Int = 0;
        if (saleOptions.saleType == kSaleTypeFairlunch) {
            itemPriceMilli = (saleBuyers.confirmedBuyTONAmount * nanoTons * milliTons) / saleOptions.jettonsReserved;      //fairlunch
        } else {
            itemPriceMilli = saleOptions.buyPrice * milliTons;                                                            //presale
        }

        //
        if (itemPriceMilli <= 0) {
            self.notifyGreedy("Can not get buyPrice".asComment());
            return;
        }

        //
        let salesFreeTokens: Int = self.salesSupply - self.salesClaimedTokens;
        if (salesFreeTokens <= 0) {
            self.notifyGreedy("There are no tokens on the contract available for claiming".asComment());
            return;
        }

        //
        send(SendParameters{
            to: storageContractAddress,
            body: ClaimRequestAsset{
                queryId: msg.queryId,
                salesFreeTokens: salesFreeTokens,
                itemPriceMilli: itemPriceMilli,
                unlockOptions: saleEx.unlockOptions,
                comment: msg.comment
            }.toCell(),
            value: 0,
            mode: SendRemainingValue,
            code: init.code,
            data: init.data
        });
        return;
    }

    /*
     * Handling an error message when withdrawing funds
    */
    receive(msg: ClaimRequestErrorAnswer) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let init: StateInit = initOf StorageContract(myAddress(), msg.storageState.clientAddress, msg.storageState.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //Security check
        if (storageContractAddress != sender()) {                                                       //[*] security-check
            self.notifyGreedy("wrong contract address".asComment());
            return;
        }

        //Forwarding the message to the fund holder
        send(SendParameters{
            to: msg.storageState.clientAddress,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: msg.errorMessage.asComment()
        });
        return;
    }

    /*
     * ClaimRequestFull -> ClaimRequestFullAnswer
    */
    receive(msg: ClaimRequestFullAnswer) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let init: StateInit = initOf StorageContract(myAddress(), msg.storageState.clientAddress, msg.storageState.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //Security check
        if (storageContractAddress != sender()) {                                                       //[*] security-check
            self.notifyGreedy("wrong contract address".asComment());
            return;
        }

        //
        if (msg.availableAmount <= 0) {
            send(SendParameters{
                to: msg.storageState.clientAddress,
                value: 0,
                bounce: false,
                mode: SendPayGasSeparately,
                body: "There are no funds on your balance".asComment()
            });
            return;
        }

        //
        let resendAmount: Int = context().value - context().readForwardFee() * 2 - ton("0.2");
        if (resendAmount <= 0) {
            resendAmount = 0;
        }
        
        //
        send(SendParameters{
            to: self.creator,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SaleClaimSuccess{
                storageAddress: storageContractAddress,

                haveCoins: false,
                assetAmount: msg.availableAmount,

                storageState: msg.storageState,
                commentPrefix: 0,
                comment: msg.comment
            }.toCell()
        });

        //
        let sendAmount: Int = msg.availableAmount + resendAmount;

        //Do not transfer more than is on the contract
        let maxSendAmount: Int = myBalance() - ton("0.1");
        if (sendAmount > maxSendAmount) {
            sendAmount = maxSendAmount;
        }

        //
        let str: StringBuilder = beginComment();
        str.append("You receive ");
        str.append(sendAmount.toCoinsString());
        str.append(" TON");

        send(SendParameters{
            to: msg.storageState.clientAddress,
            value: sendAmount,
            bounce: false,
            mode: 0,
            body: str.toCell()
        });
        return;
    }

    /*
     * ClaimRequestAsset -> ClaimRequestAssetAnswer
    */
    receive(msg: ClaimRequestAssetAnswer) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let init: StateInit = initOf StorageContract(myAddress(), msg.storageState.clientAddress, msg.storageState.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //Security check
        if (storageContractAddress != sender()) {                                                       //[*] security-check
            self.notifyGreedy("wrong contract address".asComment());
            return;
        }

        //
        if (msg.availableTokens <= 0) {
            send(SendParameters{
                to: msg.storageState.clientAddress,
                value: 0,
                bounce: false,
                mode: SendPayGasSeparately,
                body: "There are no tokens available".asComment()
            });
            return;
        }

        //
        let jettonComission: Int = ton("0.04");

        //
        let resendAmount: Int = context().value - context().readForwardFee() * 2 - jettonComission - ton("0.2");
        if (resendAmount <= 0) {
            resendAmount = 0;
        }

        //Save how many tokens have already been claimed
        self.salesClaimedTokens += msg.availableTokens;

        //
        send(SendParameters{
            to: self.creator,
            value: resendAmount,
            bounce: false,
            mode: SendPayGasSeparately,
            body: SaleClaimSuccess{
                storageAddress: storageContractAddress,

                haveCoins: true,
                assetAmount: msg.availableTokens,

                storageState: msg.storageState,

                commentPrefix: 0,
                comment: msg.comment
            }.toCell()
        });

        //Transferring tokens to the sender's wallet
        send(SendParameters{
            to: self.jettonWalletAddress!!,
            value: jettonComission,
            mode: SendPayGasSeparately,
            bounce: false,
            body: TransferMessage{
                queryId: msg.queryId,
                jettonAmount: msg.availableTokens,
                toAddress: msg.storageState.clientAddress,                          //Address who will receive the tokens
                responseAddress: msg.storageState.clientAddress,                    //ExcessesNotification address
                forwardAmount: 0                                                    //Inform the token recipient's wallet
            }.toCell()
        });
    }

    /*
     * Recive Jettons -> Send TON
    */
    receive(msg: TransferNotification) {
        require(self.jettonWalletAddress != null, "contract not inited");
        require(msg.jettonAmount > 0, "wrong jettonAmount");

        //Get LP token from Dedust
        if (self.airdropCanBeStarted && (
            (sender() != self.jettonWalletAddress)
        )) {
            if (self.airdropStarted) {
                return;
            }
            
            self.airdropStarted = true;
            send(SendParameters{
                to: self.creator,
                value: ton("0.001"),
                mode: SendIgnoreErrors,
                body: "DEX transfer completed".asComment()
            });
            return;
        }

        //
        require(sender() == self.jettonWalletAddress, "wrong sender address");                                      //[*] security-check

        //If trade not started
        if (!self.isTradeActive) {
            require(msg.jettonAmount == self.totalSupply, "wrong jettonAmount <> totalSupply");

            if (sender() == self.jettonWalletAddress) {
                self.isTradeActive = true;

                send(SendParameters{
                    to: self.creator,
                    value: ton("0.001"),
                    mode: SendPayGasSeparately,
                    body: "Contract deployed".asComment()
                });
            }
            return;
        }

        //
        if (self.daoVetoState.vetoActivated) {
            let sendTONAmount: Int = (msg.jettonAmount * self.daoVetoState.vetoPriceNano) / nanoTons;
            send(SendParameters{
                to: msg.fromAddress,
                value: sendTONAmount,
                mode: 0,
                body: DAOVetoClaimSuccess{
                    sellTokensAmount: msg.jettonAmount,
                    sendTONAmount: sendTONAmount,
                    comment: msg.forwardPayload
                }.toCell()
            });
            return;
        }
    }

    /*
     * Notification of receipt of jettons
    */
    receive(msg: ExcessesNotification) {
    }

    /*
     * Adds an entry to the DAO list
    */
    receive(msg: DAOHoldersAdd) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                                                     //[*] security-check

        if (self.isTradeStopped) {
            self.notifyGreedy("Already completed".asComment());
            return;
        }

        if (self.contractLocks.daoHoldersLocked) {                                                              //[*] security-check
            self.notifyGreedy("DAO entries locked".asComment());
            return;
        }

        if (msg.daoHoldersRecordsCounter != self.daoHoldersRecordsCounter) {
            self.notifyGreedy("Wrong daoHoldersListCounter".asComment());
            return;
        }

        let daoHolders: map<Int, DAOHolderDetails> = msg.daoHolders;

        //
        let addCoins: Int = 0;
        let addTON: Int = 0;
        let addHoldersCount: Int = 0;

        //Calc added coins
        foreach (key, daoHolder in daoHolders) {
            require(daoHolder.count > 0, "wrong count");
            require(daoHolder.assetType == kAssetTypeJetton, "wrong type");
            require(daoHolder.onlyAfterDex, "wrong onlyAfterDex");

            let checkUnlockOptionsResult = checkUnlockOptions(daoHolder.unlockOptions);
            if (checkUnlockOptionsResult != 1) {
                let err: StringBuilder = beginComment();
                err.append("wrong daoHolder.unlockOptions, error: ");
                err.append(checkUnlockOptionsResult.toString());
                self.notifyGreedy(err.toCell());
                return;
            }

            if (daoHolder.assetType == kAssetTypeJetton) {
                addCoins = addCoins + daoHolder.count;
            } else {
                addTON = addTON + daoHolder.count;
            }

            addHoldersCount += 1;
        }

        //Checks
        let daoHoldersCoinsWillBe: Int = self.daoHoldersCoins + addCoins;
        if (daoHoldersCoinsWillBe > self.daoSupply) {
            self.notifyGreedy("Not enough coins in DAO to distribute".asComment());
            return;
        }
        if (addHoldersCount <= 0) {
            self.notifyGreedy("The list of added records is empty".asComment());
            return;
        }

        //
        if ((self.daoHoldersRecordsCounter + addHoldersCount) >= kMaxDAOHoldersSize) {
            self.notifyGreedy("Too many holders".asComment());
            return;
        }

        //
        let str: StringBuilder = beginComment();
        str.append("DAO holders added: ");

        //Save changes
        let idx: Int = 0;
        foreach (key, daoHolder in daoHolders) {
            let daoHolderIndex: Int = self.daoHoldersRecordsCounter;
            self.daoHoldersRecords.set(daoHolderIndex, DAOHolderRecord{
                active: true,
                holderIndex: daoHolderIndex,
                holder: daoHolder
            });

            self.daoHoldersRecordsCounter = self.daoHoldersRecordsCounter + 1;

            if (daoHolder.assetType == kAssetTypeJetton) {
                self.daoHoldersCoins = self.daoHoldersCoins + daoHolder.count;
            } else {
                self.daoHoldersTON = self.daoHoldersTON + daoHolder.count;
            }

            if (idx > 0) {
                str.append(", ");
            }

            str.append((daoHolderIndex).toString());
            str.append(". ");
            str.append(daoHolder.count.toCoinsString());

            idx = idx + 1;
        }

        self.notifyGreedy(str.toCell());
        return;
    }

    /*
     * Adds an entry to the DAO list
    */
    receive(msg: DAOHoldersDelete) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (self.creator != sender()) {
            self.notifyGreedy("Access denied".asComment());
            return;
        }

        require(self.creator == sender(), "access denied");                                                     //[*] security-check

        if (self.isTradeStopped) {
            self.notifyGreedy("Already completed".asComment());
            return;
        }

        if (self.contractLocks.daoHoldersLocked) {                                                              //[*] security-check
            self.notifyGreedy("DAO entries locked".asComment());
            return;
        }

        let str: StringBuilder = beginComment();
        str.append("DAO holders removed: ");

        let daoHoldersIndexs: map<Int, Bool> = msg.daoHoldersIndexs;

        //Checks
        foreach (daoIndex, val in daoHoldersIndexs) {
            let daoHolder: DAOHolderRecord? = self.daoHoldersRecords.get(daoIndex);
            if (daoHolder == null) {
                self.notifyGreedy("Unable to find record in DAO holder".asComment());
                return;
            }

            let daoHolderSafe: DAOHolderRecord = daoHolder!!;
            if (daoHolderSafe.holderIndex != daoIndex) {
                self.notifyGreedy("Wrong holderIndex".asComment());
                return;
            }
            if (!daoHolderSafe.active) {
                self.notifyGreedy("One of the entries has already been cancelled".asComment());
                return;
            }
            if (daoHolderSafe.holder.editLocked) {                                                              //[*] security-check
                self.notifyGreedy("One of the entries is protected from editing".asComment());
                return;
            }
        }

        //Save
        let idx: Int = 0;
        foreach (daoIndex, val in daoHoldersIndexs) {
            let daoHolderSafe: DAOHolderRecord = self.daoHoldersRecords.get(daoIndex)!!;
            let prevCount: Int = daoHolderSafe.holder.count;
            require(prevCount > 0, "wrong prevCount");
            
            if (daoHolderSafe.holder.assetType == kAssetTypeJetton) {
                self.daoHoldersCoins = self.daoHoldersCoins - daoHolderSafe.holder.count;
            } else {
                self.daoHoldersTON = self.daoHoldersTON - daoHolderSafe.holder.count;
            }

            daoHolderSafe.active = false;
            self.daoHoldersRecords.set(daoIndex, daoHolderSafe);

            if (idx > 0) {
                str.append(", ");
            }

            str.append((daoIndex).toString());
            str.append(". ");
            str.append(prevCount.toCoinsString());
            str.append(" -> 0");

            idx = idx + 1;
        }

        self.notifyGreedy(str.toCell());
        return;
    }

    /*
     * Takes tokens from DAO
    */
    receive(msg: DAOHoldersClaim) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let daoHolder: DAOHolderRecord? = self.daoHoldersRecords.get(msg.daoHolderIndex);
        if (daoHolder == null) {
            self.notifyGreedy("Unable to find record in DAO holder".asComment());
            return;
        }

        let daoHolderSafe: DAOHolderRecord = daoHolder!!;
        if (daoHolderSafe.holderIndex != msg.daoHolderIndex) {
            self.notifyGreedy("Wrong holderIndex".asComment());
            return;
        }
        if (!daoHolderSafe.active) {
            self.notifyGreedy("Has already been cancelled".asComment());
            return;
        }

        //
        let daoHolderDetails: DAOHolderDetails = daoHolderSafe.holder;
        let claimedTokens: Int = daoHolderSafe.used;

        //According to this entry, funds can only be withdrawn after listing on DEX
        if (daoHolderDetails.onlyAfterDex && !self.airdropStarted) {
            self.notifyGreedy("Available only after listing on DEX".asComment());
            return;
        }

        //
        let tokensCount: Int = calculateUnlockedAmount(daoHolderDetails.count, daoHolderDetails.unlockOptions, now());
        let availableTokens: Int = tokensCount - claimedTokens;

        //
        require(tokensCount <= daoHolderDetails.count, "wrong tokensCount <= daoHolderDetails.count");                      //[*] security-check

        //
        if (availableTokens <= 0) {                                                                                         //[*] security-check
            self.notifyGreedy("No available assets".asComment());
            return;
        }

        /*
         * After listing do not allow tokens to be taken immediately
        */
        if (daoHolderDetails.onlyAfterDex && (self.dexClaimWaitUntilTime > 0) && (now() < self.dexClaimWaitUntilTime)) {
            let waitTime: Int = self.dexClaimWaitUntilTime - now();
            let str: StringBuilder = beginComment();
            str.append("Listing not completed, wait ");
            str.append(waitTime.toString());
            str.append(" sec");
            return;
        }

        //
        require(tokensCount >= 0, "wrong tokensCount");
        require(availableTokens >= 0, "wrong availableAmount");

        //
        claimedTokens += availableTokens;

        //
        let resendAmount: Int = context().value - context().readForwardFee() * 2 - ton("0.1");
        if (resendAmount <= 0) {
            resendAmount = 0;
        }

        //Transferring tokens to the sender's wallet
        if (daoHolderDetails.assetType == kAssetTypeJetton) {
            let jettonComission: Int = ton("0.04");
            let sendAmount: Int = jettonComission + resendAmount;

            //Check contract balance
            if (myBalance() <= sendAmount) {
                send(SendParameters{
                    to: sender(),
                    value: 0,
                    bounce: false,
                    mode: SendPayGasSeparately,
                    body: "There are insufficient funds under the contract".asComment()
                });
                return;
            }

            send(SendParameters{
                to: self.jettonWalletAddress!!,
                value: jettonComission,
                mode: SendPayGasSeparately,
                bounce: false,
                body: TransferMessage{
                    queryId: msg.queryId,
                    jettonAmount: availableTokens,
                    toAddress: daoHolderDetails.owner,                                  //Address who will receive the tokens,         [*] security-check
                    responseAddress: myAddress(),                                       //ExcessesNotification address
                    forwardAmount: 0                                                    //Inform the token recipient's wallet
                }.toCell()
            });

            //Notify sender
            let msgB: StringBuilder = beginComment();
            msgB.append("Transfer ");
            msgB.append(availableTokens.toCoinsString());
            msgB.append(" tokens to ");
            msgB.append(daoHolderDetails.owner.toString());

            send(SendParameters{
                to: sender(),
                value: resendAmount,
                bounce: false,
                mode: SendPayGasSeparately,
                body: msgB.toCell()
            });

            //
            self.daoClaimedTokens += availableTokens;
        }

        //
        if (daoHolderDetails.assetType == kAssetTypeTON) {
            let sendAmount: Int = availableTokens + resendAmount;

            //Check contract balance
            if (myBalance() <= sendAmount) {
                send(SendParameters{
                    to: sender(),
                    value: 0,
                    bounce: false,
                    mode: SendPayGasSeparately,
                    body: "There are insufficient funds under the contract".asComment()
                });
                return;
            }

            //
            let str: StringBuilder = beginComment();
            str.append("You receive ");
            str.append(availableTokens.toCoinsString());
            str.append(" TON");

            send(SendParameters{
                to: daoHolderDetails.owner,                                                                 //[*] security-check
                value: sendAmount,
                bounce: false,
                mode: 0,
                body: str.toCell()
            });

            //Notify sender
            let msgB: StringBuilder = beginComment();
            msgB.append("Transfer ");
            msgB.append(availableTokens.toCoinsString());
            msgB.append(" TON to ");
            msgB.append(daoHolderDetails.owner.toString());

            send(SendParameters{
                to: sender(),
                value: 0,
                bounce: false,
                mode: SendPayGasSeparately,
                body: msgB.toCell()
            });
        }

        //
        daoHolderSafe.used = claimedTokens;
        self.daoHoldersRecords.set(msg.daoHolderIndex, daoHolderSafe);
    }

    /*
     * Voting within DAO Veto
    */
    receive(msg: DAOVetoVote) {
        require(self.jettonWalletAddress != null, "contract not inited");

        if (myBalance() < ton("1")) {
            self.notifyGreedy("The contract balance must be greater than 1 TON".asComment());
            return;
        }

        if (!self.daoVetoEnabled) {
            self.notifyGreedy("DAO Veto module is not enabled".asComment());
            return;
        }

        //
        let signMessage: StringBuilder = beginString();
        signMessage.append("Veto vote: ");
        signMessage.append(myAddress().toString());
        signMessage.append(", ");
        signMessage.append(sender().toString());

        if (!checkSignature(sha256(signMessage.toString()), msg.vetoSign, selfTestKey)) {
            self.notifyGreedy("wrong sign".asComment());
            return;
        }

        //
        if (!self.airdropStarted) {
            self.notifyGreedy("Available only after listing on DEX".asComment());
            return;
        }

        //
        if ((self.dexClaimWaitUntilTime + 86400 * 365) < now()) {
            self.notifyGreedy("Voting is only available for the first year after listing".asComment());
            return;
        }

        //
        require(self.daoVetoState.vetoActiveTokens > 0, "need vetoActiveTokens > 0");

        //
        let salesActiveCount: Int = 0;
        foreach (saleIndex, sale in self.sales) {
            if (sale.completed && sale.completedSuccess) {
                salesActiveCount += 1;
            }
        }

        require(salesActiveCount > 0, "wrong salesActiveCount > 0");

        //
        let msgAmount: Int = ton("0.15");
        let needAmount: Int = (msgAmount + ton("0.05")) * salesActiveCount + ton("0.1");
        
        //
        if (context().value < needAmount) {
            let str: StringBuilder = beginComment();
            str.append("Minimum transaction amount: ");
            str.append(needAmount.toCoinsString());
            str.append(" TON");
            self.notifyGreedy(str.toCell());
            return;
        }

        //
        foreach (saleIndex, sale in self.sales) {
            let saleBuyers: SaleBuyers = self.buyers.get(saleIndex)!!;

            //Checking the sales start time
            let saleOptions: SaleOptions = sale.saleOptions;
            if (sale.completed && sale.completedSuccess) {
                let init: StateInit = initOf StorageContract(myAddress(), sender(), sale.saleIndex);
                let storageContractAddress: Address = contractAddress(init);

                /*
                * The price in the storage contract is transferred in millis - this increases the accuracy of calculations
                */
                let itemPriceMilli: Int = 0;
                if (saleOptions.saleType == kSaleTypeFairlunch) {
                    itemPriceMilli = (saleBuyers.confirmedBuyTONAmount * nanoTons * milliTons) / saleOptions.jettonsReserved;      //fairlunch
                } else {
                    itemPriceMilli = saleOptions.buyPrice * milliTons;                                                             //presale
                }

                //
                if (itemPriceMilli <= 0) {
                    self.notifyGreedy("Can not get buyPrice".asComment());
                    return;
                }

                //
                send(SendParameters{
                    to: storageContractAddress,
                    body: DAOVetoVoteRequest{
                        queryId: msg.queryId,
                        itemPriceMilli: itemPriceMilli,
                        comment: msg.comment
                    }.toCell(),
                    value: msgAmount,
                    mode: SendPayGasSeparately,
                    code: init.code,
                    data: init.data
                });
            }
        }
    }

    /*
     * DAOVetoVoteRequest -> DAOVetoVoteRequestAnswer
    */
    receive(msg: DAOVetoVoteRequestAnswer) {
        require(self.jettonWalletAddress != null, "contract not inited");

        let init: StateInit = initOf StorageContract(myAddress(), msg.storageState.clientAddress, msg.storageState.saleIndex);
        let storageContractAddress: Address = contractAddress(init);

        //Security check
        if (storageContractAddress != sender()) {                                                       //[*] security-check
            self.notifyGreedy("wrong contract address".asComment());
            return;
        }

        //
        require(msg.totalCoins > 0, "There are no tokens available");

        //
        self.daoVetoState.vetoVotedTokens += msg.totalCoins;
        self.daoVetoState.vetoVotedPercentCurrent = (self.daoVetoState.vetoVotedTokens * 100) / self.daoVetoState.vetoActiveTokens;

        /*
         * If the required number of votes is collected, the veto logic is activated
        */
        if ((self.daoVetoState.vetoVotedPercentCurrent >= self.daoVetoState.vetoVotedPercentTarget) && !self.daoVetoState.vetoActivated && (myBalance() > ton("1"))) {
            let daoHoldersAmount: Int = 0;
            let daoEntriesCancelled: Int = 0;

            //Canceling entries in a DAO except for early round
            foreach (daoEntryKey, daoHolderRecord in self.daoHoldersRecords) {
                if (daoHolderRecord.active) {
                    daoHolderRecord.active = false;

                    if (daoHolderRecord.holder.assetType == kAssetTypeJetton) {
                        self.daoHoldersCoins -= daoHolderRecord.holder.count;
                    } else {
                        daoHoldersAmount += daoHolderRecord.holder.count - daoHolderRecord.used;
                        self.daoHoldersTON -= daoHolderRecord.holder.count;
                    }

                    daoEntriesCancelled += 1;

                    self.daoHoldersRecords.set(daoEntryKey, daoHolderRecord);
                }
            }

            //
            let contactBalance: Int = myBalance() - ton("0.1");
            if (daoHoldersAmount > contactBalance) {
                daoHoldersAmount = contactBalance;
            }

            //
            let vetoAvailableTokens: Int = self.daoVetoState.vetoActiveTokens + self.daoClaimedTokens;
            let vetoPriceNano: Int = (daoHoldersAmount * nanoTons) / vetoAvailableTokens;

            
            //            
            self.daoVetoState.vetoActivated = true;
            self.daoVetoState.vetoActivatedTONLiquidity = daoHoldersAmount;
            self.daoVetoState.vetoAvailableTokens = vetoAvailableTokens;
            self.daoVetoState.vetoPriceNano = vetoPriceNano;

            //
            let msgA: StringBuilder = beginComment();
            msgA.append("Veto power activated by community. Refund ");
            msgA.append(daoHoldersAmount.toCoinsString());
            msgA.append(" TON on ");
            msgA.append(vetoAvailableTokens.toCoinsString());
            msgA.append(" tokens at ");
            msgA.append(vetoPriceNano.toCoinsString());
            msgA.append(", DAO entries cancelled: ");
            msgA.append(daoEntriesCancelled.toString());
            msgA.append("; ");

            send(SendParameters{
                to: self.creator,
                value: 0,
                bounce: false,
                mode: SendPayGasSeparately,
                body: msgA.toCell()
            });
        }

        //
        send(SendParameters{
            to: self.creator,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: DAOVetoVoteSuccess{
                storageAddress: storageContractAddress,

                totalCoins: msg.totalCoins,
                storageState: msg.storageState,

                commentPrefix: 0,
                comment: msg.comment
            }.toCell()
        });

        //
        let str: StringBuilder = beginComment();
        str.append("You used your veto power, ");
        str.append(msg.totalCoins.toCoinsString());
        str.append(" tokens");

        send(SendParameters{
            to: msg.storageState.clientAddress,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: str.toCell()
        });
        return;
    }
}
