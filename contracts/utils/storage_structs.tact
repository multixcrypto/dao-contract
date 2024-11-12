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

import "./farm_structs.tact";

struct StorageStateMessage {
  dexContract: Address;
  clientAddress: Address;
  saleIndex: Int as uint64;

  buyCount: Int as uint64;                //Number of sales transactions
  buyAssetAmount: Int as coins;           //Total amount purchased

  claimedTONAmount: Int as coins;
  claimedTokens: Int as coins;
  claimedCount: Int as uint64;

  vetoVoted: Bool;
}

/*
 * Parameters for blocking any assets in the contract
 * Once unlockStartTime is reached, unlockPercent will be unlocked.
 * From the unlockStartTime date, the number of milliseconds that have passed is counted.
 * Then, the number of days is counted. The cyclePercent percentage is applied to this number of days.
*/
struct UnlockOptions {
    unlockStartTime: Int as uint64 = 0;         //TGE - Token Generation Event
    unlockPercentHecto: Int as uint16 = 0;      //TGE Percent - percentage of the locked amount to be unlocked on the TGE date
    
    cycleDaysOffsetA: Int as uint16 = 0;        //After how many days does percentage A begin to take effect
    cyclePercentHectoA: Int as uint16 = 0;      //Percentage A of the locked amount
    cyclesDaysA: Int as uint16 = 0;             //The vesting cycle duration in days

    cycleDaysOffsetB: Int as uint16 = 0;        //After how many days does percentage B begin to take effect
    cyclePercentHectoB: Int as uint16 = 0;      //Percentage B of the locked amount
    cyclesDaysB: Int as uint16 = 0;             //The vesting cycle duration in days

    cycleDaysOffsetC: Int as uint16 = 0;        //After how many days does percentage C begin to take effect
    cyclePercentHectoC: Int as uint16 = 0;      //Percentage C of the locked amount
    cyclesDaysC: Int as uint16 = 0;             //The vesting cycle duration in days

    cycleDaysOffsetD: Int as uint16 = 0;        //After how many days does percentage D begin to take effect
    cyclePercentHectoD: Int as uint16 = 0;      //Percentage D of the locked amount
    cyclesDaysD: Int as uint16 = 0;             //The vesting cycle duration in days
}

struct TransferMessage {
    opcode: Int as uint32 = 0xf8a7ea5;
    queryId: Int as uint64;
    jettonAmount: Int as coins;
    toAddress: Address;
    responseAddress: Address;
    customPayload: Bool = false;
    forwardAmount: Int as coins = 0;
    haveCommit: Bool = false;
}

struct TransferMessageWithPayload {
    opcode: Int as uint32 = 0xf8a7ea5;
    queryId: Int as uint64;
    jettonAmount: Int as coins;
    toAddress: Address;
    responseAddress: Address;
    customPayload: Bool = false;
    forwardAmount: Int as coins = 0;
    haveCommit: Bool = true;
    payload: Slice;
}

struct BurnMessage {
    opcode: Int as uint32 = 0x595f07bc;
    queryId: Int as uint64;
    jettonAmount: Int as coins;
    responseAddress: Address;
}
