Hatch Patterns for AutoCAD

Copyright Charles Sweeney HatchPatterns.com
###########################################

-----------------------------
INSTALLING THE HATCH PATTERNS
-----------------------------

For AutoCAD 2007, 2006, 2005, 2004.  LT 2006, 2005, 2004.
########################################################

In brief:
---------
Copy and paste the entire contents of my file hatch_pattern_code.txt into your acad.pat hatch file and your acadiso.pat hatch file (aclt.pat and acltiso.pat hatch files for LT).  Make sure there is a carriage return at the end of the last line.  You will then see the new hatch patterns alongside the standard AutoCAD patterns in the "Other Predefined" tab when using the BHATCH command.

In more detail:
---------------
You need to locate your existing two standard AutoCAD (or LT) hatch files, open them in a text editor, then copy the hatch pattern code from my file (hatch_pattern_code.txt) into them.

The standard AutoCAD hatch files are acad.pat and acadiso.pat (aclt.pat and acltiso.pat for LT).  acad.pat contains the hatch patterns used in imperial drawings, and acadiso.pat contains the hatch patterns used in metric drawings.  The patterns in both files are the same except for the dimensions used.  Hatch pattern files (.pat) are just ordinary text files consisting mainly of numbers, which is the code AutoCAD uses to draw the hatches.

Typically you will find the hatch files in this directory (folder):

c:\Documents and Settings\(your username)\Application Data\Autodesk\(AutoCAD or LT version)\enu\support

The "Application Data" directory is a hidden one, and might not be visible on your system.  To make it visible, go into Windows Explorer (for Windows XP: start > All Programs > Accessories > Windows Explorer) then browse to the c:\Documents and Settings\(your username)\ directory.  click on: Tools > Folder Options... then click on the "View" tab.  Under "Advanced Settings: Hidden files and folders" select "Show hidden files and folders" then hit "OK".  This will make the "Application Data" directory visible, and allow you to locate the .pat hatch pattern files.

