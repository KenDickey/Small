'From Cuis 5.0 [latest update: #4749] on 17 August 2021 at 8:07:33 pm'!
'Description String Hash Function candidates and trials'!
!provides: 'StringHashTests' 1 6!
SystemOrganization addCategory: 'StringHashTests'!


!classDefinition: #HashCandidates category: 'StringHashTests'!
String variableByteSubclass: #HashCandidates
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'StringHashTests'!
!classDefinition: 'HashCandidates class' category: 'StringHashTests'!
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

!HashCandidates class methodsFor: 'comparing' stamp: 'KenD 8/17/2021 20:03:35'!
histCollectionBestBetween: collA and: collB
	"collA and collB are collections of (className,mDictSize,histogram).  Pick the best one"
	| countA countB |
	(collA size = collB size) ifFalse: [ self error: 'unequal collections'].
	countA := countB := 0.
	1 to: collA size do: [ :index |
		"#{classname, tableSize, histogram}"
		(HashCandidates  histogram: ((collA at: index) at: 3) 
						lessThan:   ((collB at: index) at: 3))
			ifTrue: [ countA := countA + 1 ]
		 	ifFalse: [ countB := countB+ 1 ]
	].
	(countA > countB)
		ifTrue:  [^collA]  
		ifFalse: [^collB]
	! !

!HashCandidates class methodsFor: 'comparing' stamp: 'KenD 8/17/2021 20:05:52'!
histogram: histA lessThan: histB
	"Given two histograms, return a < b is a is better"
	(histA size < histB size) ifTrue: [^ true ].
	(histB size < histA size) ifTrue: [^ false].

	1 to: (histA size) do: [ :index |
		(histA at: index) < (histB at: index) ifTrue: [^true ].
		(histB at: index) < (histA at: index) ifTrue: [^false].
	].
	^false "Same"
! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/17/2021 18:28:46'!
allSelectorsStatsForHashMethod: aCompiledMethod
	"{aClass printString. tableSize. histogram}"
	
	| selectorInfos |
	selectorInfos := Smalltalk allClasses 
		collect:  [ :aClass | HashCandidates hashSelectorsFor: aClass hashMethod: aCompiledMethod ].
	
	^selectorInfos ! !

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/17/2021 20:06:58'!
globalCompare
	"Find Best Hashes across all methodDictionaries"

	| hashfuns results winner |
	hashfuns := 
		{String>>#hash.
		  ProtoObject>>#identityHash.
		  String>>#hash0.
		  String>>#hash1.
		  String>>#hash2.
		  String>>#hash3.
		  String>>#hash4.}.
	results := hashfuns collect: [ :hfun | HashCandidates allSelectorsStatsForHashMethod: hfun ].
	winner := results 
				inject: (results at: 1) 
				into: [ :best :next | HashCandidates histCollectionBestBetween: best and: next ].
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

!HashCandidates class methodsFor: 'perform hashes' stamp: 'KenD 8/17/2021 15:03:37'!
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
	countsArray do: [ :count | histogram at: count+1 put: (1 + histogram at: count+1)].
	^ {aClass printString. tableSize. histogram}
	
	! !

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
