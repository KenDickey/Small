'From Cuis 5.0 [latest update: #4763] on 20 August 2021 at 2:01:34 pm'!
'Description String Hash Function candidates and trials'!
!provides: 'StringHashTests' 1 15!
SystemOrganization addCategory: #StringHashTests!


!classDefinition: #HashCandidates category: #StringHashTests!
String variableByteSubclass: #HashCandidates
	instanceVariableNames: ''
	classVariableNames: 'ReportFlags StringHashFuns'
	poolDictionaries: ''
	category: 'StringHashTests'!
!classDefinition: 'HashCandidates class' category: #StringHashTests!
HashCandidates class
	instanceVariableNames: ''!


!HashCandidates commentStamp: '<historical>' prior: 0!
Possible symbol hashes for trial.

Basic idea is that a Selector is a Symbol with an extra 64bit binary field
which is similar in structure to the Spur header format.

This gives space for two 22bit hash values plus another 20 bits for a
unique selector ID (1 Mi selectors).

After methods are added, a MethodDictionary can then check to see which of 4 hashes
(hash, identityHash, + 2 new) gives best lookup results (fewest collisions).  

As the ClassID of a MethodDictionary is its index in the class table is its hash, one
can just change the ClassID & Hash in the header to switch between the 4
MethodDictionary lookup choices, so the desired hash is used in Selector lookup.

As Selector hashes are calculated when methods are compiled, they do NOT have 
to be fast..
!

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/18/2021 13:11:53'!
allSelectorsStatsForHashMethod: aCompiledMethod
	"{aClass printString. tableSize. histogram}"
	
	| selectorInfos |
	selectorInfos := Smalltalk allClasses 
		collect:  [ :aClass | HashCandidates 
						hashSelectorsFor: aClass 
						hashMethod: aCompiledMethod ].
	(self hasFlag: $S)
		ifTrue: [Transcript log: 'AllClasses count = ', selectorInfos size asString].	
	^selectorInfos ! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/19/2021 13:28:34'!
