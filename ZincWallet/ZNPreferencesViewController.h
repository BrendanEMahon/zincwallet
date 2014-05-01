//
//  ZNPreferencesViewController.h
//  ZincWallet
//
//  Created by Brendan Mahon on 4/24/14.
//  Copyright (c) 2014 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ZNPreferencesViewController : UITableViewController<UIAlertViewDelegate, UINavigationControllerDelegate> {
    IBOutlet UISegmentedControl *bitcoinSymbol;
}

-(void)changeBitcoinSymbol:(id)sender;
-(void)changeBitcoinDenomination:(id)sender;
-(void)changeTestEnvironment:(id)sender;

@end
