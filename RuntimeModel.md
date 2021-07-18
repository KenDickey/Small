# Runtime Model

Smalltalk is meant to be a small and simple language.
The syntax is simple and basic opearations consist of Message Send, Return, and Assignment.
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

One known object is the SystemDictinary named #Smalltalk.

Basically, all globals known to code are either local values
(Instance Variables or Method Temporarys) or are names in the Smalltalk Dictionary.

## Registers & Stack

## Object Layout Format

All the machine knows are bits, either in memory or registers.

Smalltalk Objects are represented as either
Immediate Values, those which fit in a machine register,
or
Vector-Like Objects, an array, the first part of which is a Header,
which encodes clues to its size and structure) and an optional part which is
interpreted either as Smalltalk Objects (A compact array of Slots) or
binary data (e.g. a ByteVector).

Typically, there is a first Slot in a Vector-Like Object which is a pointer
to either its Class Object or a Behavior object.  Here we use a Behavior object
which is basically a Method Dictionary, a Dictionary of (Symbol -> Method).

Key ideas: Horizontal vs Vertical Encoding and Hashing.

Dictionarys map Keys to Values.
Each Smalltalk object responds to a method #Hash which reponds with a SmallInteger
which is used to shorten lookup time. [Wikipedia.org]

Horizontal encoding maps categories to bits which can be tested individually,
e.g. (#sphere->1, #cube->2, #ball->4, #rectangel->8, #square->16).
This is used where there are few
categories and an object may be classified in 
multiple categories (e.g. Sphere+Ball, Square+Rectangle)

Vertical Encodings are just numberings and may be used where there are many categories,
each of which is distinct from all others.
E.g. (#triangle->4, #rectangle->4, #pentagram->5, #hexagram->6)


## Message Invocation

## PICs

