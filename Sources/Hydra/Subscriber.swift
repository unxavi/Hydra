//
//  Subscriber.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public typealias Subscriber<Value, Error: Swift.Error> = ((Event<Value, Error>) -> (Void))

public protocol SubscriberProtocol {
	associatedtype Value
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

public class SafeSubscriber<V, E: Swift.Error>: SubscriberProtocol {
	public typealias Value = V
	public typealias Error = E
	
	private let mutex: Mutex = Mutex()
	private var subscriber: Subscriber<V,E>? = nil
	public private(set) var disposable: Disposable!
	
	internal(set) var linkedDisposable: DisposableProtocol?
	
	public init(subscriber: @escaping Subscriber<V,E>) {
		self.subscriber = subscriber
		self.linkedDisposable = disposable
		self.disposable = Disposable(onDispose: { [weak self] in
			self?.subscriber = nil
			self?.linkedDisposable?.dispose()
		})
	}
	
	public func send(_ event: Event<V, E>) {
		self.mutex.sync {
			guard let s = self.subscriber else { return }
			s(event)
			if event.isTerminal {
				self.disposable.dispose()
			}
		}
	}
}
