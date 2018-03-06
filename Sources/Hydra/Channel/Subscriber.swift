//
//  Subscriber.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Subscriber is the typealias for a function callback called to observe
/// new events received from a Channel.
public typealias Subscriber<Value, Error: Swift.Error> = ((Event<Value, Error>) -> (Void))

/// Subscriber protocol is a protocol used to define an entity which can observe
/// events produced by a Channel.
public protocol SubscriberProtocol {
	
	// Value produced by the subscriber
	associatedtype Value
	
	// Error produced by the subscriber
	associatedtype Error: Swift.Error
	
	/// Send an event to an observer.
	///
	/// - Parameter event: event to dispatch
	func send(_ event: Event<Value,Error>)
}

public extension SubscriberProtocol {
	
	/// Send `.next` event with given value.
	///
	/// - Parameter value: value
	public func send(value: Value) {
		self.send(.next(value))
	}
	
	/// Send `.error` event with given error. Channel will interrupt itself.
	///
	/// - Parameter error: error
	public func send(error: Error) {
		self.send(.error(error))
	}
	
	/// Send completion event to the channel.
	///
	/// - Parameter value: optional last value to send.
	public func complete(value: Value? = nil) {
		if let v = value {
			self.send(.next(v))
		}
		self.send(.finished)
	}
	
}

/// SafeSubsciber is used to provide a thread safe subscriber manager for Channel.
/// It receives messages from Channel's producer and dispatch to the subscriber callback
/// keeping the stuff thread safe.
/// A Channel can have one and one only subscriber (and a single producer too).
/// Overriding a subscriber of a Channel is a way to restart the producer (and remove
/// previosly set subscriber)
public class SafeSubscriber<V, E: Swift.Error>: SubscriberProtocol {
	
	/// Value produced to the subscriber
	public typealias Value = V
	
	/// Error produced to the subscriber
	public typealias Error = E
	
	/// it keeps the event dispatching thread safe
	private let mutex: Mutex = Mutex()
	
	/// Subscriber callback
	private var subscriber: Subscriber<V,E>? = nil
	
	/// Disposable of the subscriber
	public private(set) var disposable: Disposable!
	
	/// Optional linked disposable
	internal(set) var linked: DisposableProtocol?
	
	/// Initialize a new instance with given subscriber callback.
	///
	/// - Parameter subscriber: subscriber callbak
	public init(subscriber: @escaping Subscriber<V,E>) {
		self.subscriber = subscriber
		self.linked = disposable
		self.disposable = Disposable(onDispose: { [weak self] in
			self?.subscriber = nil
			self?.linked?.dispose()
		})
	}
	
	/// Dispatch event to the subscriber.
	/// This function is thread safe; events are dispatched in the same order
	/// they are received.
	///
	/// - Parameter event: event to dispatch
	public func send(_ event: Event<V, E>) {
		self.mutex.sync {
			guard let s = self.subscriber else { return }
			s(event)
			// once a final event is received we want to dispose the subscriber's disposable too
			if event.isFinal {
				self.disposable.dispose()
			}
		}
	}
}
