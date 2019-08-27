/// This is copied from our own `MMMTemple` so we can have seedable random number generator here in the example without
/// depending on the corresponding library.
class PseudoRandomSequence: RandomNumberGenerator {

	private var last: UInt64

	public init(seed: Int) {

		self.last = UInt64(seed)

		// Discard a few values, so we don't begin too close to the seed.
		for _ in 1...7 {
			let _ = next()
		}
	}

	private func _next() -> UInt32 {
		// The multiplier and increment are from Turbo Pascal, see https://en.wikipedia.org/wiki/Linear_congruential_generator
		last = 134775813 &* last &+ 1
		return UInt32(truncatingIfNeeded: last >> 32)
	}

	public func next() -> UInt64 {
		return UInt64((UInt64(_next()) << 32) | UInt64(_next()))
	}
}
