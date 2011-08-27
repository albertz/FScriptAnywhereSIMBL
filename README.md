F-Script Anywhere SIMBL
=======================

The [F-Script project](http://www.fscript.org/) contains within it an application called F-Script Anywhere. This application allows one to add the F-Script framework into any Cocoa application without altering the application itself, along with enough UI to be able to create an interpreter or object browser within the running application. This is extremely useful as a development tool when used with one's own application, or as an educational tool for exploring the makeup of any Cocoa application. 

F-Script Anywhere was not always part of the standard F-Script distribution. It was originally written by [Nicholas Riley](http://sabi.net/nriley/), and unfortunately the original method used for injection into a running app stopped working in Mac OS X 10.3. [Ken Ferry](http://homepage.mac.com/kenferry/software.html#fsa) wrote a quick and dirty temporary fork, called F-Script Anywhere SIMBL, that worked well on 10.3 and 10.4.

This is an update to recent versions of SIMBL (0.9.9) and FScript (2.1, 2010-06-14) and works fine on Mac OS X 10.7.

Installation
------------

* Install SIMBL and FScript.
* Copy the FScript framework to the directory `/Library/Frameworks/`.
* Copy `FScriptAnywhere.bundle` to `~/Library/Application Support/SIMBL/Plugins/`.

That should get it installed, but it still won't load into any applications. To control which applications it loads into, you need to edit `~/Library/Application Support/SIMBL/Plugins/FScriptAnywhere.bundle/Contents/Info.plist`. At the bottom of the property list, you'll see an array with key `SIMBLApplicationIdentifier` which is currently empty. If you add application identifiers to the array then apps with those identifiers will load FScriptAnywhereSIMBL. For example, to load into iPhoto and Mail:

	<key>SIMBLApplicationIdentifier</key>
	<array>
		<string>com.apple.iPhoto</string>
		<string>com.apple.mail</string>
	</array>
		
Now restart the applications you're interested in. If you've succeeded in loading the bundle into an application, that application will have an FSA menu.

The `*` character is special, and if you use it as an entry in the `SIMBLApplicationIdentifier` array then the bundle will load into all cocoa applications.

For documentation not covered here, please see the [F-Script project](http://www.fscript.org/) for information concerning F-Script and F-Script Anywhere, and [SIMBL](http://culater.net/software/SIMBL/SIMBL.php) for information related to SIMBL. Also, be sure to check out the [F-Script mailing list](https://lists.sourceforge.net/lists/listinfo/f-script-talk).

Have fun!

---

-- Albert Zeyer, <http://www.az2000.de>

