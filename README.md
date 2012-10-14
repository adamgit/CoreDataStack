CoreDataStack
=============

Simple classes to make Apple&#39;s Core Data usable for normal human beings

Core Data is very easy to use - unless you follow Apple's source examples (which are nothing like real-world examples).

Apple's bad examples / bad practices
=====

1. Xcode's default template for "a CoreData enabled app" puts 300 lines of INCORRECT, UNNECESSARY code into your Project.
2. Xcode puts it all into AppDelegate - the worst possible place for this code.
3. Apple's sample code forces you to have ONLY ONE CORE DATA MODEL open at a time. This is very, very bad: most CoreData projects would be ten times easier to write and debug if they used multiple models. They would also run faster. But if you start with Apple's template, you cannot do this. CoreData was not designed to be used that way!

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

...or, better, because the line above is BAD PRACTICE (even though Apple uses it in their source examples), use:

NSEntityDescription* entityDesc = [stack entityForClass:[MyFirstEntity class]];

NB: if you use Apple's version, which takes an NSString, then refactoring in Xcode *will NOT work!* and any small typo will NOT be detected by the compiler - your app will instead crash at runtime. So ... don't pass in an NSString, pass in the class you want instantiated.

Easy!
