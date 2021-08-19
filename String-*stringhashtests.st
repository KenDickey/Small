'From Cuis 5.0 [latest update: #4763] on 19 August 2021 at 2:24:37 pm'!


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
