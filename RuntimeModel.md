# Runtime Model

Smalltalk is meant to be a small and simple language _for the user_.
The syntax is minimal and basic opearations consist of Message Send, Return, and Assignment.
Smalltalk Objects hold values, receive and send messages.
The Wikipedia.org page on Smalltalk had a good description of this.

Mapping from the source language, Smalltalk, to the target machine, RISC-V RV64G or Aarch64/ARMv8,
means comparing the two world views and concentrating on the differences.
[Note "Realisitic Compilation by Program Transformation", Kelsey & Hudak, 1989]
(https://hashingit.com/elements/research-resources/1989-01-realistic-compilation-by-program-transformation.pdf)
[RV64GC Specs: (https://riscv.org/technical/specifications/)] 

Smalltalk is also well known for maintaining the dual view of the relation
between text source and machine binary runtime and displaying machine state
in comprhensible ways.
["Design Principles Behind Smalltalk", Dan Ingalls, 1981]
(http://www.cs.virginia.edu/~evans/cs655/readings/smalltalk.html)

As all objects know how to present themselves, the "simple to use" language
has complex underpinnings, e.g. Garbage Collection and access to the runtime
stack frames via #thisContext.

This document collects ideas for an RISC "asm up" runtime system with adequate performance
as a simplified "backstop runtime".

## Runtime Globals

There exists a vector/array of objects known as the Known Objects Array.

One known object is the SystemDictionary named #Smalltalk.

Basically, all globals known to code are either local values
(Instance Variables or Method Temporaries) or are names in the Smalltalk Dictionary.

There is a segmented table of ClassID -> Behavior, where a Behavior is a
dictionary of (Method Selector Symbol -> Method).
One of the selectors is #class, so each object knows its class.
All objects have behaviors -- they are useless otherwise.
Sending a message to an object is achieved by looking up the message
selector in the object's behavior dictionary (or those of its
ancestors) and invoking that method with the object and other
arguments.  This is explained further below.

## Object Layout Format

All entities in Smalltalk are known as Objects.
To do anything, Messages are sent to Objects.
There is nothing else.

All the machine knows are bits, either in memory or registers.

The basics of managing the bits to represent information is well covered in
David Gudeman's paper: 
"Representing Type Information in Dynamically Typed Languages"
https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.39.4394&rep=rep1&type=pdf

In short, Smalltalk Objects are represented as either
_Immediate Values_, those which fit in a machine register,
or
_Vector-Like Objects_, an array, the first part of which is a Header,
which encodes clues to its size and structure) and an optional part which is
interpreted either as Smalltalk Objects (A compact array of Slots) or
binary data (e.g. a ByteVector).

We are using OpenSmalltalkVM's "Spur" header format
(refs below; see "Spur Object Format").

Key ideas: Horizontal vs Vertical Encoding and Hashing.

_Dictionarys_ map _Keys_ to _Values_.
Each Smalltalk object responds to a method #hash which reponds with a SmallInteger
which is used to shorten key lookup time. [https://en.wikipedia.org/wiki/Hash_table]

_Horizontal Encoding_ maps categories to bits which can be tested individually,
e.g. (#sphere->1, #cube->2, #ball->4, #rectangel->8, #square->16).
This is used where there are few
categories and an object may be classified in 
multiple categories (e.g. Sphere+Ball, Square+Rectangle)

_Vertical Encodings_ are just consecutive numbers and may be used where there are many categories,
each of which is distinct from all others.
E.g. (#triangle->4, #rectangle->4, #pentagram->5, #hexagram->6)

Most immediate values (small integers, floats, characters) and object header format
is well described in Clément Béra: "Spur’s new object format"
https://clementbera.wordpress.com/2014/01/16/spurs-new-object-format/
(Other refs below).

Most values are known by the tag in their lower 3 bits.
- 2r000 -> Object Oriented Pointer, or _OOP_.
- 2r001 -> Small (limited range) Integer
- 2r010 -> Character
- 2r100 -> Small Floating Point Number, or _float_.

Three immediate values are special: _true_, _false_, and _nil_.
The trick here is that we don't use OOP addresses near zero.  
So _nil_, _true_, and _false_ are known by their small values, which
are easy to create and check in code.

- UndefinedObject/Nil = 0  [So matches register ZERO = x0]
- False = 8 = 2r01000
- True = 16 = 2r10000

Most values are initialized to _nil_, so writing zeros makes initialization easy.
It is assumed (need to test this) that the ease of initialization and use
will compensate for the irregulatiry in testing.  We shall see.

## Runtime Model

The foregoing gave a brief overview of how objects (data+behavior) are represented in memory.
Here we describe the basics of the _runtime execution model_, how the Central
Processing Unit or _CPU_ uses the Stack and Registers to process instructions and
drive computation forward.

Method objects contain references to "literal values", code, and information about the
method such as it's Selector symbol, number of arguments, use of registers and stack,
if it generates ^returns, if it may generate blocks which can "escape" to live longer than
the stack frame/thisContext and may hold captured references to values in the
visible/lexical environment.

There may be multiple "entry points" into the main body of the code, some of which do
extra checks on the kind of arguments acceptable.  E.g. low-level addition of two small integers
requires a _guard_ to assure that both arguments are indeed small integers.
DoIt to the text "3 + 4" in a Workspace invokes ```SmallInteger>>+```.
The #+ method of the SmallInteger object 3 requires one SmallInteger argment.
If this is the case, then the simple method code adds its _self_ object, 3, to
its argument, 4, to get 7 which it gives back as the result of the method send.

If, however we try "3 + 643872648732674863287462387648723648723687423" the #+ method
notes that its argument in a LargeInteger (or _BigNum_) and a more complex calculation
is required.

"Compelling, detailed example here, w regs + stack usage."
" Perhaps allocate and initialize an object "


## Registers & Stack

We will use more registers, but stack layout might be patterned after the Bee DMR.
http://esug.org/data/ESUG2014/IWST/Papers/iwst2014_Design%20and%20implementation%20of%20Bee%20Smalltalk%20Runtime.pdf

Note especially: Allen Wirfs-Brock: "Efficient Implementation of Smalltalk Block Returns"
http://www.wirfs-brock.com/allen/things/smalltalk-things/efficient-implementation-smalltalk-block-returns

RISC-V Stack grows down and is quadword aligned.
Stack records are between the chained FramePointer regs, which point to base of stack frame, and the StackPointer itself.

@@@

### Registers

- FramePointer is register S0 (x8).
- StackPointer is register SP (x2).
- Self/Receiver is register A0 [Also Result]
- Arguments in registers A1..A7 with spill to Stack
- Method in S1 [For literal access; 1st literal is CodeVector]
- Env in S2 [for closure captured variable access; may be nil]
- PC [Points into Method's Codevector]
- Temp0 .. Temp6 in T0..T6 w spill to Stack
- ReturnAddress in RA (x1)
- Nil/UndefinedObject is ZERO (x0) [see below]
- KnownObjects base
- Behavior/Class table base page
- MethodContext Header Template
- StackLimit
- NextAlloc
- AllocLimit
[IntReg Backup/Home in Float Regs (faster than RAM)]

### Stack Layout
```
    Stack Object Header
    ..
    ..    
    ^
    ^  	MethodContext-Header
    ^--<OlderFP <---------------<
        ReturnAddress		^
	Receiver		^
	Method			^
        [Oarg..]  [oops] 	^
	[Otemp..] [oops]	^
	[Btemp..] [bits]	^
	MethodContext-Header	^
FP--->  PreviousFP >------------^
	ReturnAddress
	Receiver
	Method
        [Oarg..] 
	[Otemp..]
	[Btemp..]
SP---> 	MethodContext-Header

```
Note: For GC, a Method knows its number of args, objTemps, binaryTemps.

Note: to interpret/convert frames into Context objects requires tracking spills and registers.
If each method knows its frame size, then just push a MethodContext Header and set its size
and info fields.
Zero out stack slots at frame alloc.
At time of debug or exception, traverse stack
and perform reg->stack spills before dereferencing MethodContexts.
Get newest thisContext from current FramePointerReg and backchain FramePointers to traverse
(e.g. for GC).

CPU Regs are known as (partition) "bits" or "OOPS" and only the OOPS get scanned by GC.
Methods know this.

To avoid "deep spill problem" (lazy caller-save register spill, deeply nested return must restore)
the invariant is that such regs must be "eagerly" spilled before block escapes, known by compiler
[?annotate in MethodContext Header flags?]

Saved regs alloc'ed for loop constructs to be "rare" relative to blocks to minimize spills.
[Investigate ping/pong/coroutine register cooperation patterns].

Do simple rules for "register tracking" for debug as to what/when on stack and what/when in regs
and annotate special case details in code.


## Message Invocation

After Bee, we separate lookup from invocation.

Lookup takes an object, the receiver, and a selector and finds either
the requisite method or substitutes a DNU.

Selector Ideas

Selector is subclass of Symbol, but with additional slots
-  Hash2 -> room for 2 secondary hashes + a 20 bit constant ID [1 million selectors]
-  PIC - by selector vs by call site?
-  As using "classIDs", can simply change class of Selector instance
[with same "structural type"]
```
    Symbol
      |
     Selector
    /  |  \  \
   /   |   \  \
Mono Poly Mega isA
```
Use "copydown" method strategy for MegaMorphic Methods. [Only check 1 mDict]

#isA pattern: Just a subclass test.  Use sorted vector of ClassIDs (highest first).
Linear search.

[Duo? Special case of Monomorphic w 1 override?]


Registers reserved for method lookup.. 
- A0=Receiver
- temp0 for Selector [Temp0 is object Reg]
- temp1 & temp2 for binary (non-object) usage.
- other temps for hash & dict lookup? TBD

### Method Lookup:
```
Before
  Receiver [A0]
  Selector [Temp0]
  Args [A1..16; spill to Stack]
After
  Receiver [A0]
  Args [A1..6;stack]
  Method [S1]
  Env [S2; nil or block captures]
```
### Method Invocation:
```
  Arg Checks -> redispatch if required
  Prolog ->  Adjust StackPointer as required
    [Note Tail Calls; Leaf Calls; Block Env Capture]
```

## Contexts & Exceptions

## Optimization Ideas

Make "type tests" visible to be "lifted out" or "propagated forward".
I.e. in a Method, if the first send does a check for an argument being a SmallInteger,
if the test passed, then no other sends need to re-check for this object again.
All succeeding SmallInteger tests can be elided (the tested object's "type" 
has become resolved).

Selectors with 3 hash values -> Method lookup for specific table can use best
case hash to reduce collisions.

Table class specialization on h1/h2/h3 like that for Selector specialization.

Method specialization for tail/leaf/capture/.. like that for Selectors.

Small Objects who's lifetimes don't extend beyond the lifetime of
a method invocation could be stack-allocated.

Within the context of a Class, trivial slot accessors could be open-coded.

With argument literals, one could preform subclass tests at compile time; other constant propagarion.
This requires recompilation when overrides.

## Background Reading

### thisContext, Exception handling, and Stack Management
Allen Wirfs-Brock: "Efficient Implementation of Smalltalk Block Returns"
http://www.wirfs-brock.com/allen/things/smalltalk-things/efficient-implementation-smalltalk-block-returns

Javier Piḿas, Javier Burroni, Gerardo Richarte:
"Design and implementation of Bee Smalltalk Runtime"
http://esug.org/data/ESUG2014/IWST/Papers/iwst2014_Design%20and%20implementation%20of%20Bee%20Smalltalk%20Runtime.pdf

Robert Hieb, R. Kent Dybvig, Carl Bruggeman:
"Representing Control in the Presence of First-Class Continuations"
https://legacy.cs.indiana.edu/~dyb/pubs/stack.pdf

Eliot Miranda: "Under Cover Contexts and the Big Frame-Up"
http://www.mirandabanda.org/cogblog/2009/01/14/under-cover-contexts-and-the-big-frame-up/

Eliot Miranda: "Context Management in VisualWorks 5i"
http://www.esug.org/data/Articles/misc/oopsla99-contexts.pdf

### Spur Object Format

Clément Béra: "Spur’s new object format"
https://clementbera.wordpress.com/2014/01/16/spurs-new-object-format/

Eliot Miranda: "A Spur gear for Cog"
http://www.mirandabanda.org/cogblog/2013/09/05/a-spur-gear-for-cog/

Eliot Miranda, Clément Béra:
"A Partial Read Barrier for Eﬀicient Support of Live
 Object-oriented Programming"
https://hal.inria.fr/hal-01152610/file/partialReadBarrier.pdf

### Possible future direction of these notes:

_Smalltalk All the Way Down: An Implementers Guide_

