/**
 CoreDataStack - CoreData made easy
 
 c.f. https://github.com/adamgit/CoreDataStack for docs + support
 */
#import <Foundation/Foundation.h>

#import <CoreData/CoreData.h>

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
 */
+(CoreDataStack*) coreDataStackWithDatabaseURL:(NSURL*) dburl modelName:(NSString*) mname;

- (id)initWithURL:(NSURL*) url modelName:(NSString *)mname storeType:(CDSStoreType) type;

-(NSManagedObjectModel*) dataModel;
-(NSPersistentStoreCoordinator*) persistentStorceCoordinator;
-(NSManagedObjectContext*) managedObjectContext;

#pragma mark - essential methods that Apple forgot to provide

/*! Apple's implementation of CoreData doesn't support Blocks. How sad. Let's fix that for them! */
-(void) saveOrFail:(void(^)(NSError* errorOrNil)) blockFailedToSave;

@end
