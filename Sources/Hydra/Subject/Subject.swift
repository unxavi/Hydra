//
//  Subject.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 28/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// A subject is both a producer of events and a subscriber (because it
/// dispatch events received to the list of all subscriber callbacks).
public protocol SubjectProtocol: ChannelProtocol, SubscriberProtocol { }

/// Subject class act as a channel where you can put new events from the outside
/// by calling `send()` function, and as a subscriber with multiple observer because,
/// for each event, it will be dispatched to the all remainings.
public class Subject<V, E: Swift.Error>: SubjectProtocol {
	public typealias Token = UInt64
	public typealias Value = V
	public typealias Error = E
	
	/// If `true` the inner channel is active too. When `false` channel streaming is terminated.
	private var isActive: Bool = true
	
	/// List of the subscribers for this subject
	private var subscribers: [Token : Subscriber<V,E>] = [:]
	
	/// This hold the next token identifier when you attach a new subscriber to watch
	/// events from subject. Behind the typealias there is a UInt64, it should pretty
	/// large for all humankind needs.
	private var nextTokenID: Token = 0
	
	/// Thread safe support for dispatching events
	private var lock: Mutex = Mutex()
	
	public var disposable: DisposableBag = DisposableBag()

	/// Allows you to attach a new subscriber.
	/// It overrides the default behaviour of the SubscriberProtocol in order to allows
	/// subscription of more callbacks.
	///
	/// - Parameter callback: callback to call on new event
	/// - Returns: disposable used to dismiss the watcher
	public func subscribe(_ callback: @escaping Subscriber<V, E>) -> DisposableProtocol {
		return self.lock.sync {
			var (next,overflow) = self.nextTokenID.addingReportingOverflow(1) // just to be safe
			if overflow { // reset the observer counter
				self.nextTokenID = 0
				next = 0
			}
			
			self.subscribers[next] = callback
			
			// return a disposable for this subscriber. Once the disposable will be disposed
			// the subscriber will be also removed from the list of subscribers.
			return Disposable.onDispose({ [weak self] in
				self?.subscribers.removeValue(forKey: next)
			})
		}
	}
	
	/// Event received from ChannelProtocol on new event.
	///
	/// - Parameter event: event received
	public func send(_ event: Event<V, E>) {
		self.lock.sync {
			guard self.isActive else { return } // keep it running only for live channels
			self.isActive = (event.isFinal == false)
			// dispatch the new occurred event to all the subscribers
			self.subscribers.values.forEach { $0(event) }
		}
	}
	
}
