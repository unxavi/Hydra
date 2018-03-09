//
//  Property.swift
//  Hydra
//
//  Created by Daniele Margutti on 06/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public protocol PropertyProtocol {
	associatedtype PropertyValue
	
	var value: PropertyValue { get }
}

public class Property<V>: PropertyProtocol, SubjectProtocol, BindingProtocol {
	public typealias BindedValue = V
	
	public typealias Error = NoError
	public typealias PropertyValue = V
	public typealias Value = V
	
	/// This is the underlying value we want to keep.
	private var innerValue: V
	
	/// Ensure atomicity of events dispatch
	private var lock = Mutex()
	
	/// This is the subject used to notify of changes
	private var subject: Subject<V,NoError> = Subject<V,NoError>()
	
	/// This is the value currently set for this property.
	/// Changing it emits a new `.next()` event with the new value.
	public var value: V {
		get {
			return self.lock.sync { self.innerValue }
		}
		set {
			self.set(newValue, silently: false)
		}
	}
	
	/// Initialize a new property with passed value.
	///
	/// - Parameter value: value to set
	public init(_ value: V) {
		self.innerValue = value
	}
	
	/// Set the new value of the property. It's like `.value = ...` but
	/// you can choose if the operation must also fire the dispatch of the
	/// events to the subscribers.
	/// Set is thread safe.
	///
	/// - Parameters:
	///   - value: new value to set.
	///   - silently: `true` to avoid subscribers notifications, `false` to notify them.
	public func set(_ value: V, silently: Bool = false) {
		self.lock.sync {
			self.innerValue = value
			if silently == false {
				// Dispatch the new event
				self.subject.send(.next(value))
			}
		}
	}
	
	
	/// Add a new subscriber of the property's change events.
	///
	/// - Parameter callback: callback to call
	/// - Returns: disposable, used to remove callback when you are not interested anymore in changes.
	public func subscribe(_ callback: @escaping Subscriber<V, NoError>) -> DisposableProtocol {
		// In fact this is a modification of the standard behaviour. We want just to add passed callback
		// as a new subscriber of the inner's `subject` variable used to dispatch event to multiple subscribers.
		let disposable = self.subject.start(with: self.value).subscribe(callback)
		return disposable
	}
	
	/// Dispatch a new event (or, for Property class just change the value like `.value = `).
	///
	/// - Parameter event: event to dispatch, only `.next()` events are dispatched, others are ignored.
	public func send(_ event: Event<V, NoError>) {
		// Property cannot have errors, only new values. We don't care about any other event type.
		guard case .next(let newValue) = event else { return }
		self.innerValue = newValue // store new event...
		self.subject.send(event) // ...dispastch it to the observers of the subject
	}
	
	
	public func bind(channel: Channel<Property<V>.BindedValue, NoError>) -> DisposableProtocol {
		let destroyBindEvent = self.subject.disposable.deallocateChannel
		return channel.until(filter: .any, channel: destroyBindEvent).subscribe(next: { [weak self] newValue in
			self?.send(value: newValue)
		})
	}
	
}