globalCollisionsCounts
	"Find Best Hashes across all methodDictionaries"
	| results collisions |

	results := StringHashFuns collect: [ :hfun | 
		HashCandidates allSelectorsStatsForHashMethod: hfun 
	 ].
	collisions := results collect: [ :hashStats | "array of {className, mDictSize, histogram}"
		self collisionsFromStats: hashStats.
	].

	(self hasFlag: $H)
		ifTrue: [
			1 to: StringHashFuns size do: [ :idx |
				Transcript log: '#', 
						(StringHashFuns at: idx) selector asString,
						' collisions = ', (collisions at: idx) asString
			]
		].

	^collisions 
	
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/19/2021 13:29:19'!
globalCompare
	"Find Best Hashes across all methodDictionaries"
	| results winner |

	results := StringHashFuns collect: [ :hfun | 
		HashCandidates allSelectorsStatsForHashMethod: hfun 
	 ].
	(self hasFlag: $H)
		ifTrue: [Transcript log: 'HashFun count = ', results size asString].

	winner := results at: 1.
	2 to: results size do: [ :idx2 | 
		(self hasFlag: $B) ifTrue: [
			 Transcript 
				log: 'hashA= #', 
					(StringHashFuns at: (results indexOf: winner)) selector asString,
					' ,   hashB= #',
					(StringHashFuns at: idx2) selector asString.
		].
		winner := HashCandidates 
					histCollectionBestBetween: winner 
					and: (results at: idx2).
 
	].
	^(StringHashFuns at: (results findFirst: [ :val | val = winner])) selector
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/20/2021 13:33:17'!
globalHashNoTiePattern
	"Return cases of win ties across hashes"
	| tiePattern  |

	tiePattern := OrderedCollection new.
	Smalltalk allClassesDo: [ :aClass | | collisions minCollision ties tieCount |
		collisions := StringHashFuns collect: 
			[ :hfun |  self collisionsFromHIstogram: 
					((self hashSelectorsFor: aClass hashMethod: hfun) at: 3)].
		minCollision := 
			collisions 
				inject: 500
				into: [ :minCollide :nextCollide | 
						minCollide min: nextCollide].
		tieCount := 0.
		ties := collisions collect: [ :c | (c = minCollision) 
						ifTrue: [tieCount := tieCount + 1. 1] 
						ifFalse: [0]
		].
		(tieCount > 1) ifFalse: [ tiePattern addLast: ties ].
	 ].

	^tiePattern
	
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/20/2021 13:25:02'!
globalHashTiePattern
	"Return cases of win ties across hashes"
	| tiePattern  |

	tiePattern := OrderedCollection new.
	Smalltalk allClassesDo: [ :aClass | | collisions minCollision ties tieCount |
		collisions := StringHashFuns collect: 
			[ :hfun |  self collisionsFromHIstogram: 
					((self hashSelectorsFor: aClass hashMethod: hfun) at: 3)].
		minCollision := 
			collisions 
				inject: 500
				into: [ :minCollide :nextCollide | 
						minCollide min: nextCollide].
		tieCount := 0.
		ties := collisions collect: [ :c | (c = minCollision) 
						ifTrue: [tieCount := tieCount + 1. 1] 
						ifFalse: [0]
		].
		(tieCount > 1) ifTrue: [ tiePattern addLast: ties ].
	 ].

	^tiePattern
	
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/20/2021 13:05:27'!
globalHashWinCounts
	"Count Hash wins across all methodDictionaries.
	 Win -> minimum hash collisions within a methodDictionary"
	| wins |

	wins := Array new: StringHashFuns size withAll: 0.
	Smalltalk allClassesDo: [ :aClass | | collisions minCollision |
		collisions := StringHashFuns collect: 
			[ :hfun |  self collisionsFromHIstogram: 
					((self hashSelectorsFor: aClass hashMethod: hfun) at: 3)].
		minCollision := 
			collisions 
				inject:  500
				into: [ :minCollide :nextCollide | 
						minCollide min: nextCollide].
		1 to: StringHashFuns size do: [ :index | 
			(minCollision = (collisions at: index)) 
				"May be multiple winners with least collisions"
				ifTrue: [ wins at: index put: (1 + wins at: index)].
		]
	 ].

	(self hasFlag: $H)
		ifTrue: [
			1 to: StringHashFuns size do: [ :idx |
				Transcript log: '#', 
						(StringHashFuns at: idx) selector asString,
						' win count = ', (wins at: idx) asString
			]
		].

	^wins 
	
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/17/2021 15:56:15'!
hashSelectorsFor: aClass
	"For each hash function, want results of hashing as number of collisions"
	| mDict tableSize countsArray histogram |
	mDict := aClass methodDict.
	tableSize := mDict basicSize.
	countsArray := Array new: tableSize withAll: 0.
	"Current hash"
	mDict keysDo: [ :selector | | index |
		index := (selector identityHash \\ tableSize) + 1.
		countsArray at: index put: (1 + countsArray at: index)
	].
	"Histogram of Results"
	histogram := Array new: 1 +
						(countsArray 
							inject: 0
							into: [:maxSoFar :next | maxSoFar max: next]) 
					withAll: 0.
	countsArray do: [ :count | histogram at: count+1 put: (1 + histogram at: count+1)].
	"histogram at: 0 -> number of empty slots
	 histogram at: 1 -> number of inserts with no collisions
	 shorter histograms -> fewer multi-collisions
	"
	^ {aClass printString. tableSize. histogram}
	
	! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/18/2021 13:40:15'!
