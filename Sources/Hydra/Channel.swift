//
//  Signal.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Used to mark a `Channel` as not failable.
public enum NoError: Swift.Error { }

/// `ChannelProtocol` represent a conformance to a single-input/single-output data stream.
public protocol ChannelProtocol {
	associatedtype Value
	associatedtype Error: Swift.Error
	
	/// Subscribe for channel's events. Channel have only a single output subscriber.
	///
	/// - Parameter callback: callback to call on new events.
	/// - Returns: diposable
	func subscribe(_ callback: @escaping Subscriber<Value, Error>) -> DisposableProtocol
}

public extension ChannelProtocol {
	
	/// Register an observer that will receive events from another channel.
	///
	/// - Parameter subscriber: subscriber
	/// - Returns: disposable
	public func subscribe<S: SubscriberProtocol>(to subscriber: S) -> DisposableProtocol
		where S.Value == Value, S.Error == Error {
		return self.subscribe(subscriber.send)
	}
	
	/// Subscribe to only `.next` event types.
	///
	/// - Parameter callback: callback to execute.
	/// - Returns: disposable
	public func subscribe(next callback: @escaping ((Value) -> (Void))) -> DisposableProtocol {
		return self.subscribe { event in
			guard case .next(let v) = event else { return }
			callback(v)
		}
	}
	
	/// Subscribe to only `.error` event types.
	///
	/// - Parameter callback: callback to execute.
	/// - Returns: disposable
	public func subscribe(error callback: @escaping ((Error) -> (Void))) -> DisposableProtocol {
		return self.subscribe { event in
			guard case .error(let e) = event else { return }
			callback(e)
		}
	}
	
	/// Subscribe to only completion event types.
	///
	/// - Parameter callback: callback to execute.
	/// - Returns: disposable
	public func subscribe(complete callback: @escaping (() -> (Void))) -> DisposableProtocol {
		return self.subscribe { event in
			guard case .finished = event else { return }
			callback()
		}
	}
	
}

public struct Channel<V, E: Swift.Error>: ChannelProtocol {
	public typealias Value = V
	public typealias Error = E

	/// Callback definition
	public typealias ChannelProducer = ((SafeSubscriber<Value,Error>) -> (DisposableProtocol))

	/// Input producer callback
	private let producer: ChannelProducer
	
	/// Create a new channel with the input producer callback.
	/// Simple Channel class can generate new events only inside the producer's callback.
	/// `ChannelProducer` may return a `Disposable` (you can use to cancel the operation) or
	/// `Disposable.dontcare` if you are not interested in cancelling a runner producer from the outside.
	///
	/// - Parameter input: producer callback
	public init(_ producer: @escaping ChannelProducer) {
		self.producer = producer
	}
	
	/// Register a new output for this signal.
	/// `Channel` instance implies single-input and single-output, so if you attempt to register
	/// more than one subscriber, previous one will be replaced automatically.
	/// This is a difference compared to other reactive programming frameworks that allow multiple-observers
	/// by default.
	/// In order to user multiple observers you must use the `MultiChannel` class.
	///
	/// - Parameter callback: callback to register
	/// - Returns: a disposable you can use to dispose subscription registration.
	public func subscribe(_ callback: @escaping ((Event<Channel<V, E>.Value, Channel<V, E>.Error>) -> (Void))) -> DisposableProtocol {
		// Create a new subscriber for this callback.
		// Subscriber manage the amocity dispatch of the events.
		// Subscriber also have a disposable which is returned by this function and allows the user to cancel the subscriber itself.
		let subscriber = SafeSubscriber(subscriber: callback)
		
		// Producer may return a disposable, typically used to cancel the operations of the channel from the outside.
		// For example a producer may start a network task and return a disposable with a callback (called on dispose9
		// which cancel the task itself.
		let producerDisposable = self.producer(subscriber)
		
		// Link the producer's disposable to the subscriber's disposable so when user call dispose on subscriber
		// it also dispose producer's disposable cancelling the operation.
		subscriber.disposable.linked = producerDisposable
		return subscriber.disposable
	}
	
}
