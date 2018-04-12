//
//  Promise.swift
//  Hydra
//
//  Created by Daniele Margutti on 11/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

open class Promise<V> {
	
	public indirect enum State {
		case pending
		case fulfilled(_: V)
		case rejected(_: Swift.Error)
		case cancelled
		
		internal var isPending: Bool {
			guard case .pending = self else { return false }
			return true
		}
		
		internal var isCancelled: Bool {
			guard case .cancelled = self else { return false }
			return true
		}
		
		internal var value: V? {
			guard case .fulfilled(let value) = self else { return nil }
			return value
		}
		
		internal var error: Error? {
			guard case .rejected(let error) = self else { return nil }
			return error
		}
	}
	
	public enum Callback {
		case onFulfill(_: Context, _: Resolver)
		case onReject(_: Context, _: Rejector)
		case onCancel(_: Context, _: (() -> (Void)))
	}
	
	public typealias Resolver = ((V) -> (Void))
	public typealias Rejector = ((Swift.Error) -> (Void))
	public typealias Canceller = (() -> (Void))
	public typealias Body = ((_ resolver: @escaping Resolver, _ rejector: @escaping Rejector) throws -> (Void))
	
	private var body: Body
	private var context: Context
	private var lock = Mutex()
	public private(set) var state: State = .pending
	private var dispatchGroup = DispatchGroup()
	
	private var observers: [Callback] = []
	
	public init(in context: Context = .background, _ body: @escaping Body) {
		self.body = body
		self.context = context
		self.dispatchGroup.enter()

		self.context.execute {
			do {
				try body( { value in
					self.setState(.fulfilled(value))
				}, { err in
					self.setState(.rejected(err))
				})
			} catch let err {
				self.setState(.rejected(err))
			}
		}
	}
	
	deinit {
		self.lock.sync {
			self.observers.removeAll()
		}
	}
	
	private func setState(_ newState: State) {
		self.lock.sync {
			guard self.state.isPending else { return }
			self.state = newState
			self.executeObservers()
		}
	}
	
	internal func add(_ callback: Callback) {
		self.lock.sync {
			self.observers.append(callback)
			guard self.state.isPending else {
				switch (self.state, callback) {
				case (.fulfilled(let value), .onFulfill(let ctx, let callback)):
					ctx.queue?.async(group: self.dispatchGroup, execute: {
						callback(value)
					})
				case (.rejected(let err), .onReject(let ctx, let callback)):
					ctx.queue?.async(group: self.dispatchGroup, execute: {
						callback(err)
					})
				case (.cancelled, .onCancel(let ctx, let callback)):
					ctx.queue?.async(group: self.dispatchGroup, execute: {
						callback()
					})
				default:
					break
				}
				return
			}
			self.executeObservers()
		}
	}

	internal func executeObservers() {
		self.observers.forEach { observer in
			switch (self.state, observer) {
			case (.fulfilled(let value), .onFulfill(let ctx, let callback)):
				ctx.queue?.async(group: self.dispatchGroup, execute: {
					callback(value)
				})
			case (.rejected(let err), .onReject(let ctx, let callback)):
				ctx.queue?.async(group: self.dispatchGroup, execute: {
					callback(err)
				})
			case (.cancelled, .onCancel(let ctx, let callback)):
				ctx.queue?.async(group: self.dispatchGroup, execute: {
					callback()
				})
			default:
				break
			}
		}
		self.dispatchGroup.leave()
	}

	
	internal func chain(in context: Context, fulfill fCallback: ((V) -> (V))?, reject rCallback: ((Swift.Error) -> (Swift.Error))?) -> Promise<V> {
		let promise = Promise<V> { (r, rj) in
			let onFulfill: Callback = .onFulfill(context, { value in
				if let fC = fCallback {
					r( fC(value) )
				} else {
					r(value)
				}
			})
			let onReject: Callback = .onReject(context, { err in
				if let rC = rCallback {
					rj( rC(err) )
				} else {
					rj(err)
				}
			})
			self.add(onFulfill)
			self.add(onReject)
		}
		return promise
	}
	
}
