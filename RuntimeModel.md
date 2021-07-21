# Runtime Model

Smalltalk is meant to be a small and simple language.
The syntax is minimal and basic opearations consist of Message Send, Return, and Assignment.
Smalltalk Objects hold values, receive and send messages.
The Wikipedia.org page on Smalltalk had a good description of this.

Mapping from the source language, Smalltalk, to the target machine, RISC-V RV64G,
means comparing the two world views and concentrating on the differences.
[Note "Realisitic Compilation by Program Transformation", Kelsey & Hudak, 1989]
(https://hashingit.com/elements/research-resources/1989-01-realistic-compilation-by-program-transformation.pdf)
[RV64GC Specs: (https://riscv.org/technical/specifications/)] 

Smalltalk is also well known for maintaining the dual view of the relation
between text source and machine binary runtime and displaying machine state
in comprhensible ways.
["Design Principles Behind Smalltalk", Dan Ingalls, 1981]
(http://www.cs.virginia.edu/~evans/cs655/readings/smalltalk.html)

## Runtime Globals

There exists a vector/array of objects known as the Known Objects Array.

One known object is the SystemDictionary named #Smalltalk.

Basically, all globals known to code are either local values
(Instance Variables or Method Temporaries) or are names in the Smalltalk Dictionary.

## Registers & Stack

We will use more registers, but stack layout is patterned after the Bee DMR.
http://esug.org/data/ESUG2014/IWST/Papers/iwst2014_Design%20and%20implementation%20of%20Bee%20Smalltalk%20Runtime.pdf 

RISC-V Stack grows down and is quadword aligned.
Stack records are between the chained FramePointer regs, which point to base of stack frame, and the StackPointer itself.

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
- StackLimit in S8
- KnownObjects base in S9

### Stack Layout
```
    Stack Object Header
    ..
    ..    
    ^
    ^--<OlderFP -----<
	temp...      ^
	Env          ^
        Method       ^
	Receiver     ^
FP--->  PreviousFP>--^
	ReturnAddress
	...
        arg9
SP--->  arg8
```

Note: to interpret/convert frames into Context objects requires tracking spills and registers.


## Object Layout Format

All the machine knows are bits, either in memory or registers.

Smalltalk Objects are represented as either
_Immediate Values_, those which fit in a machine register,
or
_Vector-Like Objects_, an array, the first part of which is a Header,
which encodes clues to its size and structure) and an optional part which is
interpreted either as Smalltalk Objects (A compact array of Slots) or
binary data (e.g. a ByteVector).

Typically, there is a first Slot in a Vector-Like Object which is a pointer
to either its Class Object or a Behavior object.  Here we use a Behavior object
which is basically a _Method Dictionary_, a Dictionary of (Symbol -> Method).

Key ideas: Horizontal vs Vertical Encoding and Hashing.

_Dictionarys_ map _Keys_ to _Values_.
Each Smalltalk object responds to a method #hash which reponds with a SmallInteger
which is used to shorten key lookup time. [https://en.wikipedia.org/wiki/Hash_table]

_Horizontal Encoding_ maps categories to bits which can be tested individually,
e.g. (#sphere->1, #cube->2, #ball->4, #rectangel->8, #square->16).
This is used where there are few
categories and an object may be classified in 
multiple categories (e.g. Sphere+Ball, Square+Rectangle)

_Vertical Encoding_ are just consecutive numbers and may be used where there are many categories,
each of which is distinct from all others.
E.g. (#triangle->4, #rectangle->4, #pentagram->5, #hexagram->6)

Pointer addresses end in 2r00.  If we follow Bee DMR, SmallIntegers are 31 bits left shifted
one and bit0 set to 1.

Immediate values are just OOP addresses near zero.  
These are known by their small values.
These are easy to create, so do not need dedicated registers to hold their values.

- UndefinedObject/Nil = 2r0000  [So matches register ZERO = x0]
- True  = 2r0100
- False = 2r1000
- ...

## Object Headers

Bee Header (simple) or Spur (refined) ?? TBD

## Message Invocation

After Bee, we separate lookup from invocation.

Lookup takes an object, the receiver, and a selector and finds either
the requisite method or substitutes a DNU.

[Decision: Debug: Reserve a temp reg for selector or recover from method?]

Registers reserved for method lookup.. 
- A0=Receiver
- temp0 for Selector?
- other temps for hash & dict lookup? TBD

## PICs

## Contexts & Exceptions

## Optimization Ideas

Make "type tests" visible to be "lifted out" or "propagated forward".
I.e. in a Method, if the first send does a check for an argument being a SmallInteger,
if the test passed, then no other sends need to re-check for this object again.
All succeeding SmallInteger tests can be elided (the tested object's "type" 
has become resolved).