hashSelectorsFor: aClass hashMethod: aCompiledMethod
	"For each hash function, want results of hashing as number of collisions"
	| mDict tableSize countsArray histogram |
	mDict := aClass methodDict.
	tableSize := mDict basicSize.
	countsArray := Array new: tableSize withAll: 0.
	"Current hash"
	mDict keysDo: [ :selector | | index |
		index := ((aCompiledMethod  valueWithReceiver: selector arguments: {})
					 \\ tableSize) + 1.
		countsArray at: index put: (1 + countsArray at: index)
	].
	"Histogram of Results"
	histogram := Array new: 1 +
						(countsArray 
							inject: 0
							into: [:maxSoFar :next | maxSoFar max: next]) 
					withAll: 0.
	countsArray do: [ :count | 
		histogram at: count+1 put: (1 + histogram at: count+1)
	].
	(self hasFlag: $D)
		ifTrue: [Transcript 
				log:  aClass printString,
					', mDict size=', tableSize asString,
					' ', aCompiledMethod selector asString,
					' ', histogram printString
		].	

	^ {aClass printString. tableSize. histogram}
	
	! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/18/2021 13:44:33'!
rawHashSelectorsFor: aClass hashMethod: aCompiledMethod
	"For each hash function, want results of hashing as number of collisions"
	| mDict tableSize countsArray |
	mDict := aClass methodDict.
	tableSize := mDict basicSize.
	countsArray := Array new: tableSize withAll: 0.
	"Current hash"
	mDict keysDo: [ :selector | | index |
		index := ((aCompiledMethod  valueWithReceiver: selector arguments: {})
					 \\ tableSize) + 1.
		countsArray at: index put: (1 + countsArray at: index)
	].
	^countsArray ! !

!HashCandidates class methodsFor: 'notes' stamp: 'KenD 8/17/2021 17:10:46'!
djbernstein
	^'
  Daniel J. Bernstein:  see  String>>#hash0
  DJBX33A (Daniel J. Bernstein, Times 33 with Addition)
 
  This is Daniel J. Bernstein''s popular "times 33" hash function as
  posted by him years ago on comp.lang.c. It basically uses a function
  like ``hash(i) = hash(i-1)  33 + string[i]''. This is one of the
  best hashing functions for strings. Because it is both computed very
  fast and distributes very well.
 
  The magic of the number 33, i.e. why it works better than many other
  constants, prime or not, has never been adequately explained by
  anyone. So I try an own RSE-explanation: if one experimentally tests
  all multipliers between 1 and 256 (as I did it) one detects that
  even numbers are not useable at all. The remaining 128 odd numbers
  (except for the number 1) work more or less all equally well. They
  all distribute in an acceptable way and this way fill a hash table
  with an average percent of approx. 86%.
 
  If one compares the Chi/2 values resulting of the various
  multipliers, the 33 not even has the best value. But the 33 and a
  few other equally good values like 17, 31, 63, 127 and 129 have
  nevertheless a great advantage over the remaining values in the large
  set of possible multipliers: their multiply operation can be replaced
  by a faster operation based on just one bit-wise shift plus either a
  single addition or subtraction operation. And because a hash function
  has to both distribute good and has to be very fast to compute, those
  few values should be preferred and seems to be also the reason why
  Daniel J. Bernstein also preferred it.
 
  Lawsuit here:
  http://epic.org/crypto/export_controls/bernstein_decision_9_cir.html
 
'! !

!HashCandidates class methodsFor: 'notes' stamp: 'KenD 8/17/2021 17:07:23'!
probes
	
	^' Both String>>hash and hash0 beat identityHash
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash.   "#(String 512 #(330 142 34 6)) "
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash0. "#(String 512 #(329 142 37 4)) "
HashCandidates hashSelectorsFor: String.  "Same as identityHash, next"  "#(String 512 #(337 133 33 7 2)) "
HashCandidates hashSelectorsFor: String hashMethod: ProtoObject>>#identityHash.
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash1.  "#(String 512 #(328 146 33 3 2)) "
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash2.  "#(String 512 #(332 139 33 7 1)) "
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash3.  "#(String 512 #(332 137 36 6 1)) "
HashCandidates hashSelectorsFor: String hashMethod: String>>#hash4.  "#(String 512 #(323 156 25 7 0 1)) "
'! !

