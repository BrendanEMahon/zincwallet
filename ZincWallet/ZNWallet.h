//
//  ZNWallet.h
//  ZincWallet
//
//  Created by Aaron Voisine on 5/12/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>

#define ZNWalletBalanceChangedNotification @"ZNWalletBalanceChangedNotification"

@class ZNTransaction;

@interface ZNWallet : NSObject

@property (nonatomic, readonly) uint64_t balance;
@property (nonatomic, readonly) NSString *receiveAddress; // returns the first unused external address
@property (nonatomic, readonly) NSString *changeAddress; // returns the first unused internal address
@property (nonatomic, readonly) NSSet *addresses; // all previously generated internal and external addresses
@property (nonatomic, readonly) NSArray *unspentOutputs; // NSData objects containing serialized UTXOs
@property (nonatomic, readonly) NSArray *recentTransactions; // ZNTransaction objects sorted by date, most recent first

- (instancetype)initWithContext:(NSManagedObjectContext *)context andSeed:(NSData *(^)())seed;

// true if the address is known to belong to the wallet
- (BOOL)containsAddress:(NSString *)address;

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)addressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
- (ZNTransaction *)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (ZNTransaction *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee;

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (BOOL)signTransaction:(ZNTransaction *)transaction;

// true if the given transaction is associated with the wallet, false otherwise
- (BOOL)containsTransaction:(ZNTransaction *)transaction;

// adds a transaction to the wallet, or returns false if it isn't associated with the wallet
- (BOOL)registerTransaction:(ZNTransaction *)transaction;

// removes a transaction from the wallet along with any transactions that depend on its outputs
- (void)removeTransaction:(NSData *)txHash;

// set the block heights for the given transactions
- (void)setBlockHeight:(int32_t)height forTxHashes:(NSArray *)txHashes;

// true if no previous wallet transaction spends any of the given transaction's inputs, and no input tx is invalid
- (BOOL)transactionIsValid:(ZNTransaction *)transaction;

// returns the amount received to the wallet by the transaction (total outputs to change and/or recieve addresses)
- (uint64_t)amountReceivedFromTransaction:(ZNTransaction *)transaction;

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(ZNTransaction *)transaction;

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(ZNTransaction *)transaction;

// returns the first non-change transaction output address, or nil if there aren't any
- (NSString *)addressForTransaction:(ZNTransaction *)transaction;

// returns the block height after which the transaction is likely to be processed without including a fee
- (uint32_t)blockHeightUntilFree:(ZNTransaction *)transaction;

@end