//
//  ZNPreferencesViewController.m
//  ZincWallet
//
//  Created by Brendan Mahon on 4/24/14.
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

#import "ZNPreferencesViewController.h"
#import "ZNWalletManager.h"
#import "ZNWallet.h"
#import "ZNStoryboardSegue.h"
#import <QuartzCore/QuartzCore.h>

#define TRANSACTION_CELL_HEIGHT 75

@interface ZNPreferencesViewController ()

@property (nonatomic, strong) UIImageView *wallpaper;
@property (nonatomic, assign) CGPoint wallpaperStart;

@property (nonatomic, strong) id resignActiveObserver;

@end

@implementation ZNPreferencesViewController

//TODO: need settings for denomination (BTC, mBTC or uBTC), local currency, and exchange rate source
//TODO: only show most recent 10-20 transactions and have a separate page for the rest with section headers for each day
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.wallpaper.hidden = (self.navigationController.viewControllers.firstObject != self) ? YES : NO;
    
    self.resignActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
    if (self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:NO];
    }
    }];
}

- (void)dealloc
{
    if (self.resignActiveObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.resignActiveObserver];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"View: X:%f Y:%f W:%f H:%f",self.view.bounds.origin.x,self.view.bounds.origin.y,self.view.bounds.size.width,self.view.bounds.size.height);
    NSLog(@"TableView: X:%f Y:%f W:%f H:%f",self.tableView.bounds.origin.x,self.tableView.bounds.origin.y,self.tableView.bounds.size.width,self.tableView.bounds.size.height);

}


- (void)setBackgroundForCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)path
{
    if (! cell.backgroundView) {
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cell.frame.size.width, 0.5)];
        
        v.tag = 100;
        cell.backgroundView = [[UIView alloc] initWithFrame:cell.frame];
        cell.backgroundView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.67];
        v.backgroundColor = self.tableView.separatorColor;
        [cell.backgroundView addSubview:v];
        v = [[UIView alloc] initWithFrame:CGRectMake(0, cell.frame.size.height - 0.5, cell.frame.size.width, 0.5)];
        v.tag = 101;
        v.backgroundColor = self.tableView.separatorColor;
        [cell.backgroundView addSubview:v];
    }
    
    [cell viewWithTag:100].frame = CGRectMake(path.row == 0 ? 0 : 15, 0, cell.frame.size.width, 0.5);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:self.tableView numberOfRowsInSection:path.section]);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0: return 2;
        case 1: return 1;
        default: NSAssert(FALSE, @"%s:%d %s: unkown section %d", __FILE__, __LINE__,  __func__, (int)section);
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *preferencesIdent = @"ZNPreferencesCell";
    UITableViewCell *cell = nil;
    UILabel *textLabel;
    UISegmentedControl *segmentedControl;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    cell = [tableView dequeueReusableCellWithIdentifier:preferencesIdent];
    [self setBackgroundForCell:cell atIndexPath:indexPath];
    
    textLabel = (id)[cell viewWithTag:1];
    segmentedControl = (id)[cell viewWithTag:2];
    
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    textLabel.text = @"symbol";

                    if([[defaults objectForKey:@"bitcoinSymbol"] isEqualToString:@"\xC9\x83"]){
                        segmentedControl.selectedSegmentIndex = 0;
                    }
                    if([[defaults objectForKey:@"bitcoinSymbol"] isEqualToString:@"\xE0\xB8\xBF"]){
                        segmentedControl.selectedSegmentIndex = 1;
                    }
                    
                    [segmentedControl setTitle:@"\xC9\x83" forSegmentAtIndex:0];
                    [segmentedControl setTitle:@"\xE0\xB8\xBF" forSegmentAtIndex:1];
                    [segmentedControl addTarget:self action:@selector(changeBitcoinSymbol:) forControlEvents:UIControlEventValueChanged];
                    break;
                    
                case 1:
                    textLabel.text = @"denomination";
                    
                    [segmentedControl setFrame:CGRectMake(165, segmentedControl.frame.origin.y, 135, segmentedControl.frame.size.height)];
                    
                    [segmentedControl setTitle:@"BTC" forSegmentAtIndex:0];
                    [segmentedControl setTitle:@"mBTC" forSegmentAtIndex:1];
                    if (!(segmentedControl.numberOfSegments == 3)) {
                        [segmentedControl insertSegmentWithTitle:@"µBTC" atIndex:2 animated:NO];
                    }
                    [segmentedControl addTarget:self action:@selector(changeBitcoinDenomination:) forControlEvents:UIControlEventValueChanged];
                    
                    if([[defaults objectForKey:@"bitcoinDenomination"] isEqualToString:@""]){
                        segmentedControl.selectedSegmentIndex = 0;
                    }
                    if([[defaults objectForKey:@"bitcoinDenomination"] isEqualToString:@"m"]){
                        segmentedControl.selectedSegmentIndex = 1;
                    }
                    if([[defaults objectForKey:@"bitcoinDenomination"] isEqualToString:@"µ"]){
                        segmentedControl.selectedSegmentIndex = 2;
                    }
                    break;
                    
                default:
                    NSAssert(FALSE, @"%s:%d %s: unknown indexPath.row %d", __FILE__, __LINE__,  __func__,
                             (int)indexPath.row);
            }
            break;
        case 1:
            switch (indexPath.row) {
                case 0:
                    textLabel.text = @"test environment";
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"testnet"]) {
                        segmentedControl.selectedSegmentIndex = 0;
                    }
                    else {
                        segmentedControl.selectedSegmentIndex = 1;
                    }
                    
                    [segmentedControl setTitle:@"test" forSegmentAtIndex:0];
                    [segmentedControl setTitle:@"main" forSegmentAtIndex:1];
                    [segmentedControl addTarget:self action:@selector(changeTestEnvironment:) forControlEvents:UIControlEventValueChanged];
                    break;
                    
                default:
                    NSAssert(FALSE, @"%s:%d %s: unknown indexPath.row %d", __FILE__, __LINE__,  __func__,
                             (int)indexPath.row);
            }
            break;
        default:
            NSAssert(FALSE, @"%s:%d %s: unknown indexPath.section %d", __FILE__, __LINE__,  __func__,
                     (int)indexPath.section);
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"visual preferences";
        case 1: return @"developer (Non-Functional)";
        default: NSAssert(FALSE, @"%s:%d %s: unknown section %d", __FILE__, __LINE__,  __func__, (int)section);
    }
    
    return nil;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
            return TRANSACTION_CELL_HEIGHT;
        case 1:
            return TRANSACTION_CELL_HEIGHT;
            
        default:
            NSAssert(FALSE, @"%s:%d %s: unknown indexPath.section %d", __FILE__, __LINE__,  __func__,
                     (int)indexPath.section);
    }
    
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    CGFloat h = 0;
    
    switch (section) {
        case 0:
            return 22;
            
        case 1:
            h = tableView.frame.size.height - self.navigationController.navigationBar.frame.size.height - 20.0 - 44.0 - 64.0 - 22.0;
            
            for (int s = 0; s < section; s++) {
                h -= [self tableView:tableView heightForHeaderInSection:s];
                
                for (int r = 0; r < [self tableView:tableView numberOfRowsInSection:s]; r++) {
                    h -= [self tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:s]];
                }
            }
            
            return h > 22 ? h : 22;
            
        default:
            NSAssert(FALSE, @"%s:%d %s: unkown section %d", __FILE__, __LINE__,  __func__, (int)section);
    }
    
    return 22;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForHeaderInSection:section])];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(10, v.frame.size.height - 22.0,
                                                           self.view.frame.size.width - 20, 22.0)];
    
    l.text = [self tableView:tableView titleForHeaderInSection:section];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont fontWithName:@"HelveticaNeue" size:15];
    l.textColor = [UIColor grayColor];
    l.shadowColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    l.shadowOffset = CGSizeMake(0.0, 1.0);
    v.backgroundColor = [UIColor clearColor];
    [v addSubview:l];
    
    return v;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0:
                    NSLog(@"1");
                    break;
                case 1:
                    NSLog(@"2");
                    break;
                default:
                    NSAssert(FALSE, @"%s:%d %s: unknown indexPath.section %d", __FILE__, __LINE__,  __func__,
                             (int)indexPath.row);
            }
            
        default:
            NSAssert(FALSE, @"%s:%d %s: unknown indexPath.section %d", __FILE__, __LINE__,  __func__,
                     (int)indexPath.section);
    }
     */
}


