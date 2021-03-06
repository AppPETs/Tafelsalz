import XCTest
@testable import Tafelsalz

func KMAssertEqual(_ lhs: KeyMaterial, _ rhs: KeyMaterial) {
	XCTAssertEqual(lhs.copyBytes(), rhs.copyBytes())
}

func KMAssertNotEqual(_ lhs: KeyMaterial, _ rhs: KeyMaterial) {
	XCTAssertNotEqual(lhs.copyBytes(), rhs.copyBytes())
}

class KeyMaterialTest: XCTestCase {

	// MARK: - Meta tests

	static func metaTestDefaultInitializer<T: KeyMaterial, E: Equatable>(
		of fixedSizeInBytes: UInt32,
		eq: (T) -> E,
		with initializer: () -> T
	) {
		let instance1 = initializer()

		// Test expected size limitation
		XCTAssertEqual(instance1.sizeInBytes, fixedSizeInBytes)

		// Test reflexivity
		XCTAssertEqual(eq(instance1), eq(instance1))

		// Test uniqueness after initialization
		XCTAssertNotEqual(eq(instance1), eq(initializer()))
	}

	static func metaTestCapturingInitializer<T: KeyMaterial, E: Equatable>(
		minimumSizeInBytes: UInt32,
		maximumSizeInBytes: UInt32,
		eq: (T) -> E,
		with initializer: (inout Bytes) -> T?
	) {
		let sizesInBytes = (minimumSizeInBytes == maximumSizeInBytes) ? [minimumSizeInBytes] : [minimumSizeInBytes, maximumSizeInBytes]
		for sizeInBytes in sizesInBytes {
			let expectedBytes = Random.bytes(count: sizeInBytes)
			var bytes = Bytes(expectedBytes)
			let optionalInstance = initializer(&bytes)

			// Test creating instance from byte sequence with correct size
			XCTAssertNotNil(optionalInstance)

			let instance = optionalInstance!

			// Test expected size limitation
			XCTAssertEqual(instance.sizeInBytes, sizeInBytes)

			// Test equality of byte sequences
			XCTAssertEqual(instance.copyBytes(), expectedBytes)

			// Test that passed argument is zeroed
			XCTAssertEqual(bytes, Bytes(count: Int(sizeInBytes)))

			XCTAssertEqual(eq(instance), eq(instance))
		}

		// Test creating instance from byte sequence with incorrect size
		var tooShort = Random.bytes(count: minimumSizeInBytes - 1)
		var tooLong = Random.bytes(count: maximumSizeInBytes + 1)

		XCTAssertNil(initializer(&tooShort))
		XCTAssertNil(initializer(&tooLong))

		// Test if arguments passed have been wiped unexpectedly
		XCTAssertNotEqual(tooShort, Bytes(count: tooShort.count))
		XCTAssertNotEqual(tooLong, Bytes(count: tooLong.count))
	}

	static func metaTestCapturingInitializer<T: KeyMaterial, E: Equatable>(
		of fixedSizeInBytes: UInt32,
		eq: (T) -> E,
		with initializer: (inout Bytes) -> T?
	) {
		metaTestCapturingInitializer(minimumSizeInBytes: fixedSizeInBytes, maximumSizeInBytes: fixedSizeInBytes, eq: eq, with: initializer)
	}

	static func metaTestEquality<T: KeyMaterial>(
		of fixedSizeInBytes: UInt32,
		withCapturingInitializer initializer: (inout Bytes) -> T?
	) {
		let bytes = Random.bytes(count: fixedSizeInBytes)
		let otherBytes = Random.bytes(count: fixedSizeInBytes)
		var tmpBytes1 = Bytes(bytes)
		var tmpBytes2 = Bytes(bytes)
		var tmpBytes3 = Bytes(otherBytes)
		let keyMaterial1 = initializer(&tmpBytes1)!
		let keyMaterial2 = initializer(&tmpBytes2)!
		let keyMaterial3 = initializer(&tmpBytes3)!

		// Reflexivity
		XCTAssertTrue(keyMaterial1.isEqual(to: keyMaterial1))
		XCTAssertTrue(keyMaterial1.isFingerprintEqual(to: keyMaterial1))

		// Symmetry
		XCTAssertTrue(keyMaterial1.isEqual(to: keyMaterial2))
		XCTAssertTrue(keyMaterial2.isEqual(to: keyMaterial1))
		XCTAssertTrue(keyMaterial1.isFingerprintEqual(to: keyMaterial2))
		XCTAssertTrue(keyMaterial2.isFingerprintEqual(to: keyMaterial1))

		// Inequality due to different byte sequences
		XCTAssertFalse(keyMaterial1.isEqual(to: keyMaterial3))
		XCTAssertFalse(keyMaterial3.isEqual(to: keyMaterial1))
		XCTAssertFalse(keyMaterial1.isFingerprintEqual(to: keyMaterial3))
		XCTAssertFalse(keyMaterial3.isFingerprintEqual(to: keyMaterial1))
	}

	// MARK: - Tests

	func testDefaultInitializer() {
		let sizeInBytes: UInt32 = 32

		KeyMaterialTest.metaTestDefaultInitializer(of: sizeInBytes, eq: { $0.copyBytes() }) { KeyMaterial(sizeInBytes: sizeInBytes) }
	}

	func testCapturingInitializer() {
		let sizeInBytes: UInt32 = 32

		KeyMaterialTest.metaTestCapturingInitializer(of: sizeInBytes, eq: { $0.copyBytes() }) {
			UInt32($0.count) == sizeInBytes ? KeyMaterial(bytes: &$0) : nil
		}
	}

	func testEquality() {
		let sizeInBytes: UInt32 = 32

		KeyMaterialTest.metaTestEquality(of: sizeInBytes) { KeyMaterial(bytes: &$0) }

		// Inequality due to different lengths
		var moreBytes = Random.bytes(count: sizeInBytes + 1)
		var lessBytes = moreBytes[..<Int(sizeInBytes)].bytes
		let more = KeyMaterial(bytes: &lessBytes)!
		let less = KeyMaterial(bytes: &moreBytes)!

		// Inequality can only be tested via fingerprints, see documentation.
		XCTAssertFalse(more.isFingerprintEqual(to: less))
		XCTAssertFalse(less.isFingerprintEqual(to: more))
	}

}
