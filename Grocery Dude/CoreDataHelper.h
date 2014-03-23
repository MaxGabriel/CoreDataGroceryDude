//
//  CoreDataHelper.h
//  Grocery Dude
//
//  Created by Maximilian Tagher on 3/22/14.
//  Copyright (c) 2014 Tim Roadley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
@class MigrationVC;

@interface CoreDataHelper : NSObject

@property (nonatomic, strong) MigrationVC *migrationVC;

@property (nonatomic, readonly) NSManagedObjectContext *context;
@property (nonatomic, readonly) NSManagedObjectModel *model;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, readonly) NSPersistentStore *store;

- (void)setupCoreData;

- (void)saveContext;

@end