#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (! animated) return;
    
    [UIView animateWithDuration:SEGUE_DURATION animations:^{
        if (viewController != self) {
            self.wallpaper.center = CGPointMake(self.wallpaperStart.x - self.view.frame.size.width*PARALAX_RATIO,
                                                self.wallpaperStart.y);
        }
        else self.wallpaper.center = self.wallpaperStart;
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }

}

-(void)changeBitcoinSymbol:(id)sender {
   
    UISegmentedControl *segmentedControl = (UISegmentedControl*)sender;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if(segmentedControl.selectedSegmentIndex == 0){
        [defaults setObject:@"\xC9\x83" forKey:@"bitcoinSymbol"]; // capital B with stroke (utf-8)
	}
	if(segmentedControl.selectedSegmentIndex == 1){
        [defaults setObject:@"\xE0\xB8\xBF" forKey:@"bitcoinSymbol"]; // capital B with vertical line (utf-8)
    }

    [defaults synchronize];
}

-(void)changeBitcoinDenomination:(id)sender {

    UISegmentedControl *segmentedControl = (UISegmentedControl*)sender;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
	if(segmentedControl.selectedSegmentIndex == 0){
        [defaults setObject:@"" forKey:@"bitcoinDenomination"]; // BTC
        NSLog(@"BTC");
	}
	if(segmentedControl.selectedSegmentIndex == 1){
        [defaults setObject:@"m" forKey:@"bitcoinDenomination"]; // mBTC
        NSLog(@"mBTC");
    }
    if(segmentedControl.selectedSegmentIndex == 2){
        [defaults setObject:@"µ" forKey:@"bitcoinDenomination"]; // uBTC
        NSLog(@"µBTC");
    }
    
    [defaults synchronize];
}

-(void)changeTestEnvironment:(id)sender {
    
    UISegmentedControl *segmentedControl = (UISegmentedControl*)sender;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
	if(segmentedControl.selectedSegmentIndex == 0){
        [defaults setBool:1 forKey:@"testnet"]; //testnet
        NSLog(@"testnet");
	}
	if(segmentedControl.selectedSegmentIndex == 1){
        [defaults setBool:1 forKey:@"mainnet"]; //mainnet
        NSLog(@"mainnet");
    }
    
    [defaults synchronize];
}


@end
