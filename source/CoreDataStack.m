/**
 CoreDataStack - CoreData made easy
 
 c.f. https://github.com/adamgit/CoreDataStack for docs + support
 */

#import "CoreDataStack.h"

@interface CoreDataStack()
+ (NSURL *)applicationDocumentsDirectory;
@property(nonatomic,assign,readwrite) NSThread* threadThatOwnsThisStack;
@end

@implementation CoreDataStack

#pragma mark - @synthesize for old Xcode versions (pre Xcode 4.4)

@synthesize databaseURL;
@synthesize modelName;
@synthesize coreDataStoreType;
@synthesize automaticallyMigratePreviousCoreData;

#pragma mark - main class

+(NSString*) sharedNameForModelName:(NSString*) mname dbName:(NSString*) dbname
{
	return [NSString stringWithFormat:@"%@+%@", mname, dbname];
}

#pragma mark - Initializers / Constructors

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
		
		[self addObserver:self forKeyPath:@"managedObjectContextConcurrencyType" options:0 context:nil];
    }
    return self;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"managedObjectContextConcurrencyType" context:nil];
	
    self.threadThatOwnsThisStack = nil;
	self.databaseURL = nil;
	self.modelName = nil;
	
    [super dealloc];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if( [@"managedObjectContextConcurrencyType" isEqualToString:keyPath])
	{
		NSAssert( _moc == nil, @"You cannot change the managedObjectContextConcurrencyType after you've started using the stack (you've already read the value of .managedObjectContext, I'm afraid) - that's going to make your app source code confused and broken and chaos");
	}
}

#pragma mark - Apple core objects / references

-(NSManagedObjectModel*) dataModel
{
	if( _mom == nil )
	{
		NSString* momdPath = [[NSBundle mainBundle]pathForResource:self.modelName ofType:@"momd"];
		NSURL* momdURL = nil;
		
		/**
		 New feature: WHEREVER your MOMD file is hiding, we'll find it!
		 
		 Problem: When you embed a CoreData project (e.g. a static library) inside another project (e.g. your app),
		 Apple has banned us all from using Frameworks (even though Apple prefers us to write frameworks on OS X,
		 they disabled them from Xcode when making iOS apps).
		 
		 You're supposed to attach multiple NSBundle's to your app - one for each
		 subproject.
		 
		 This is great, but ... Apple provides no method to "search ALL bundles to find a file", they only provide
		 a method to "search the top-level bundle AND IGNORE THE SUB-BUNDLES".
		 
		 So, if we fail to find the MOMD we're looking for, we'll look at each sub-bundle we find, and go looking in 
		 them for it.
		 */
#define DEBUG_RECURSIVE_BUNDLE_SEARCHING 0
		if( momdPath == nil )
		{
#if DEBUG_RECURSIVE_BUNDLE_SEARCHING
			NSLog(@"[%@] WARN: Apple MOMD file was missing from main bundle. Now searching sub-bundles (1 level deep) to find it...", [self class]);
#endif
			
			NSArray* allAppBundles = [NSBundle allBundles];
#if DEBUG_RECURSIVE_BUNDLE_SEARCHING
			NSLog( @"[%@] ... found %i potential app bundles that might contain it", [self class], allAppBundles.count);
#endif
			for(  NSBundle* appBundle in allAppBundles )
			{
				momdURL = [appBundle URLForResource:self.modelName withExtension:@"momd" subdirectory:nil];
				
				if( momdURL == nil ) // not found, so check the bundle for sub-bundles
				{
					for( NSURL* subURL in [appBundle URLsForResourcesWithExtension:@"bundle" subdirectory:nil])
					{
						NSBundle* subBundle = [NSBundle bundleWithURL:subURL];
						momdURL = [subBundle URLForResource:self.modelName withExtension:@"momd" subdirectory:nil];
						if( momdURL != nil )
						{
							break;
						}
					}
				}
				
				if( momdURL != nil )
				{
					break;
				}
			}
			
			NSAssert( momdURL != nil, @"Failed to find the momd file for incoming modelName = %@. Maybe you forgot to convert your MOM to a MOMD? (Xcode major bug: used to do this automatically, now it doesn't)", self.modelName );
		}
		else
			momdURL = [NSURL fileURLWithPath:momdPath];
		
		_mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momdURL];
	}
	
	return _mom;
}

-(NSEntityDescription*) entityForClass:(Class) entityClass
{
	NSEntityDescription* result = [NSEntityDescription entityForName:NSStringFromClass(entityClass) inManagedObjectContext:self.managedObjectContext];
	
	return result;
}

-(NSManagedObject*) insertInstanceOfClass:(Class) entityClass
{
	NSManagedObject* newObject = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(entityClass) inManagedObjectContext:self.managedObjectContext];
	
	return newObject;
}

