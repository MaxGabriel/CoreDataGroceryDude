//
//  AppDelegate.m
//  Grocery Dude
//
//  Created by Tim Roadley on 18/09/13.
//  Copyright (c) 2013 Tim Roadley. All rights reserved.
//

#import "AppDelegate.h"
#import "CoreDataHelper.h"
#import "Item.h"
#import "Unit.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self cdh];
    [self demo];
}

- (CoreDataHelper *)cdh {
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    if (!_coreDataHelper) {
        _coreDataHelper = [[CoreDataHelper alloc] init];
        [_coreDataHelper setupCoreData];
    }
    return _coreDataHelper;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[self cdh] saveContext];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[self cdh] saveContext];
}

- (void)demo
{
    
}

@end