!HashCandidates class methodsFor: 'hashstats' stamp: 'KenD 8/18/2021 16:21:08'!
collisionsFromHIstogram: histogram
"hist at: 1 is number of empty slots
 hist at: 2 is number of singletons in bucket (good)
 higher indices -> number of buckets with this number of collisions (increasingly bad) 
"	
	| count |
	count := 0.
	3 to: histogram size 
	   do: [ :idx | count := count + ((idx-2) * (histogram at: idx))].
	^count! !

!HashCandidates class methodsFor: 'hashstats' stamp: 'KenD 8/19/2021 12:59:03'!
collisionsFromStats: hashStats
	"hashStats is array of {className, mDictSize, histogram}"
	^hashStats inject: 0 
			   into: [ :count :stat | 
				count + (self collisionsFromHIstogram: (stat at: 3) )]! !

!HashCandidates class methodsFor: 'comparing' stamp: 'KenD 8/18/2021 15:40:04'!
histCollectionBestBetween: collA and: collB
	"collA and collB are arrays of {className,mDictSize,histogram}.  Pick the best one"
	| countA countB |
	(collA size = collB size) ifFalse: [ self error: 'unequal collections'].
	countA := countB := 0.
	1 to: collA size do: [ :index |
		"Array of {classname, tableSize, histogram}"
		(HashCandidates  histogram: ((collA at: index) at: 3) 
						lessThan:   ((collB at: index) at: 3))
			ifTrue:  [ countA := countA + 1 ] "A better"
		 	ifFalse: [ countB := countB+ 1 ]  "B Better"
	].
	(self hasFlag: $B)
		ifTrue: [
			 Transcript
				log: 'A better: ', countA asString; tab;
			 	log: 'B better: ', countB asString; newLine.
	].
	(countA > countB)
		ifTrue:  [^collA]  
		ifFalse: [^collB]
	! !

!HashCandidates class methodsFor: 'comparing' stamp: 'KenD 8/18/2021 16:01:35'!
histogram: histA lessThan: histB
	"Given two histograms, return (A < B) => A is better"
	| negValA negValB |
"Want Minimum number of Collisions"
"hist at: 1 is number of empty slots
 hist at: 2 is number of singletons in bucket (good)
 higher indices -> number of buckets with this number of collisions (increasingly bad) 
"
	negValA := negValB := 0.
	3 to: histA size do: [ :indx0 | negValA := negValA + ((indx0-2) * (histA at: indx0))].
	3 to: histB size do: [ :indx1 | negValB := negValB + ((indx1-2) * (histB at: indx1))].
	(self hasFlag: $N)
		ifTrue: [Transcript 
				log: 'negValA= ', negValA asString, ' negValB= ', negValB asString
		].
	^ (negValA <= negValB)  "True if A has fewer or same collisions than B"

! !

!HashCandidates class methodsFor: 'comparing' stamp: 'KenD 8/20/2021 13:39:55'!
patternCounts: arrayOfArray
	"Array of same length arrays, sum counts"
	| sums |
	sums := Array new: (arrayOfArray at: 1) size withAll: 0.
	arrayOfArray do: [ :counts |
		1 to: counts size do: [ :index | "mostly add zero, but so what?"
			sums at: index put: ((sums at: index) + (counts at: index))
		]
	].
	^sums! !

!HashCandidates class methodsFor: 'transcripting' stamp: 'KenD 8/18/2021 12:37:33'!
clearFlag: aChar

	ReportFlags := ReportFlags select: [ :char | char !!= aChar  ]! !

!HashCandidates class methodsFor: 'transcripting' stamp: 'KenD 8/18/2021 13:54:24'!
flagUsage
	^'Character Flag Set -> Report to Transcript
	$H -> HashFun count
	$S -> Selector''s Class count
	$B -> Best compare count
	$N -> NegValue for collisions
	$D -> Data (raw!!) {ClassName,size,histogram}
	'! !