/**
 Returns the URL to the application's Documents directory. Used by Apple's reference code for finding the CoreData persistent files
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
				storeType = NSSQLiteStoreType;
				NSLog(@"[%@] ERROR: impossible store type. This type only exists on OS X. Using SqlLite instead ... %@", [self class], storeType );
#endif
				
			}break;
				
			case CDSStoreTypeBinary:
			{
				storeType = NSBinaryStoreType;
			}break;
				
			case CDSStoreTypeUnknown:
			{
				storeType = NSSQLiteStoreType;
				NSLog(@"[%@] WARN: unknown store type. Guessing ... %@", [self class], storeType );
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
					   [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
					   [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
		}
		else
			NSLog(@"[%@] Warning: not migrating store (Apple default, but it's incorrect for 99%% of projects)", [self class]);
		
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

/**
 NB: all internal methods route via this method; this way, we can centrally check that you're not
 doing dangerous multi-threaded CoreData, and Assert if we catch you doing it
 
 NB: We "Assert" in this method because it is ALWAYS WRONG to do multi-threaded access against CoreData
 (apart from niche uses that are so specialized - and so hard to get right - that you won't see them
 on normal app projects)
 */
-(NSManagedObjectContext*) managedObjectContext
{
	if( _moc == nil )
	{
		_moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:self.managedObjectContextConcurrencyType];
		[_moc setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
		
		NSLog(@"[%@] Info: Created a new NSManagedObjectContext (if you weren't expecting this, this could be fatal to your app", [self class] );
	}
	
	if( self.threadThatOwnsThisStack == nil )
	{
		self.threadThatOwnsThisStack = [NSThread currentThread];
	}
	else
	{
		NSAssert( self.threadThatOwnsThisStack == [NSThread currentThread], @"FATAL ERROR: Apple's CoreData code is very UNSAFE with multithreading; you tried to access CoreData from thread = %@, but this stack was initialized by thread = %@. According to Apple, only the thread that initializes a ManagedObjectContext is allowed to read from or write to it", [NSThread currentThread], self.threadThatOwnsThisStack );
	}
	
	return _moc;
}

#pragma mark - Convenience methods that can be implemented generically on top of any coredata stack

-(NSFetchRequest*) fetchRequestForEntity:(Class) c
{
	return [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(c)];
}

-(NSManagedObject*) fetchOneOrNil:(Class) c predicate:(NSPredicate*) predicate error:(NSError**) error
{
	NSFetchRequest* fetch = [self fetchRequestForEntity:c];
	fetch.predicate = predicate;
	NSArray* result = [self.managedObjectContext executeFetchRequest:fetch error:error];
	
	if( result == nil )
	{
		return nil;
	}
	else if( result.count != 1 )
	{
		if( error != nil )
			*error = nil; // not an error, but wrong number of matches
		return nil;
	}
	else
	{
		if( error != nil )
			*error = nil;
		return [result objectAtIndex:0];
	}
}

-(BOOL) storeContainsAtLeastOneEntityOfClass:(Class) c
{
	NSFetchRequest* fetchAny = [self fetchRequestForEntity:c];
	NSArray* anyCats = [self.managedObjectContext executeFetchRequest:fetchAny error:nil];
	
	if( [anyCats count] > 0 )
		return TRUE;
	
	return FALSE;
}

-(NSArray*) fetchEntities:(Class) c matchingPredicate:(NSPredicate*) predicate
{
	return [self fetchEntities:c matchingPredicate:predicate sortedByDescriptors:nil];
}

-(NSArray*) fetchEntities:(Class) c matchingPredicate:(NSPredicate*) predicate sortedByDescriptors:(NSArray*) sortDescriptors
{
	NSFetchRequest* fetch = [self fetchRequestForEntity:c];
	if( predicate != nil )
		fetch.predicate = predicate;
	if( sortDescriptors != nil )
		fetch.sortDescriptors = sortDescriptors;
	NSError* error;
	NSArray* result = [self.managedObjectContext executeFetchRequest:fetch error:&error];
	
	if( result == nil )
	{
		NSLog(@"[%@] ERROR calling fetchEntities:matchingPredicate for predicate %@, error = %@", [self class], predicate, error );
		return nil;
	}
	else
		return result;
}

-(int) countEntities:(Class) c matchingPredicate:(NSPredicate*) predicate
{
	NSFetchRequest* fetch = [self fetchRequestForEntity:c];
	fetch.predicate = predicate;
	NSError* error;
	NSArray* result = [self.managedObjectContext executeFetchRequest:fetch error:&error];
	
	if( result == nil )
	{
		NSLog(@"[%@] ERROR calling countEntities:matchingPredicate for predicate %@, error = %@", [self class], predicate, error );
		return -1;
	}
	else
		return result.count;
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
			
			if( self.shouldAssertWhenSaveFails )
				NSAssert( FALSE, @"A CoreData save failed, and you asked me to Assert when this happens. This is a very serious error - you should investigate!");
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
