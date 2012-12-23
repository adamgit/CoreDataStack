/**
 CoreDataStack - CoreData made easy
 
 c.f. https://github.com/adamgit/CoreDataStack for docs + support
 */

#import "CoreDataStack.h"

@interface CoreDataStack()
+ (NSURL *)applicationDocumentsDirectory;
@end

@implementation CoreDataStack

@synthesize databaseURL;
@synthesize modelName;
@synthesize coreDataStoreType;
@synthesize automaticallyMigratePreviousCoreData;

+(NSString*) sharedNameForModelName:(NSString*) mname dbName:(NSString*) dbname
{
	return [NSString stringWithFormat:@"%@+%@", mname, dbname];
}

+(CoreDataStack*) coreDataStackWithSharedModelName:(NSString *)mname databaseFilename:(NSString*) dbname
{
	static NSMutableDictionary* sharedModelsByNameANdDBName;
	
	if( sharedModelsByNameANdDBName == nil )
	{
		sharedModelsByNameANdDBName = [NSMutableDictionary new];
	}
	
	CoreDataStack* sharedStack = [sharedModelsByNameANdDBName objectForKey:[self sharedNameForModelName:mname dbName:dbname]];
	if( sharedStack == nil )
	{
		sharedStack = [self coreDataStackWithModelName:mname databaseFilename:dbname];
		[sharedModelsByNameANdDBName setObject:sharedStack forKey:[self sharedNameForModelName:mname dbName:dbname]];
	}
	
	return sharedStack;
}

+(CoreDataStack*) coreDataStackWithModelName:(NSString *)mname databaseFilename:(NSString*) dbname
{
	NSURL *storeURL;
	
	if( dbname != nil )
		storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:dbname];
	else
		storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:mname];
	
	CoreDataStack* cds = [[[CoreDataStack alloc] initWithURL: storeURL
												   modelName: mname
												   storeType: CDSStoreTypeUnknown] autorelease];
	
	return cds;
}

+(CoreDataStack*) coreDataStackWithModelName:(NSString *)mname
{
	return [self coreDataStackWithModelName:mname databaseFilename:nil];
}

+(CoreDataStack*) coreDataStackWithDatabaseURL:(NSURL*) dburl modelName:(NSString *)mname
{	
	CoreDataStack* cds = [[[CoreDataStack alloc] initWithURL:dburl modelName:mname storeType:CDSStoreTypeUnknown] autorelease];
	
	return cds;
}

-(void) guessStoreType:(NSString*) fileExtension
{
	if( fileExtension != nil && [fileExtension length] > 0)
	{
		/** Guess the Store Type */
		if( [@"BINARY" isEqualToString:[fileExtension uppercaseString]] )
		{
			self.coreDataStoreType = CDSStoreTypeBinary;
		}
		else if( [@"XML" isEqualToString:[fileExtension uppercaseString]] )
		{
			self.coreDataStoreType = CDSStoreTypeXML;
		}
		else if( [@"SQL" isEqualToString:[fileExtension uppercaseString]] )
		{
			self.coreDataStoreType = CDSStoreTypeSQL;
		}
		else if( [@"SQLITE" isEqualToString:[fileExtension uppercaseString]] )
		{
			self.coreDataStoreType = CDSStoreTypeSQL;
		}
		else
			NSLog(@"[%@] WARN: no explicit store type given, and could NOT guess the store type. Core Data will PROBABLY refuse to initialize!", [self class] );
	}
}

- (id)initWithURL:(NSURL*) url modelName:(NSString *)mname storeType:(CDSStoreType) type
{
    self = [super init];
    if (self) {
        self.databaseURL = url;
		self.modelName = mname;
		self.coreDataStoreType = type;
		self.automaticallyMigratePreviousCoreData = TRUE;
		
		if( self.coreDataStoreType == CDSStoreTypeUnknown )
		{
			[self guessStoreType:[self.databaseURL pathExtension]];
		}
    }
    return self;
}

-(NSManagedObjectModel*) dataModel
{
	if( _mom == nil )
	{
		NSString* momdPath = [[NSBundle mainBundle] pathForResource:self.modelName ofType:@"momd"];
		NSURL* momdURL = [NSURL fileURLWithPath:momdPath];
		
		_mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momdURL];
	}
	
	return _mom;
}

