/**
 CoreDataStack - CoreData made easy
 
 c.f. https://github.com/adamgit/CoreDataStack for docs + support
 */

#import "CoreDataStack.h"

@implementation CoreDataStack

@synthesize databaseURL;
@synthesize databaseFilenameOrNil;
@synthesize coreDataStoreType;

static NSMutableDictionary* dataStacksByFilename;

+(CoreDataStack*) coreDataStackWithDatabaseFilename:(NSString*) dbfn
{
	if( dataStacksByFilename == nil )
	{
		dataStacksByFilename = [NSMutableDictionary new];
	}
	
	CoreDataStack* cds = [dataStacksByFilename valueForKey:dbfn];
	
	if( cds == nil )
	{
		cds = [[[CoreDataStack alloc] initWithDBFilename:dbfn] autorelease];
		[dataStacksByFilename setValue:cds forKey:dbfn];
	}
	
	return cds;
}

+(CoreDataStack*) coreDataStackWithDatabaseURL:(NSURL*) dburl
{	
	CoreDataStack* cds = [[[CoreDataStack alloc] initWithURL:dburl] autorelease];
	
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

- (id)initWithURL:(NSURL*) url
{
    self = [super init];
    if (self) {
        self.databaseURL = url;
		self.coreDataStoreType = CDSStoreTypeUnknown;
		
		if( self.coreDataStoreType == CDSStoreTypeUnknown )
		{
			[self guessStoreType:[self.databaseURL pathExtension]];
		}
    }
    return self;
}

- (id)initWithinitWithDBFilename:(NSString*) dbfn
{
    return [self initWithinitWithDBFilename:dbfn storeType:CDSStoreTypeUnknown];
}


- (id)initWithinitWithDBFilename:(NSString*) dbfn storeType:(CDSStoreType) type
{
    self = [super init];
    if (self) {
		self.coreDataStoreType = type;
		self.databaseFilenameOrNil = dbfn;
        self.databaseURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:self.databaseFilenameOrNil];
		
		if( self.coreDataStoreType == CDSStoreTypeUnknown )
		{
			[self guessStoreType:[self.databaseFilenameOrNil pathExtension]];
		}
    }
    return self;
}

-(NSManagedObjectModel*) dataModel
{
	if( _mom == nil )
	{
		NSString* momdPath = [[NSBundle mainBundle] pathForResource:@"ScrumProject" ofType:@"momd"];
		NSURL* momdURL = [NSURL fileURLWithPath:momdPath];
		
		_mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momdURL];
	}
	
	return _mom;
}

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

-(NSPersistentStoreCoordinator*) persistentStorceCoordinator
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
				storeType = NSXMLStoreType;
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
		if (![_psc addPersistentStoreWithType:storeType configuration:nil URL:self.databaseURL options:nil error:&error]) {
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
		[_moc setPersistentStoreCoordinator:[self persistentStorceCoordinator]];
	}
	
	return _moc;
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

@end