!HashCandidates class methodsFor: 'transcripting' stamp: 'KenD 8/18/2021 12:33:38'!
hasFlag: aChar

	^ReportFlags includes: aChar! !

!HashCandidates class methodsFor: 'transcripting' stamp: 'KenD 8/18/2021 12:39:24'!
reportFlags
	"String treated as a set of flags; if present report to transcript"
	^ReportFlags! !

!HashCandidates class methodsFor: 'transcripting' stamp: 'KenD 8/18/2021 12:30:32'!
setFlag: aChar

	(ReportFlags includes: aChar)
		ifFalse: [ ReportFlags := ReportFlags , aChar asString ]! !

!HashCandidates class methodsFor: 'class initialization' stamp: 'KenD 8/19/2021 14:02:57'!
initialize
	"self initialize"
	
	ReportFlags := ''.  "String treated as a set of character flags"
	StringHashFuns :=
		{
		  String>>#hash.
		  ProtoObject>>#identityHash.
		  String>>#hash0.
		  String>>#hash1.
		  String>>#hash2.
		  String>>#hash3.
		  String>>#hash4.
		  String>>#hash5.
		  String>>#hash6.
		  String>>#hash7.
		  String>>#hash8.
		  String>>#hash9.
		  String>>#hash10.
		  }.! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/17/2021 16:10:33'!
hash0
	"DJ1B1"

	| result |
	result := 0.
	self do: [ :char |
		result := result * 33.
		result := result + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:54:13'!
hash1
	"K&R"

	| result |
	result := 0.
	self do: [ :char |
		result := result * 31.
		result := result + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:59:46'!
hash10
	"FNVHash"

	| result |
	result := 2166136261. "offset32"
	self do: [ :char |
		result := result * 16777619. "prime32"
		result := result bitAnd: char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/17/2021 16:49:14'!
hash2
	"STLPort"

	| result |
	result := 0.
	self do: [ :char |
		result := (result * 5) + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:50:58'!
hash3
	"RSHashMod"

	| result |
	result := 0.
	self do: [ :char |
		result := (result * 127) + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:48:55'!
hash4
	"UHashMod"

	| result rand1 rand2 |
	result := 0.
	rand1 := 31415.
	rand2 := 27183.
	self do: [ :char |
		result := result * rand1.
		result := (result + char asciiValue).
		rand1 := rand1 * rand2.
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:43:54'!
hash5
	"PJWHash1"

	| result highBits|
	result := 0.
	self do: [ :char |
		result := result bitShift: 4.
		result := (result + char asciiValue).
		highBits := result bitAnd: 16rF0000000.
		(highBits = 0) ifFalse: [ 
			result := result bitAnd: (highBits bitShift: -24)
		].
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:48:13'!
hash6
	"RSHash"

	| result |
	result := 0.
	self do: [ :char | 
		result := result * 127.
		result := (result + char asciiValue) bitAnd: 16rFFFFFFF].
	
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:49:59'!
hash7
	"UHash"

	| result rand1 rand2 |
	result := 0.
	rand1 := 31415.
	rand2 := 27183.
	self do: [ :char |
		result := result * rand1.
		result := (result + char asciiValue) bitAnd: 16rFFFFFFF.
		rand1 := (rand1 * rand2) bitAnd: 16rFFFFFFF.
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:53:35'!
hash8
	"DJ1B2"

	| result |
	result := 5381.
	self do: [ :char |
		result := result bitShift: 5.
		result := result + result. "?Isn't this just one more left shift?"
		result := result + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/19/2021 13:56:47'!
hash9
	"Knuth"

	| result |
	result := self size.
	self do: [ :char |
		result := result bitShift: 5.
		result := result bitAnd: (result bitShift: -27).
		result := result bitAnd: char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !
HashCandidates initialize!
