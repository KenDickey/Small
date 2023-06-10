# Approach -- approximate and iterate

I really want Cuis on a RiscV64 with compile-to-native.

I have been looking at Pinocchio, OpenSmalltalk, and Bee runtimes but
want something less complex.

The thought is to do "the simplest thing that will work" in Cuis
to generate a metacircular Smalltalk native runtime, then add
OS native support for UI, events, files, sockets .. working toward
a full Cuis IDE (a.k.a. _Cuis Userland_)

## Essentials: What Makes Cuis Cuis?

- Full IDE: Refactoring Tools, Syntax Hilighting, Code Completion
- Minimalist -- all code must carry its own weight (Base < 700 Classes)
- Composition/Modularity -- Features Provided by  versioned Packages
- Morphic 3: Antialiased Scalable Vector Graphics & TT Fonts
- Unified Unicode
- Compiletime constant literals (backquote, e.g `1@2`).
- and of course: ANSI Smalltalk Standard (such as it is..)


Pole Star Goal: Load any Cuis Package and use it without change.

VM Support Makes Problems:
 - LiveTyping
 - FFI
 - Plugins

## See also Scribblings:

UserlandClasses.txt -- Critical Classes to understand

PrimCallers.tst  -- methods that call PrimOps
  -- note:  #Parser>>primitivePragmaSelectors.

BeeBootstrapClasses.txt

## Various Bootstrap Refs

- https://playingwithobjects.wordpress.com/2013/05/06/bootstrap-revival-the-basics/
- https://github.com/guillep/PharoCandle
- https://github.com/powerlang/bee-dmr
- http://esug.org/data/ESUG2014/IWST/Papers/iwst2014_Design%20and%20implementation%20of%20Bee%20Smalltalk%20Runtime.pdf
- http://www.smalltalksystems.com/publications/avmarch.pdf
