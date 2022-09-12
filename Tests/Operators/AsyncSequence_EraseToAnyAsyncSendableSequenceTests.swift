//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-09-12.
//

import AsyncExtensions
import XCTest

final class AsyncSequence_EraseToAnyAsyncSendableSequenceTests: XCTestCase {
    func testAnyAsyncSendableSequence_gives_sames_values_as_original_sequence() async throws {
        let expectedValues = (0...4).map { _ in Int.random(in: 0...100) }
        var receivedValues = [Int]()

        // `AsyncFromSequence` is `Sendable`
        let baseSequence = expectedValues.asyncElements
        let sut = baseSequence.eraseToAnyAsyncSendableSequence()

        for try await element in sut {
            receivedValues.append(element)
        }

        XCTAssertEqual(receivedValues, expectedValues)
    }
    
    func testAnyAsyncSendableSequence_can_be_used_on_sendable_async_sequence() async throws {
        let expectedValues = (0...4).map { _ in Int.random(in: 0...100) }
        var receivedValues = [Int]()

        // `AsyncFromSequence` is `Sendable`
        let baseSequence = expectedValues.asyncElements
        let asyncFromSequence = baseSequence.eraseToAnyAsyncSendableSequence()
        // turn Sendable `AsyncFromSequence` into non-Sendable `AnyAsyncSequence`
        let nonSendableSequence = asyncFromSequence.eraseToAnyAsyncSequence()
        // Prove we can turn a non-Sendable to Sendable, works because `Element` of type
        // `Int` is Sendable and `AnyAsyncSendableSequence` does not require `BaseAsyncSequence`
        // to be Sendable.
        let sut = nonSendableSequence.eraseToAnyAsyncSendableSequence()

        for try await element in sut {
            receivedValues.append(element)
        }

        XCTAssertEqual(receivedValues, expectedValues)
    }
}

