//
//  OrientationObserver.swift
//  OrientationObserver
//
//  Created by Jared Sinclair on 1/1/20.
//  Copyright © 2020 Nice Boy, LLC. All rights reserved.
//

import UIKit
import CoreMotion
import Combine

/// Observes device motion updates via CoreMotion, interpreting and publishing
/// those updates as UIInterfaceOrientation changes.
///
/// ## Usage
///
/// - When you're ready to receive updates, call `start()` on the observer.
/// - Receive updates using Combine subscriptions, e.g. `sink(_:)`. Updates are
///   published on the main queue (device motion processing is not).
/// - When you're finished, call `stop()`.
///
/// ## About CMMotionManager
///
/// Apple recommends that an application has no more than one CMMotionManager
/// in existence at any given time, across an entire process. If your app is
/// already using a CMMotionManager, you should provide it to an orientation
/// observer during initialization. Otherwise, OrientationObserver will fall
/// back to a private instance shared among all OrientationObservers.
public final class OrientationObserver: Publisher {

    // MARK: - Publisher (Typealiases)

    public typealias Output = UIInterfaceOrientation
    public typealias Failure = Never

    // MARK: - Constants

    enum Constants {
        static let debounceInterval = OperationQueue.SchedulerTimeType.Stride(1.0 / 30.0)
    }

    // MARK: - Private Statics

    /// Used to lock pushing/popping the instance count.
    private static let lock = NSLock()

    /// A tally of OrientationObservers in existing.
    private static var instanceCount = 0

    /// Used by any observer not initialized with an application-provided
    /// motion manager.
    private static let sharedManager = CMMotionManager()

    // MARK: - Private Properties

    /// Convenience to absolve us from implementing Publisher from scratch.
    private let publisher: AnyPublisher<UIInterfaceOrientation, Never>

    /// Convenience to absolve us from implementing Publisher from scratch.
    private let passthrough: PassthroughSubject<UIInterfaceOrientation, Never>

    /// If `true`, the developer provided an app-specific motion manager.
    private let didProvideCustomManager: Bool

    /// The resolved motion manager to use.
    private let motionManager: CMMotionManager

    /// Locks around pushing/popping `self` as an observer.
    private let lock = NSLock()

    /// A serial queue on which updates are processed.
    private let queue: OperationQueue

    /// Set to `true` when the observer is observing.
    private var isRunning = false

    /// Bag of cancellables.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Init / Deinit

    /// Designated initializer.
    ///
    /// - Note: See the "About CMMotionManager" section above for details.
    public init(applicationMotionManager: CMMotionManager? = nil) {
        motionManager = applicationMotionManager ?? OrientationObserver.sharedManager
        didProvideCustomManager = applicationMotionManager != nil
        let subject = PassthroughSubject<UIInterfaceOrientation, Never>()
        passthrough = subject
        publisher = subject
            .removeDuplicates()
            .receive(on: OperationQueue.main)
            .eraseToAnyPublisher()
        queue = {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            return queue
        }()
    }

    deinit {
        queue.cancelAllOperations()
        popObserver()
    }

    // MARK: - Public Methods