(The above example shows the drive letter "c:\".  This might be different on your system, but the directory structure will be the same.)

If the hatch files are not in this directory (by default they will be) then you will need to search for them.  Search for them in Windows Explorer by hitting the "Search" button, selecting "All files and folders", then entering *.pat in the file name search box.  Select "My Computer" from the "Look in:" list.  Then hit "Search".  This will give you the locations of your hatch files.

You might have more than one acad.pat file (or more than one acadiso.pat, aclt.pat, acltiso.pat file).  In which case you should use the one that is highest in the "Support File Search Path" list, or use any one and move the directory that it is in to the top of the "Support File Search Path" list (see below).

When you are happy that you have located the acad.pat and acadiso.pat files that you are working with (aclt.pat and acltiso.pat files for LT) you need to open them and paste my hatch pattern code into them.  Open the files by double-clicking on them, then selecting Notepad to edit them, or any other PLAIN TEXT editor.  If you use something like Word, you could end up with formatting that will have an adverse effect on the operation of the patterns.  Alternatively, open Notepad then browse to the files where you previously located them, and open them that way.

You will need to open my hatch_pattern_code.txt file in Notepad also.  Select everything in my file and copy it (right-click "Select All", right-click "Copy").  You will notice that a blank line has been selected at the bottom of my data.  This is as it should be.  This blank line (a carriage return) is to tell AutoCAD that the end of the file has been reached.  Without it you will get an error when you try to hatch.

Go into acad.pat (aclt.pat for LT) then go to the last line in the file.  Place the cursor at the start of the next blank line, then paste in my code (right-click "Paste").  Do the same with the acadiso.pat file (acltiso.pat for LT).  In both cases, ensure there is a carriage return at the end of the last line.

You can paste my code anywhere in your original file.  You can pick out my pattern codes and paste them in individually.  To make it easier for people who do not do this very often, I suggest pasting everything in at the bottom.  Always remembering to have that carriage return at the end of the last line.  The order that the patterns appear in the hatch files, determines the displayed order you see when using the BHATCH command.  If you use one particular pattern quite often, it is a good idea to move it to the top of the .pat file.

Once you have pasted my code into the relevant files, save them.  Ensure that your text editor does not add the extension ".txt" to the file.  If need be, you can put the file name in quotes "" when saving it, which will prevent .txt being added to it.  The hatch files are NOT case sensitive, so "acad.pat" or "ACAD.PAT" are both acceptable.  You will then see the new hatch patterns alongside the standard AutoCAD patterns in the "Other Predefined" tab when using the BHATCH command.  You use the new patterns in the same way that you would use the standard patterns (see the note about scale in the "USING THE HATCH PATTERNS" section below).  In some cases you might not see a preview swatch of the pattern.  This is due to the scale it is drawn in, and does not mean there is an error in the pattern.

Finally, ensure that the directory (folder) containing the hatch files you edited is at the top of the AutoCAD "Support File Search Path" list.  AutoCAD (or LT) will use the first acad.pat file it encounters (or acadiso.pat, aclt.pat, acltiso.pat as appropriate).  If the hatch files were in the "c:\Documents and Settings\..." directory, then this will probably be at the top already.  To check this, in AutoCAD (or LT) go into:

Tools > Options > Files

You will get the search paths dialogue box.

Double-click on "Support File Search Path".

This will show a list of directories that AutoCAD searches for files such as .pat hatch pattern files.  If the correct directory path is at the top, you don't need to do anything.  If you need to move the correct directory path to the top of the list, click on it, then use the "Move Up" button, to move this path to the top of the list.  Remember, the correct directory path is the one containing the directory that your edited .pat files were in.

For AutoCAD 2002, 2000i, 2000.  LT 2002, 2000i, 2000.
#####################################################

The instructions above apply to these versions with the exception that the default location for the standard hatch pattern files is typically:

c:\Program Files\(AutoCAD or LT version)\support

This directory is the default path for hatch files, so you should only need to copy my code into the hatch files in this directory, without having to change search paths.

At its simplest level, find the standard hatch files acad.pat and acadiso.pat in the above directory, then paste my code into them (for LT the standard hatch files are aclt.pat and acltiso.pat).  Please see above for detailed instructions.

For AutoCAD R14, R13.  LT 98, 97, 95(R3).
#########################################

The instructions above for AutoCAD 2007 apply to these versions with the exception that the default location for the standard hatch pattern files is typically:

c:\Program Files\(AutoCAD or LT version)\support

For LT if there is no support directory (folder) the default location for the hatch files is:

c:\Program Files\(LT version)\

And also you must replace your existing slide-library file (acad.slb) with my slide-library file (acad.slb) included with the relevant download. For LT the slide-library file is called aclt.slb

The slide library goes in the same directory as the hatch pattern files.  Copy my slide-library file into the relevant directory by dragging and dropping it in Windows Explorer (information about Windows Explorer is under the 2007 section above).  It is adviseable to rename your original file, or move it somewhere else for safekeeping should you need to refer back to it.

If your hatch and slide-library files are in the default directory, you will not need to change search paths.

For AutoCAD R12 and earlier.  LT R2, R1.
########################################

Copy and paste the entire contents of my file hatch_pattern_code.txt into your acad.pat hatch file (aclt.pat hatch file for LT).  Make sure there is a carriage return at the end of the last line.  You will then see the new hatch patterns alongside the standard AutoCAD patterns when using the BHATCH command.  You can see the patterns by clicking on Hatch Options... > Pattern... 

You can see more information on the copying and pasting task, and saving the files, in the instructions above for the 2007 versions.  Note that in those instructions, mention is made of acadiso.pat and acltiso.pat which you do not need for these versions of AutoCAD and LT.

For AutoCAD, your standard hatch file (acad.pat) should typically be in this directory (folder):

c:\acadwin(or acad)\support

For LT it will be something like:

c:\aclt\

If you cannot locate your original hatch file, search for all .pat files on your computer.  There is more information about this in the instructions above for 2007 versions.

Also you must replace your existing slide-library file (acad.slb) with my slide-library file (acad.slb) included with the relevant download. For LT the slide-library file is called aclt.slb

The slide library goes in the same directory as the hatch pattern files.  Copy my slide-library file into the relevant directory by dragging and dropping it in Windows Explorer (information about Windows Explorer is under the 2007 section above).  It is adviseable to rename your original file, or move it somewhere else for safekeeping should you need to refer back to it.

If your hatch and slide-library files are in the default directory, you will not need to change search paths.


For Architectural Desktop (ADT), AEC, Map and other AutoCAD-powered versions
############################################################################

The methods used for installing the hatch patterns in the standard versions of AutoCAD should be used here.  The principle is the same, copy my hatch code into your standard hatch file.

Use the instructions for the version of AutoCAD that closest matches the version of your program.  For example, if you have ADT 2006, then follow the instructions above for AutoCAD 2006.

USING THE HATCH PATTERNS
########################

Errors
------

If you get an error, it will most likely be caused by the omission of a carriage return from the end of the last line in the hatch file.  To fix this, Open your hatch file in a text editor such as Notepad.  Place the cursor at the end of the last line of code, then hit "return" or "enter".  This makes a carriage return.  Then save the file.

If you cannot see the new hatches, then this will most likely be due to the search path being incorrect.  AutoCAD will use the first acad.pat it comes across, so you must make sure that the directory containing the edited hatch file is at the top of the search path list.  See the instructions above for more information.

Pattern names
-------------

In order to make my hatches compatible with all versions of AutoCAD and LT, I have restricted the pattern names to eight characters.  To make the pattern names unique, they all end in "hpdc" which stands for "Hatch Patterns Dot Com", but could be anything.  Making the pattern names unique means that they will not clash with any patterns that you might already have installed on your system.  The number component of the pattern name (e.g 7965) is simply that, a unique number.  In itself it doesn't mean anything.  Due to using eight characters, it was virtually impossible to write meaningful pattern names.

For your convenience you can download a PDF file showing the patterns and the pattern names.  You can get it here:

http://hatchpatterns.com/r22/hatch_pictures.pdf

Scale
-----

When making these patterns I try to choose sizes that will be most compatible with the drawing units a typical user might be using.  For logistical reasons, I might not always be able to do this.  However it is impossible to know what units a user will be using in all cases.  A user could be drawing in millimetres, inches, feet, or miles.  So a size of "1" in my pattern code would be 1mm for someone drawing in millimetres, or 1" for someone drawing in architectural imperial units.

You can therefore expect to make some adjustment to the scale of the patterns.  In all AutoCAD and LT versions you can adjust the scale of the hatch pattern in the relevant hatch command, usually by entering a number in a "Scale" box.  You can also enter decimal values for the scale.  In other words, it doesn't have to be a whole number, you can have 5.3 for example.  You will probably have to experiment a little to get a scale that looks right for your drawing.

Try using a larger scale first.  If the scale is too small, the pattern will be too dense and might give an error or take too long to appear.  Start large and work your way down.

Angle
-----

All my patterns are drawn assuming they will be used with an angle of "0".  As with scale, you can enter any angle for the hatch.  You might find that you get a better hatch for a particular hatch by changing the angle.

Multiple hatching
-----------------

You can apply a hatch pattern over another hatch pattern.  Usually this results in a mess, but with some imagination you might get a useful pattern.

SNAPBASE
--------

This is a very useful command.  It moves the origin of the hatch to a specified point.  If you find that you cannot get a hatch to line up properly, try using this command and entering a start point where you want the hatch to begin.  In some drawings with very large dimensions, you might find that a pattern breaks up as it gets further away from the (0,0) origin.  This is due to angles being used in the patterns.  I write angles and lengths to six decimal places (one millionth of a unit) where necessary.  This minimises break up.  Using SNAPBASE you can move the origin for hatching to a place in the drawing close to where you need the hatch, which will eliminate the break up.

Ctrl c
------

This is the emergency brake.  If you have selected a scale that is too small, and the hatching is taking too long to appear, you can hit "Ctrl c" which will cancel the hatching operation.

Contact
-------

Feel free to email me if you need any help or need a particular pattern made.

info@hatchpatterns.com

Charles Sweeney
HatchPatterns.com