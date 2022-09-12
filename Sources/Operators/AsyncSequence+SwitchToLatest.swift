//
//  AsyncSequence+SwitchToLatest.swift
//  
//
//  Created by Thibault Wittemberg on 04/01/2022.
//

import Foundation

public extension AsyncSequence where Element: AsyncSequence {
    /// Republishes elements sent by the most recently received async sequence.
    ///
    /// ```
    /// let sourceSequence = AsyncSequences.From([1, 2, 3])
    /// let mappedSequence = sourceSequence.map { element in ["a\(element)", "b\(element)"].asyncElements }
    /// let switchedSequence = mappedSequence.switchToLatest()
    ///
    /// for try await element in switchedSequence {
    ///     print(element)
    /// }
    ///
    /// // will print:
    /// a3, b3
    /// ```
    /// - parameter upstreamPriority: can be used to change the priority of the task that supports the iteration
    /// over the upstream sequence (nil by default)
    ///
    /// - Returns: The async sequence that republishes elements sent by the most recently received async sequence.
    func switchToLatest(upstreamPriority: TaskPriority? = nil) -> AsyncSwitchToLatestSequence<Self> {
        AsyncSwitchToLatestSequence<Self>(self, upstreamPriority: upstreamPriority)
    }
}

public struct AsyncSwitchToLatestSequence<UpstreamAsyncSequence: AsyncSequence>: AsyncSequence where UpstreamAsyncSequence.Element: AsyncSequence {
    public typealias Element = UpstreamAsyncSequence.Element.Element
    public typealias AsyncIterator = Iterator

    let upstreamAsyncSequence: UpstreamAsyncSequence
    let upstreamPriority: TaskPriority?

    public init(
        _ upstreamAsyncSequence: UpstreamAsyncSequence,
        upstreamPriority: TaskPriority?
    ) {
        self.upstreamAsyncSequence = upstreamAsyncSequence
        self.upstreamPriority = upstreamPriority
    }

    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(
            upstreamIterator: self.upstreamAsyncSequence.makeAsyncIterator(),
            upstreamPriority: self.upstreamPriority
        )
    }

    final class UpstreamIteratorManager {
        var upstreamIterator: UpstreamAsyncSequence.AsyncIterator
        var childIterators = [AsyncIteratorByRef<UpstreamAsyncSequence.Element.AsyncIterator>]()
        var hasStarted = false
        var currentTask: Task<Element?, Error>?

        let upstreamPriority: TaskPriority?
        let serialQueue = DispatchQueue(label: UUID().uuidString)

        init(
            upstreamIterator: UpstreamAsyncSequence.AsyncIterator,
            upstreamPriority: TaskPriority?
        ) {
            self.upstreamIterator = upstreamIterator
            self.upstreamPriority = upstreamPriority
        }

        func setCurrentTask(task: Task<Element?, Error>) {
            self.currentTask = task
        }

        /// iterates over the upstream sequence and maintain the current async iterator while cancelling the current .next() task for each new element
        func startUpstreamIterator() async throws {
            guard !self.hasStarted else { return }
            self.hasStarted = true

            if let firstChildSequence = try await self.upstreamIterator.next() {
                self.serialQueue.async { [weak self] in
                    self?.childIterators.append(AsyncIteratorByRef(iterator: firstChildSequence.makeAsyncIterator()))
                }
            }

            Task(priority: self.upstreamPriority) { [weak self] in
                while let nextChildSequence = try await self?.upstreamIterator.next() {
                    self?.serialQueue.async { [weak self] in
                        self?.childIterators.removeFirst()
                        self?.childIterators.append(AsyncIteratorByRef(iterator: nextChildSequence.makeAsyncIterator()))
                        self?.currentTask?.cancel()
                    }
                }
            }
        }

        func nextOnCurrentChildIterator() async throws -> Element? {
            let childIterator = self.serialQueue.sync { [weak self] in
                self?.childIterators.last
            }
            return try await childIterator?.next()
        }
    }

    public struct Iterator: AsyncIteratorProtocol {
        let upstreamIteratorManager: UpstreamIteratorManager

        init(
            upstreamIterator: UpstreamAsyncSequence.AsyncIterator,
            upstreamPriority: TaskPriority?
        ) {
            self.upstreamIteratorManager = UpstreamIteratorManager(
                upstreamIterator: upstreamIterator,
                upstreamPriority: upstreamPriority
            )
        }

        public mutating func next() async throws -> Element? {
            guard !Task.isCancelled else { return nil }

            var noValueHasBeenEmitted = true
            var emittedElement: Element?
            var currentTask: Task<Element?, Error>

            // starting the root iterator to be able to iterate in the first child iterator
            try await self.upstreamIteratorManager.startUpstreamIterator()
            let localUpstreamIteratorManager = self.upstreamIteratorManager

            // if a task is cancelled while waiting with the next element (a new element arrived in the root iterator)
            // we create a new task and wait for the elements from the new child iterator
            while noValueHasBeenEmitted {
                currentTask = Task {
                    do {
                        return try await localUpstreamIteratorManager.nextOnCurrentChildIterator()
                    } catch is CancellationError {
                        return nil
                    } catch {
                        throw error
                    }
                }
                localUpstreamIteratorManager.setCurrentTask(task: currentTask)
                emittedElement = try await currentTask.value
                noValueHasBeenEmitted = (emittedElement == nil && currentTask.isCancelled)
            }

            return emittedElement
        }
    }
}
extension AsyncSwitchToLatestSequence: Sendable where UpstreamAsyncSequence: Sendable {}
