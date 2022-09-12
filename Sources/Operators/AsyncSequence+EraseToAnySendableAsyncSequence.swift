//
//  AsyncSequence+EraseToAnySendableAsyncSequence.swift
//  
//
//  Created by Alexander Cyon on 12/09/2022.
//

public extension AsyncSequence where Element: Sendable {
    /// Type erase a Sendable AsyncSequence into an AnyAsyncSendableSequence.
    /// - Returns: A type erased Sendable AsyncSequence.
    func eraseToAnyAsyncSendableSequence() -> AnyAsyncSendableSequence<Element> {
        AnyAsyncSendableSequence(self)
    }
}

/// Type erased version of a Sendable AsyncSequence.
public struct AnyAsyncSendableSequence<Element: Sendable>: Sendable, AsyncSequence {
    public typealias Element = Element
    public typealias AsyncIterator = Iterator

    private let makeAsyncIteratorClosure: @Sendable () -> AsyncIterator

    public init<BaseAsyncSequence: Sendable & AsyncSequence>(_ baseAsyncSequence: BaseAsyncSequence) where BaseAsyncSequence.Element == Element {
        self.makeAsyncIteratorClosure = { Iterator(baseIterator: baseAsyncSequence.makeAsyncIterator()) }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(baseIterator: self.makeAsyncIteratorClosure())
    }

    public struct Iterator: Sendable, AsyncIteratorProtocol {
        final class BaseAsyncIteratorStorage<BaseAsyncIterator: AsyncIteratorProtocol> where BaseAsyncIterator.Element == Element {
            private var baseIterator: BaseAsyncIterator
            init(baseIterator: BaseAsyncIterator) {
                self.baseIterator = baseIterator
            }
            func next() async throws -> Element? {
                try await self.baseIterator.next()
            }
        }
        private let nextClosure: @Sendable () async throws -> Element?

        public init<BaseAsyncIterator: Sendable & AsyncIteratorProtocol>(baseIterator: BaseAsyncIterator) where BaseAsyncIterator.Element == Element {
            let baseIteratorStorage = BaseAsyncIteratorStorage(baseIterator: baseIterator)
            self.nextClosure = { try await baseIteratorStorage.next() }
        }

        public func next() async throws -> Element? {
            try await self.nextClosure()
        }
    }
}
