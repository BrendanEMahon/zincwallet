//
//  ZNPaymentRequest.m
//  ZincWallet
//
//  Created by Aaron Voisine on 5/9/13.
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

#import "ZNPaymentRequest.h"
#import "ZNPaymentProtocol.h"
#import "NSString+Base58.h"

// BIP21 bitcoin URI object https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki
@implementation ZNPaymentRequest

//TODO: support for BIP70 payment protocol
+ (instancetype)requestWithString:(NSString *)string
{
    return [[self alloc] initWithString:string];
}

+ (instancetype)requestWithURL:(NSURL *)url
{
    return [[self alloc] initWithURL:url];
}

+ (instancetype)requestWithData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithString:(NSString *)string
{
    return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (instancetype)initWithURL:(NSURL *)url
{
    return [self initWithData:[url.absoluteString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (instancetype)initWithData:(NSData *)data
{
    if (! (self = [self init])) return nil;

    self.data = data;
    
    return self;
}

- (void)setData:(NSData *)data
{
    self.paymentAddress = nil;
    self.label = nil;
    self.message = nil;
    self.amount = 0;

    if (! data) return;

    // stringByAddingPercentEscapesUsingEncoding: only encodes characters that would otherwise make the URL illegal so
    // it doesn't result in double encoding
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                  // stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:s];
    
    if (! url || ! url.scheme) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"bitcoin://%@", s]];
    }
    else if (! url.host && url.resourceSpecifier) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", url.scheme, url.resourceSpecifier]];
    }
    
    self.paymentAddress = url.host;
    
    //TODO: correctly handle unkown but required url arguments (by reporting the request invalid)
    for (NSString *arg in [url.query componentsSeparatedByString:@"&"]) {
        NSArray *pair = [arg componentsSeparatedByString:@"="];

        if (pair.count != 2) continue;
        
        if ([pair[0] isEqual:@"amount"]) {
            self.amount = ([pair[1] doubleValue] + DBL_EPSILON)*SATOSHIS;
        }
        else if ([pair[0] isEqual:@"label"]) {
            self.label = [[pair[1] stringByReplacingOccurrencesOfString:@"+" withString:@"%20"]
                          stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        else if ([pair[0] isEqual:@"message"]) {
            self.message = [[pair[1] stringByReplacingOccurrencesOfString:@"+" withString:@"%20"]
                            stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
        else if ([pair[0] isEqual:@"r"]) {
            self.r = [[pair[1] stringByReplacingOccurrencesOfString:@"+" withString:@"%20"]
                      stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
}

- (NSData *)data
{
    if (! self.paymentAddress) return nil;

    NSMutableString *s = [NSMutableString stringWithFormat:@"bitcoin:%@", self.paymentAddress];
    NSMutableArray *q = [NSMutableArray array];
    
    if (self.amount > 0) {
        [q addObject:[NSString stringWithFormat:@"amount=%.16g", (double)self.amount/SATOSHIS]];
    }
    
    if (self.label.length > 0) {
        [q addObject:[NSString stringWithFormat:@"label=%@",
         [self.label stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    }
    
    if (self.message.length > 0) {
        [q addObject:[NSString stringWithFormat:@"message=%@",
         [self.message stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    }

    if (self.r.length > 0) {
        [q addObject:[NSString stringWithFormat:@"r=%@",
         [self.r stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    }
    
    if (q.count > 0) {
        [s appendString:@"?"];
        [s appendString:[q componentsJoinedByString:@"&"]];
    }
    
    return [s dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)isValid
{
    if (! [self.paymentAddress isValidBitcoinAddress] && (! self.r || ! [NSURL URLWithString:self.r])) return NO;
    
    // TODO: validate bitcoin payment request X.509 certificate, hopefully offline

    return YES;
}

// fetches the request over HTTP and calls completion block
+ (void)fetch:(NSString *)url completion:(void (^)(ZNPaymentProtocolRequest *req, NSError *error))completion
{
    if (! completion) return;

    NSURL *u = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

    if (! u) {
        completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                         userInfo:@{NSLocalizedDescriptionKey:@"bad payment request URL"}]);
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u
                                cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];

    [req addValue:@"application/bitcoin-paymentrequest" forHTTPHeaderField:@"Accept"];

    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue currentQueue]
    completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (! [response.MIMEType.lowercaseString isEqual:@"application/bitcoin-paymentrequest"] || data.length > 50000){
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"unexpected response from payment server"}]);
            return;
        }

        ZNPaymentProtocolRequest *req = [ZNPaymentProtocolRequest requestWithData:data];

        if (! req) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"unexpected response from payment server"}]);
            return;
        }

        completion(req, nil);
    }];
}

+ (void)postPayment:(ZNPaymentProtocolPayment *)payment to:(NSString *)paymentURL
completion:(void (^)(ZNPaymentProtocolACK *ack, NSError *error))completion
{
    NSURL *url = [NSURL URLWithString:paymentURL];

    if (! url || [url.scheme isEqual:@"http"]) { // must be https rather than http
        completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                         userInfo:@{NSLocalizedDescriptionKey:@"bad payment URL"}]);
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0];

    [req addValue:@"application/bitcoin-payment" forHTTPHeaderField:@"Content-Type"];
    [req addValue:@"application/bitcoin-paymentack" forHTTPHeaderField:@"Accept"];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:payment.data];

    [NSURLConnection sendAsynchronousRequest:req queue:[NSOperationQueue currentQueue]
    completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (! [response.MIMEType.lowercaseString isEqual:@"application/bitcoin-paymentack"] || data.length > 50000) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"unexpected response from payment server"}]);
            return;
        }

        ZNPaymentProtocolACK *ack = [ZNPaymentProtocolACK ackWithData:data];
        
        if (! ack) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"unexpected response from payment server"}]);
            return;
        }
        
        completion(ack, nil);
     }];
}

@end
