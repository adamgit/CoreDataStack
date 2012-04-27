CoreDataStack
=============

Simple classes to make Apple&#39;s Core Data usable for normal human beings

Apple makes it INCREDIBLY DIFFICULT to do common simple things with CoreData. Apple's default template for "a CoreData enabled app" puts 300 lines of crap into your Project.

Worse, Apple puts it all into AppDelegate - the worst possible place for this code.

EVEN WORSE, Apple's sample code forces you to have ONLY ONE CORE DATA MODEL open at a time. This is EXTREMELY BAD programming practice and leads to MANY BROKEN APPS AND SOURCE PROJECTS.

(multi-threaded CoreData is extremely difficult, because Apple implemented CoreData badly - but if you use multiple models in parallel, everything is threadsafe automatically. Instead of learning the difficult MT model for CoreData, just use multiple models!)

So, this simple library turns CoreData from:

     "300 lines of incomprehensible code in your AppDelegate class"

...into:

     "3 lines of simple, easy code you can re-use throughout your project"

License is:

    Do whatever you want with this code. Attribution is appreciated - @redglassesapps on twitter - but not required.


Installation A: by drag/drop into your project
=====

1. Open the "source" folder
2. Drag/drop all the files into your project


Installation B: by creating a static library
=====

Not supported yet. Use "Installation A" instead (see above) If you really want it, add an item to the Issue Tracker on Github, and I'll make a library version.


Usage
=====

To use CoreData, you ALWAYS need to have created a CoreData Model first. You also ALWAYS need to have defined a save location for the database.

Apple makes this difficult, but we make it easy again. All you need to know is the NAME of your CoreData Model (the graphical doc that lets you edit and add entities) - whatever name it appears in on the left hand side of Xcode. e.g. if it says "CoreDataModel.xcdatamodeld" then the "NAME" is "CoreDataModel"

Given the name, you do:

CoreDataStack* stack = [CoreDataStack coreDataStackWithModelName:@"My_Model_Name"]];

Then, everytime CoreData needs a "ManagedObjectContext" instance, you just pass it:

stack.managedObjectContext

e.g.:

NSEntityDescription* entityDesc = [NSEntityDescription entityForName:@"MyFirstEntity" inManagedObjectContext:stack.managedObjectContext];

Easy!