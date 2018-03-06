//
//  ReplaySubject.swift
//  Hydra
//
//  Created by Daniele Margutti on 06/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// ReplaySubject is like a Subject but allows you to keep a buffer
/// of given size where all # latest events are stored.
/// Moreover, when a new subscriber will be added to the list, it will
/// receive the entire buffer's size.
public class ReplaySubject<V,E: Swift.Error>: Subject<V,E> {
	
	/// This is the buffer where buffered events are stored.
	/// We are using `ArraySlice` because it makes fast and efficient
	/// for you to perform operations on sections of a larger array.
	private var items: ArraySlice<Event<V,E>> = []
	
	/// This is the size of the buffer where we keep the last # events
	/// received from channel.
	/// Be careful; these objects are stored in memory.
	public private(set) var size: Int
	
	/// Initialize a new replay subject with a buffer of given size.
	/// If `nil` is passed size is set to `Int.max`, virtually an huge
	/// number of elements you should not want to keep in memory.
	/// When you set the buffer size you don't need to make it
	///
	/// - Parameter size: size of the buffer; `nil` to make it huge as `Int.max`.
	public init(size: Int?) {
		// Size is +1 larger to keep the channel's terminal event.
		self.size = (size == nil ? Int.max : (size! + 1))
	}
	
	/// Event received from ChannelProtocol on new event.
	///
	/// - Parameter event: event received
	public override func send(_ event: Event<V, E>) {
		// store and clean buffer
		self.items.append(event)
		self.items = self.items.suffix(self.size)
		// continue with the normal behaviour
		super.send(event)
	}
	
	/// Add a new observer of the subject.
	///
	/// - Parameter callback: callback to call on a new event.
	/// - Returns: disposable used to dispose the subscription.
	public override func subscribe(_ callback: @escaping ((Event<V, E>) -> (Void))) -> DisposableProtocol {
		// replay all buffered events to the new subscriber
		self.items.forEach { callback($0) }
		// continue with the normal behaviour
		return super.subscribe(callback)
	}
	
}