    /// Starts the motion manager and orientation updates.
    public func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager
            .publisher(for: \.deviceMotion)
            .debounce(for: Constants.debounceInterval, scheduler: queue)
            .sink { [weak self] motion in
                self?.deviceMotionChanged(to: motion)
            }
            .store(in: &subscriptions)
        pushObserver()
    }

    /// Stops the motion manager (unless other observers are still using it).
    ///
    /// - Note: if your app provides a custom motion manager, your app is
    /// responsible for also stopping the motion manager.
    public func stop() {
        popObserver()
    }

    // MARK: - Publisher (Methods)

    public func receive<S>(subscriber: S) where S : Subscriber, OrientationObserver.Failure == S.Failure, OrientationObserver.Output == S.Input {
        publisher.receive(subscriber: subscriber)
    }

    // MARK: - Private Methods (Static)

    /// Increments the observer count, starting the shared manager if needed.
    private static func pushObserver() {
        lock.lock()
        defer { lock.unlock() }
        instanceCount += 1
        if instanceCount == 1 {
            sharedManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
    }

    /// Decrements the observer count, stopping the shared manager if able.
    private static func popObserver() {
        lock.lock()
        defer { lock.unlock() }
        instanceCount = Swift.max(0, instanceCount - 1)
        if instanceCount == 0 {
            sharedManager.stopDeviceMotionUpdates()
        }
    }

    // MARK: - Private Methods (Instance)

    /// Increments the observer count, starting the shared manager if needed.
    private func pushObserver() {
        if didProvideCustomManager {
            if !motionManager.isDeviceMotionActive {
                motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            }
        } else {
            lock.lock()
            defer { lock.unlock() }
            guard !isRunning else { return }
            isRunning = true
            OrientationObserver.pushObserver()
        }
    }

    /// Decrements the observer count, stopping the shared manager if able.
    private func popObserver() {
        if didProvideCustomManager {
            // Do not stop motion updates. The application developer will do so.
        } else {
            lock.lock()
            defer { lock.unlock() }
            guard isRunning else { return }
            isRunning = false
            subscriptions.removeAll()
            OrientationObserver.popObserver()
        }
    }

    /// Callback received when device motion has updated.
    private func deviceMotionChanged(to deviceMotion: CMDeviceMotion?) {
        assert(OperationQueue.current === queue)
        guard let gravity = deviceMotion?.gravity else { return }
        let position = CGPoint(x: gravity.x, y: gravity.y)
        // Check four quadrants in counterclockwise fashion, arbitrarily
        let quadrants: [(UIInterfaceOrientation, UIInterfaceOrientation)] = [
            (.landscapeRight, .portrait),
            (.portraitUpsideDown, .landscapeRight),
            (.landscapeLeft, .portraitUpsideDown),
            (.portrait, .landscapeLeft)
        ]
        _ = quadrants.first {
            send(if: position, isBetween: $0)
        }
    }

    /// Sends the resolved orientation iff `position` is between the two values.
    private func send(if position: CGPoint, isBetween tuple: (UIInterfaceOrientation, UIInterfaceOrientation)) -> Bool {
        let former = tuple.0
        let latter = tuple.1
        guard position.isBetween(former, and: latter) else { return false }
        switch position.whichIsCloser(former, or: latter) {
        case .former: send(former)
        case .latter: send(latter)
        }
        return true
    }

    /// Publishes `orientation`.
    private func send(_ orientation: UIInterfaceOrientation) {
        passthrough.send(orientation)
    }

}

// MARK: -

private extension UIInterfaceOrientation {

    var motionVector: CGPoint {
        switch self {
        case .portrait, .unknown: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        @unknown default: return .portrait
        }
    }

}

// MARK: -

private extension CGPoint {

    enum FormerOrLatter {
        case former, latter
    }

    static let portrait = CGPoint(x: 0, y: -1)
    static let portraitUpsideDown = CGPoint(x: 0, y: 1)
    static let landscapeRight = CGPoint(x: -1, y: 0)
    static let landscapeLeft = CGPoint(x: 1, y: 0)

    func distance(to point: CGPoint) -> CGFloat {
        let a = abs(x - point.x)
        let b = abs(y - point.y)
        return (a.squared + b.squared).squareRoot()
    }

    func whichIsCloser(_ a: UIInterfaceOrientation, or b: UIInterfaceOrientation) -> FormerOrLatter {
        let distanceToA = distance(to: a.motionVector)
        let distanceToB = distance(to: b.motionVector)
        return distanceToA < distanceToB ? .former : .latter
    }

    func isBetween(_ a: UIInterfaceOrientation, and b: UIInterfaceOrientation) -> Bool {
        let a = a.motionVector
        let b = b.motionVector
        let minX = min(a.x, b.x)
        let minY = min(a.y, b.y)
        let maxX = max(a.x, b.x)
        let maxY = max(a.y, b.y)
        return minX < x && x <= maxX
            && minY < y && y <= maxY
    }

}

// MARK: -

private extension CGFloat {

    var squared: CGFloat {
        CGFloat(pow(Double(self), 2))
    }

}
