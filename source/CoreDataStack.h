/**
 CoreDataStack - CoreData made easy
 
 c.f. https://github.com/adamgit/CoreDataStack for docs + support
 */
#import <Foundation/Foundation.h>

#import <CoreData/CoreData.h>

#define kNotificationDestroyAllNSFetchedResultsControllers @"DestroyAllNSFetchedResultsControllers"
typedef enum CDSStoreType
{
	CDSStoreTypeUnknown,
	CDSStoreTypeXML,
	CDSStoreTypeSQL,
	CDSStoreTypeBinary,
	CDSStoreTypeInMemory
} CDSStoreType;

@interface CoreDataStack : NSObject
{
	NSManagedObjectModel* _mom;
	NSManagedObjectContext* _moc;
	NSPersistentStoreCoordinator* _psc;
}

/*! The actual URL that's in use - you can pass this to init, or let the CoreDataStack work it out automatically */
@property(nonatomic,retain) NSURL* databaseURL;
/*! Name of the model file in Xcode, with no extension - e.g. for "Model.xcdatamodeld", this is "Model" */
@property(nonatomic,retain) NSString* modelName;
/*! Apple's source code is weak and crashes if you don't tell it the correct 'type' of CoreData store. This class will try to guess it for you - or you can explicitly set it during or after init */
@property(nonatomic) CDSStoreType coreDataStoreType;

/*! 99.999% of all projects need this set to "TRUE", but Apple's code defaults to FALSE */
@property(nonatomic) BOOL automaticallyMigratePreviousCoreData;

/*! To use CoreData, you need to provide a permanent filename for it to save its sqlite DB to disk - or provide a manual URL to where
 you've already saved it. You also need to provide a model name
 
 I recommend "MyModelName.sqlite" as a name
 
 Returns a SHARED stack - multiple classes fetching the same filename will get the same stack object back (this is what you want in 99.9% of cases)
 
 TODO: allow non-shared stacks
 
 If you need separate stacks, then init the first one using the name, and init all subsequent ones like this:
 
 firstStack = [CoreDataStack coreDataStackWithDatabaseFilename: @"MyModel"];
 secondStack = [CoreDataStack coreDataStackWithDatabaseURL: firstStack.databaseURL]; // uses the same config data, but is NOT shared
 */
+(CoreDataStack*) coreDataStackWithModelName:(NSString*) mname;
/*! To use CoreData, you need to provide a permanent filename for it to save its sqlite DB to disk - or provide a manual URL to where
 you've already saved it. 
 
 NB: either keep this reference and re-use it throughout your app, or use the other version of this method that returns a "shared" pointer,
 otherwise you'll get CoreData inconsistency errors
 */
+(CoreDataStack*) coreDataStackWithModelName:(NSString *)mname databaseFilename:(NSString*) dbname;
+(CoreDataStack*) coreDataStackWithSharedModelName:(NSString *)mname databaseFilename:(NSString*) dbname;
/*! To use CoreData, you need to provide a permanent filename for it to save its sqlite DB to disk - or provide a manual URL to where
 you've already saved it.
 */
+(CoreDataStack*) coreDataStackWithDatabaseURL:(NSURL*) dburl modelName:(NSString*) mname;

- (id)initWithURL:(NSURL*) url modelName:(NSString *)mname storeType:(CDSStoreType) type;

-(NSManagedObjectModel*) dataModel;
-(NSPersistentStoreCoordinator*) persistentStoreCoordinator;
-(NSManagedObjectContext*) managedObjectContext;

#pragma mark - essential methods that Apple forgot to provide

/*! Useful method that MOST APPS need, to check instantly whether they've been initialized with this CD store before */
-(BOOL) storeContainsAtLeastOneEntityOfClass:(Class) c;

/*! Apple's implementation of CoreData doesn't support Blocks. How sad. Let's fix that for them! */
-(void) saveOrFail:(void(^)(NSError* errorOrNil)) blockFailedToSave;

/** Shorthand for Apple's clunky, overly-verbose method:
 
 [NSEntityDescription entityForName: inManagedObjectContext:]
 
 NB: Apple uses an NSString argument; you should never use a string argument! Very unsafe code, very bad practice. There's good reason for allowing String
 argument here (it enables CoreData to work with classes that it doesn't actually have the class file) but that's a very rare case for most projects.
 
 ...instead, call this method for an entity named e.g. Entity (Apple's default entity name):
 
     "[stack entityForClass:[Entity class]];"
 
 NB: Obviously, this implementation automatically uses the stack's current NSManagedObjectContext as the final argument - anything else wouldn't make sense
 */
-(NSEntityDescription*) entityForClass:(Class) entityClass;
  
/*! Deletes all data from your CoreData store - this is a very fast (and allegedly safe) way
 of resetting your data to a "virginal" state, as if your app had just been installed for the
 first time.
 
 It is ALMOST CERTAINLY not safe to call from a multithreaded environment, because nothing in
 Apple's code is threadsafe. But you already knew that, right?
 
 c.f. http://stackoverflow.com/questions/1077810/delete-reset-all-entries-in-core-data
 
 ALSO ... side effect: all NSFetchedResultsController's will explode. As of iOS 5.1, NSFetchedResultsController is
 still an inherently buggy class, and I'd recommend avoid using it if you possibly can. To make this slightly
 less painful, we'll post an NSNotificaiton that you can listen for inside your own NSFetchedResultsController
 subclasses, and re-build your NSFetchedResultsController when you receive one.
 
 Easy way: use this code as your init method for your NSFetchedResultsController subclass
 
 -(id)initWithCoder:(NSCoder *)aDecoder
 {
   self = [super initWithCoder:aDecoder];
   if (self) {
   // Custom initialization
     
     [[NSNotificationCenter defaultCenter] addObserverForName:kNotificationDestroyAllNSFetchedResultsControllers object:nil queue:nil usingBlock:^(NSNotification *note) {
     NSLog(@"[%@] must destroy my nsfetchedresultscontroller", [self class]);
     [__fetchedResultsController release];
     __fetchedResultsController = nil;
     }];
   }
   return self;
 }
 */
-(void) wipeAllData;

@end
