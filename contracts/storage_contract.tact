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

import "./utils/storage_structs.tact";
import "./utils/storage_messages.tact";
import "./utils/funcs.tact";

/*
 * [*] security-check - the most important security checks are marked with this tag
*/

contract StorageContract {
    dexContract: Address;
    clientAddress: Address;
    saleIndex: Int;

    buyCount: Int as uint64 = 0;                //Number of sales transactions
    buyAssetAmount: Int as coins = 0;           //Total amount purchased

    claimedTONAmount: Int as coins = 0;
    claimedTokens: Int as coins = 0;
    claimedCount: Int as uint64 = 0;

    vetoVoted: Bool = false;

    override const storageReserve: Int = ton("0.01");
    const storageContractFee: Int = ton("0.01");
 
    init(
        dexContract: Address,
        clientAddress: Address,
        saleIndex: Int
    ) {
        self.dexContract = dexContract;
        self.clientAddress = clientAddress;
        self.saleIndex = saleIndex;
    }

    get fun state(): StorageStateMessage {
        return StorageStateMessage{
            dexContract: self.dexContract,
            clientAddress: self.clientAddress,
            saleIndex: self.saleIndex,

            buyCount: self.buyCount,
            buyAssetAmount: self.buyAssetAmount,

            claimedTONAmount: self.claimedTONAmount,
            claimedTokens: self.claimedTokens,
            claimedCount: self.claimedCount,

            vetoVoted: self.vetoVoted
        };
    }

    fun errorMessage(err: String) {
        send(SendParameters{
            to: self.clientAddress,
            value: 0,
            bounce: false,
            mode: SendPayGasSeparately,
            body: err.asComment()
        });
    }
 
    /*
     * Adding a sales request
    */
    receive(msg: BuyRequest) {
        require(self.dexContract == sender(), "access denied");                                     //[*] security-check

        //
        let realBuyAmount = context().value - context().readForwardFee() * 2 - self.storageContractFee;
        
        if (self.buyCount == 0) {
            realBuyAmount -= self.storageReserve;
        }

        //Checking the total purchase amount
        let buyAssetAmountWillBe: Int = self.buyAssetAmount + realBuyAmount;
        if (buyAssetAmountWillBe > msg.limitTotalAmount) {
            self.reply(BuyRequestAnswer{
                successAnswer: false,
                errorCode: 1000,
                buyRequestID: msg.buyRequestID,
                realBuyAmount: 0,
                storageState: self.state(),
                comment: msg.comment
            }.toCell());
            return;
        }

        //Checking the minimum purchase amount
        if (realBuyAmount <= 0) {
            self.reply(BuyRequestAnswer{
                successAnswer: false,
                errorCode: 1001,
                buyRequestID: msg.buyRequestID,
                realBuyAmount: 0,
                storageState: self.state(),
                comment: msg.comment
            }.toCell());
            return;
        }

        //
        self.buyCount += 1;
        self.buyAssetAmount += realBuyAmount;

        //
        self.reply(BuyRequestAnswer{
            successAnswer: true,
            errorCode: 0,
            buyRequestID: msg.buyRequestID,
            realBuyAmount: realBuyAmount,
            storageState: self.state(),
            comment: msg.comment
        }.toCell());
    }
 
    /*
     * Called in case of an error and a refund is required
    */
    receive(msg: ClaimRequestFull) {
        require(self.dexContract == sender(), "access denied");                                     //[*] security-check

        //
        let availableAmount: Int = self.buyAssetAmount - self.claimedTONAmount;

        /*
        * In case of funds issuance, additional checks must be carried out
        */
        if (availableAmount > 0) {
        //It is important to check the balance of the storage contract, it may decrease due to the storage fee
        if (myBalance() < ton("0.1")) {
            let str: StringBuilder = beginString();
            str.append("Error! Storage contract balance: ");
            str.append(myBalance().toCoinsString());
            str.append(" TON, minimum balance: 0.1 TON");

            self.reply(ClaimRequestErrorAnswer{
                queryId: msg.queryId,
                storageState: self.state(),
                errorMessage: str.toString()
            }.toCell());
            return;
        }

        //It is important to check that there are enough funds on the main contract
        let availableContactBalance = msg.contractTONBalance - ton("0.5");
        if (availableAmount > availableContactBalance) {
            let str: StringBuilder = beginString();
            str.append("Error! Trade contract balance: ");
            str.append(availableContactBalance.toCoinsString());
            str.append(" TON, you want to receive: ");
            str.append(availableAmount.toCoinsString());
            str.append(" TON");

            self.reply(ClaimRequestErrorAnswer{
                queryId: msg.queryId,
                storageState: self.state(),
                errorMessage: str.toString()
            }.toCell());
            return;
        }
        }

        //
        require(availableAmount >= 0, "wrong availableAmount");

        //Save before sending the message because of self.state()
        if (availableAmount > 0) {
            self.claimedCount += 1;
            self.claimedTONAmount += availableAmount;
        }

        //Sending the entire balance of the contract (contract will no longer be used)
        send(SendParameters{
            to: self.dexContract,
            value: 0,
            mode: SendRemainingBalance,
            body: ClaimRequestFullAnswer{
                queryId: msg.queryId,

                availableAmount: availableAmount,
                storageState: self.state(),
                comment: msg.comment
            }.toCell()
        });
    }

    /*
     * Tells how many tokens the client can take
    */
    receive(msg: ClaimRequestAsset) {
        require(self.dexContract == sender(), "access denied");                                     //[*] security-check

        /*
        * Calculate the amount of transfer to the main contract,
        * it must be sufficient for the contract to perform its work
        * Also leave a small amount on the storage contract
        */
        let toSend: Int = context().value - context().readForwardFee() * 2 - ton("0.01");
        if (toSend < ton("0.1")) {
            let str: StringBuilder = beginString();
            str.append("Error! Current transfer amount: ");
            str.append(toSend.toCoinsString());
            str.append(" TON, minimum 0.1 TON");

            self.reply(ClaimRequestErrorAnswer{
                queryId: msg.queryId,
                storageState: self.state(),
                errorMessage: str.toString()
            }.toCell());
            return;
        }

        /*
        * How many tokens want to take
        * Convert from milli to nano since the price in the storage contract is transferred in milli for accuracy
        */
        let totalAmount: Int = (self.buyAssetAmount * nanoTons * milliTons) / msg.itemPriceMilli;

        //How many tokens unlocked
        let tokensCount: Int = calculateUnlockedAmount(totalAmount, msg.unlockOptions, now());

        //
        require(tokensCount <= totalAmount, "wrong tokensCount <= totalAmount");                    //[*] security-check
        
        //
        let availableTokens: Int = tokensCount - self.claimedTokens;

        /*
        * In case of funds issuance, additional checks must be carried out
        */
        if (availableTokens > 0) {
            //It is important to check the balance of the storage contract, it may decrease due to the storage fee
            if (myBalance() < ton("0.1")) {
                let str: StringBuilder = beginString();
                str.append("Error! Storage contract balance: ");
                str.append(myBalance().toCoinsString());
                str.append(" TON, minimum balance: 0.1 TON");

                self.reply(ClaimRequestErrorAnswer{
                    queryId: msg.queryId,
                    storageState: self.state(),
                    errorMessage: str.toString()
                }.toCell());
                return;
            }

            //It is important to check that there are enough enough tokens on the main contract
            if (availableTokens > msg.salesFreeTokens) {
                let str: StringBuilder = beginString();
                str.append("Error! Available tokens on contract: ");
                str.append(msg.salesFreeTokens.toCoinsString());
                str.append(", you want to receive: ");
                str.append(availableTokens.toCoinsString());
                str.append(" tokens");

                self.reply(ClaimRequestErrorAnswer{
                    queryId: msg.queryId,
                    storageState: self.state(),
                    errorMessage: str.toString()
                }.toCell());
                return;
            }
        }

        //
        require(tokensCount >= 0, "wrong tokensCount");
        require(availableTokens >= 0, "wrong availableAmount");
        require(toSend > 0, "wrong toSend");

        //Save before sending the message because of self.state()
        if (availableTokens > 0) {
            self.claimedCount += 1;
            self.claimedTokens += availableTokens;
        }

        //Send notification of token transfer
        send(SendParameters{
            to: self.dexContract,
            value: toSend,
            mode: SendPayGasSeparately,
            body: ClaimRequestAssetAnswer{
                queryId: msg.queryId,
                availableTokens: availableTokens,
                storageState: self.state(),
                comment: msg.comment
            }.toCell()
        });
    }

    /*
     * Voting within DAO Veto
    */
    receive(msg: DAOVetoVoteRequest) {
        require(self.dexContract == sender(), "access denied");                                     //[*] security-check

        let toSend: Int = context().value - context().readForwardFee() * 2 - ton("0.01");
        if (toSend < ton("0.1")) {
            let str: StringBuilder = beginString();
            str.append("Error! Current transfer amount: ");
            str.append(toSend.toCoinsString());
            str.append(" TON, minimum 0.1 TON");

            self.errorMessage(str.toString());
            return;
        }

        let totalCoins: Int = (self.buyAssetAmount * nanoTons * milliTons) / msg.itemPriceMilli;
        if (totalCoins <= 0) {
            self.errorMessage("There are no tokens available");
            return;
        }

        //
        if (self.vetoVoted) {
            self.errorMessage("Already voted");
            return;
        }

        //
        self.vetoVoted = true;

        //Send notification
        send(SendParameters{
            to: self.dexContract,
            value: toSend,
            mode: SendPayGasSeparately,
            body: DAOVetoVoteRequestAnswer{
                queryId: msg.queryId,
                totalCoins: totalCoins,
                storageState: self.state(),
                comment: msg.comment
            }.toCell()
        });
    }
}