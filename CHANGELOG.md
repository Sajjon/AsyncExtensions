Make these AsyncSequences Sendable (if Element or Upstream is Sendable):
* Empty
* FAil
* From
* Just
* Merge
* Zip, Zip2, Zip3


**v0.4.0 - Bore:**

- AsyncStreams: new @Streamed property wrapper
- AsyncSequences: finish Timer when canceled

**v0.3.0 - Beryllium:**

- Operators: new Share operator
- AsyncSequences: new Timer AsyncSequence
- AsyncStreams: `send()` functions are now synchronous

**v0.2.1 - Lithium:**

- Enforce the call of onNext in a determinitisc way

**v0.2.0 - Helium:**

- AsyncStreams.CurrentValue `element` made public and available with get/set
- new Multicast operator
- new Assign operator

**v0.1.0 - Hydrogen:**

- Implements the first set of extensions
