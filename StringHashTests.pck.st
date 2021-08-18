'From Cuis 5.0 [latest update: #4763] on 18 August 2021 at 4:32:59 pm'!
'Description String Hash Function candidates and trials'!
!provides: 'StringHashTests' 1 13!
SystemOrganization addCategory: #StringHashTests!


!classDefinition: #HashCandidates category: #StringHashTests!
String variableByteSubclass: #HashCandidates
	instanceVariableNames: ''
	classVariableNames: 'ReportFlags'
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

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/18/2021 16:29:04'!
globalCollisionsCounts
	"Find Best Hashes across all methodDictionaries"

	| hashfuns results collisions |
	hashfuns := 
		{
		  String>>#hash.
		  ProtoObject>>#identityHash.
		  String>>#hash0.
		  String>>#hash1.
		  String>>#hash2.
		  String>>#hash3.
		  String>>#hash4.
		  }.
	results := hashfuns collect: [ :hfun | 
		HashCandidates allSelectorsStatsForHashMethod: hfun 
	 ].
	collisions := results collect: [ :hashStats | "array of {className, mDictSize, histogram}"
		self collisionsFromStats: hashStats.
	].

	(self hasFlag: $H)
		ifTrue: [
			1 to: hashfuns size do: [ :idx |
				Transcript log: '#', 
						(hashfuns at: idx) selector asString,
						' collisions = ', (collisions at: idx) asString
			]
		].

	^collisions 
	
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/18/2021 15:20:41'!
globalCompare
	"Find Best Hashes across all methodDictionaries"

	| hashfuns results winner |
	hashfuns := 
		{
		  String>>#hash4.
		  String>>#hash.
		  String>>#hash3.
		  ProtoObject>>#identityHash.
		  String>>#hash0.
		  String>>#hash2.
		  String>>#hash1.
		  }.
	results := hashfuns collect: [ :hfun | 
		HashCandidates allSelectorsStatsForHashMethod: hfun 
	 ].
	(self hasFlag: $H)
		ifTrue: [Transcript log: 'HashFun count = ', results size asString].

	winner := results at: 1.
	2 to: results size do: [ :idx2 | 
		(self hasFlag: $B) ifTrue: [
			 Transcript 
				log: 'hashA= #', 
					(hashfuns at: (results indexOf: winner)) selector asString,
					' ,   hashB= #',
					(hashfuns at: idx2) selector asString.
		].
		winner := HashCandidates 
					histCollectionBestBetween: winner 
					and: (results at: idx2).
 
	].
	^(hashfuns at: (results findFirst: [ :val | val = winner])) selector
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

!HashCandidates class methodsFor: 'hashstats' stamp: 'KenD 8/18/2021 16:25:32'!
collisionsFromStats: hashStats
	"hashStats is array of {className, mDictSize, histogram}"
	^hashStats inject: 0 
			   into: [ :count :stat | count + (self collisionsFromHIstogram: (stat at: 3) )]! !

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

!HashCandidates class methodsFor: 'class initialization' stamp: 'KenD 8/18/2021 12:33:11'!
initialize
	"self initialize"
	
	ReportFlags := ''.  "String treated as a set of character flags"! !

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

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/17/2021 16:44:24'!
hash1
	"Knuth"

	| result |
	result := 0.
	self do: [ :char |
		result := result * 31.
		result := result + char asciiValue 
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

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/17/2021 16:52:00'!
hash3
	"RSHash"

	| result |
	result := 0.
	self do: [ :char |
		result := (result * 127) + char asciiValue 
	].
	^ result bitAnd: 16rFFFFFFF! !

!String methodsFor: '*stringhashtests' stamp: 'KenD 8/17/2021 16:57:57'!
hash4
	"UHash"

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
HashCandidates initialize!