-(NSEntityDescription*) entityForClass:(Class) entityClass
{
	NSEntityDescription* result = [NSEntityDescription entityForName:NSStringFromClass(entityClass) inManagedObjectContext:self.managedObjectContext];
	
	return result;
}

/**
 Returns the URL to the application's Documents directory.
 */
+ (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

-(NSPersistentStoreCoordinator*) persistentStoreCoordinator
{
	if( _psc == nil )
	{
		NSAssert( self.databaseURL != nil, @"This class should have been init'd with a URL, or with enough info to construct a valid URL" );
		NSError *error = nil;
		_psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self dataModel]];
		
		NSString* storeType;
		switch( self.coreDataStoreType )
		{
			case CDSStoreTypeXML:
			{
#ifdef NSXMLStoreType
				storeType = NSXMLStoreType;
#else
				NSAssert( FALSE, @"Apple does not allow you to use an XML store on this OS. Only available on OS X" );
#endif
					
			}break;
				
			case CDSStoreTypeBinary:
			{
				storeType = NSBinaryStoreType;
			}break;
				
			case CDSStoreTypeUnknown:
			{
				storeType = NSSQLiteStoreType;
				NSLog(@"[%@] WARN: unknown store type. Guessing ... %@ ??", [self class], storeType );
			}break;
				
			case CDSStoreTypeSQL:
			{
				storeType = NSSQLiteStoreType;
			}break;
				
			case CDSStoreTypeInMemory:
			{
				storeType = NSInMemoryStoreType;
			}break;
		}
		
		NSDictionary *options = nil;
		
		if( self.automaticallyMigratePreviousCoreData )
		{
			options = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES],NSMigratePersistentStoresAutomaticallyOption,
								 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
		}
			
		if (![_psc addPersistentStoreWithType:storeType configuration:nil URL:self.databaseURL options:options error:&error]) {
			/*
			 Replace this implementation with code to handle the error appropriately.			 
			 */
			NSLog(@"[%@] Unresolved error %@, %@", [self class], error, [error userInfo]);
			abort();
		}
	}
	
	return _psc;
}

-(NSManagedObjectContext*) managedObjectContext
{
	if( _moc == nil )
	{
		_moc = [[NSManagedObjectContext alloc] init];
		[_moc setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
	}
	
	return _moc;
}

#pragma mark - Convenience methods that can be implemented generically on top of any coredata stack

-(BOOL) storeContainsAtLeastOneEntityOfClass:(Class) c
{
	NSFetchRequest* fetchAny = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(c)];
	NSArray* anyCats = [self.managedObjectContext executeFetchRequest:fetchAny error:nil];
	
	if( [anyCats count] > 0 )
		return TRUE;
	
	return FALSE;
}

-(void) saveOrFail:(void(^)(NSError* errorOrNil)) blockFailedToSave
{
	NSError* error = nil;
	if( [[self managedObjectContext] save:&error] )
	{
		return;
	}
	else
	{
		if( [self managedObjectContext] == nil )
		{
			blockFailedToSave( [NSError errorWithDomain:@"CoreDataStack" code:1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Attempted to save a nil NSManagedObjectContext. This CoreDataStack has no context - probably there was an earlier error trying to access the CoreData database file", NSLocalizedDescriptionKey, nil]] );
		}
		else
		{
			blockFailedToSave( error );
		}
	}
}

-(void) wipeAllData
{
	for( NSPersistentStore* store in [self.persistentStoreCoordinator persistentStores] )
	{
		NSError *error;
		NSURL *storeURL = store.URL;
		[self.persistentStoreCoordinator removePersistentStore:store error:&error];
		[[NSFileManager defaultManager] removeItemAtPath:storeURL.path error:&error];
		_moc = nil;
		_mom = nil;
		_psc = nil;
		
		/** ... side effect: all NSFetchedResultsController's will now explode because Apple didn't code them very well */
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDestroyAllNSFetchedResultsControllers object:self];
	}
}

@end
