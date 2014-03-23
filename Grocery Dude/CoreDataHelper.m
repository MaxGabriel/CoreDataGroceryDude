//
//  CoreDataHelper.m
//  Grocery Dude
//
//  Created by Maximilian Tagher on 3/22/14.
//  Copyright (c) 2014 Tim Roadley. All rights reserved.
//

#import "CoreDataHelper.h"
#import "MigrationVC.h"

@implementation CoreDataHelper

#define debug 1

#pragma mark - Files
NSString *const storeFilename = @"Grocery-Dude.sqlite";



#pragma mark - Paths

- (NSString *)applicationDocumentsDirectory
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];;
}

- (NSURL *)applicationStoresDirectory {
    if (debug) {
        DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    }
    
    NSURL *storesDirectory = [[NSURL fileURLWithPath:[self applicationDocumentsDirectory]] URLByAppendingPathComponent:@"Stores"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:[storesDirectory path]]) {
        NSError *error;
        if ([fileManager createDirectoryAtURL:storesDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            DLog(@"<%@:%@:%d:\nCreate Stores Directory",[self class],NSStringFromSelector(_cmd),__LINE__);
        } else {
            DLog(@"<%@:%@:%d:\nFailed to create Stores directory",[self class],NSStringFromSelector(_cmd),__LINE__);
        }
    }
    return storesDirectory;
}

- (NSURL *)storeURL {
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    return [[self applicationStoresDirectory] URLByAppendingPathComponent:storeFilename];
}

#pragma mark - Setup

- (instancetype)init {
    self = [super init];
    if (self) {
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_context setPersistentStoreCoordinator:_coordinator];
    }
    return self;
}

- (void)loadStore
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    if (_store) {
        return;
    }
    
    BOOL useMigrationManager = NO;
    if (useMigrationManager && [self isMigrationNecessaryForStore:[self storeURL]]) {
        [self performBackgroundManagedMigrationForStore:[self storeURL]];
    } else {
        NSError *error;
        NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                  NSInferMappingModelAutomaticallyOption: @YES,
                                  NSSQLitePragmasOption: @{@"journal_mode": @"DELETE"}
                                  };
        _store =[_coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                           configuration:nil
                                                     URL:[self storeURL]
                                                 options:options
                                                   error:&error];
        if (!_store) {
            NSLog(@"Failed to create store, error = %@",error);
            abort();
        } else {
            DLog(@"<%@:%@:%d:\nAdded store",[self class],NSStringFromSelector(_cmd),__LINE__);
        }
    }
}

- (void)setupCoreData
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    [self loadStore];
}

#pragma mark - Saving

- (void)saveContext
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    if ([_context hasChanges]) {
        NSError *error;
        if ([_context save:&error]) {
            NSLog(@"_context SAVED changes to persistent store");
        } else {
            NSLog(@"Failed to save _context: %@",error);
        }
    } else {
        NSLog(@"Skipped _context save, there are no changes");
    }
}

#pragma mark - Migration Manager

- (BOOL)isMigrationNecessaryForStore:(NSURL *)storeUrl {
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self storeURL].path]) {
        NSLog(@"Skipped imgration: DB missing");
        return NO;
    }
    
    NSError *error;
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeUrl error:&error];
    NSManagedObjectModel *destinationModel = _coordinator.managedObjectModel;
    if ([destinationModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata]) {
        NSLog(@"Skipped migration—source is already compatible");
        return NO;
    }

    
    return YES;
}

- (BOOL)migrateStore:(NSURL *)sourceStore
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    BOOL success = NO;
    NSError *error;
    
    // Gather the source, destinating and mapping model
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                              URL:sourceStore
                                                                                            error:&error];
    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:nil
                                                                    forStoreMetadata:sourceMetadata];
    
    NSManagedObjectModel *destinModel = _model;
    
    NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:nil
                                                            forSourceModel:sourceModel
                                                          destinationModel:destinModel];
    
    // Step 2, perform migration, assuming the mapping model isn't null
    if (mappingModel) {
        NSError *error;
        NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinModel];
        [migrationManager addObserver:self
                           forKeyPath:@"migrationProgress"
                              options:NSKeyValueObservingOptionNew
                              context:NULL];
        NSURL *destinStore = [[self applicationStoresDirectory] URLByAppendingPathComponent:@"Temp.sqlite"];
        
        success = [migrationManager migrateStoreFromURL:sourceStore
                                                   type:NSSQLiteStoreType
                                                options:nil
                                       withMappingModel:mappingModel
                                       toDestinationURL:destinStore
                                        destinationType:NSSQLiteStoreType
                                     destinationOptions:nil
                                                  error:&error];
        
        if (success) {
            // Step 3, replace the odl sore with the new migrated store
            if ([self replaceStore:sourceStore withStore:destinStore]) {
                DLog(@"<%@:%@:%d:\nSUCCESSFULLY MIGRATED %@ to the current model",[self class],NSStringFromSelector(_cmd),__LINE__,sourceStore.path);
                [migrationManager removeObserver:self forKeyPath:@"migrationProgress"];
            }
        } else {
            NSLog(@"Failed migration: %@",error);
        }
    } else {
        NSLog(@"Failed migration: mapping model is nil");
    }
    return YES; // migration has finished, regardless of outcome.
}

- (BOOL)replaceStore:(NSURL *)old withStore:(NSURL *)new
{
    BOOL success = NO;
    NSError *error;
    if ([[NSFileManager defaultManager] removeItemAtURL:old error:&error]) {
        error = nil;
        if ([[NSFileManager defaultManager] moveItemAtURL:new toURL:old error:&error]) {
            success = YES;
        } else {
            DLog(@"<%@:%@:%d:\nFailed to re-home new store error = %@",[self class],NSStringFromSelector(_cmd),__LINE__,error);
        }
    } else {
        DLog(@"<%@:%@:%d:\nFailde to remove old store %@ error %@",[self class],NSStringFromSelector(_cmd),__LINE__,old,error);
    }
    return success;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"migrationProcess"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            float progress = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            int percentage = progress * 100;
            NSString *string = [NSString stringWithFormat:@"Migration Progress: %i%%",percentage];
            NSLog(@"%@",string);
            self.migrationVC.label.text = string;
        });
    }
}

- (void)performBackgroundManagedMigrationForStore:(NSURL *)storeURL
{
    DLog(@"<%@:%@:%d",[self class],NSStringFromSelector(_cmd),__LINE__);
    
    // Show migration process preventing using from using the app.
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.migrationVC = [sb instantiateViewControllerWithIdentifier:@"migration"];
    UIApplication *sa = [UIApplication sharedApplication];
    UINavigationController *nc = (UINavigationController *)sa.keyWindow.rootViewController;
    [nc presentViewController:self.migrationVC animated:NO completion:nil];
    
    // Perform migration in the background, so it doesn't freeze the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        BOOL done = [self migrateStore:storeURL];
        if (done) {
            // When migration finishes, add the newly migrated store
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error;
                _store = [_coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storeURL] options:nil error:&error];
                if (!_store) {
                    NSLog(@"Failed to add a migrated store. Error = %@",error);
                    abort();
                } else {
                    NSLog(@"Successfully added a migrated store %@",_store);
                }
                [self.migrationVC dismissViewControllerAnimated:NO completion:nil];
                self.migrationVC = nil;
            });
        }
    });
}

@end








