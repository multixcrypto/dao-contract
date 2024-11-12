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

message(0x3775) BuyRequest {
  buyRequestID: Int as uint64;
  limitTotalAmount: Int as coins;
  comment: Slice as remaining;
}
message(0x3777) BuyRequestAnswer {
  successAnswer: Bool;
  errorCode: Int as uint16;
  buyRequestID: Int as uint64;

  realBuyAmount: Int as coins;

  storageState: StorageStateMessage;
  comment: Slice as remaining;
}

//
message(0x3888) ClaimRequestErrorAnswer {
  queryId: Int as uint64;
  storageState: StorageStateMessage;
  errorMessage: String;
}

//
message(0x3881) ClaimRequestFull {
  queryId: Int as uint64;
  contractTONBalance: Int as coins;
  comment: Slice as remaining;
}
message(0x3891) ClaimRequestFullAnswer {
  queryId: Int as uint64;
  availableAmount: Int as coins;

  storageState: StorageStateMessage;
  comment: Slice as remaining;
}

//
message(0x3883) ClaimRequestAsset {
  queryId: Int as uint64;
  salesFreeTokens: Int as coins;

  itemPriceMilli: Int as coins;
  unlockOptions: UnlockOptions;
  comment: Slice as remaining;
}
message(0x3893) ClaimRequestAssetAnswer {
  queryId: Int as uint64;
  availableTokens: Int as coins;

  storageState: StorageStateMessage;
  comment: Slice as remaining;
}

//
message(0x3993) DAOVetoVoteRequest {
  queryId: Int as uint64;
  itemPriceMilli: Int as coins;
  comment: Slice as remaining;
}

message(0x3995) DAOVetoVoteRequestAnswer {
  queryId: Int as uint64;
  totalCoins: Int as coins;

  storageState: StorageStateMessage;
  comment: Slice as remaining;
}