//
//  Channel+Operations.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension ChannelProtocol {
	
	/// Create a channel which start with given value then start forwarding `self` events.
	///
	/// - Parameter value: initial value to dispatch
	/// - Returns: channel
	public func start(with value: Value) -> Channel<Value,Error> {
		return Channel({ producer in
			producer.send(value: value)
			return self.subscribe({ event in
				producer.send(event)
			})
		})
	}
	
	
	/// Create a channel which, before receiving the last terminal message (`.finished`)
	/// dispatch given value.
	///
	/// - Parameter value: value to pass before `.finished` event.
	/// - Returns: channel
	public func end(with value: Value) -> Channel<Value,Error> {
		return Channel({ producer in
			return self.subscribe({ event in
				switch event {
				case .finished:
					producer.send(value: value) // dispatch our custom value...
					producer.complete() // ... then complete
				default:
					producer.send(event)
				}
			})
		})
	}
	
	/// Apply reduce function to an initial value by passing to it the current value emitted by the channel.
	///
	/// - Parameters:
	///   - initial: initial value of the output you want to produce.
	///   - reduce: reduction function; will receive both the current state of the reduced value and the current value recevied on event.
	/// - Returns: channel
	public func reduce<NewValue>(_ initial: NewValue, _ reduce: @escaping ((_ reduced: NewValue, _ current: Value) -> (NewValue))) -> Channel<NewValue,Error> {
		return Channel<NewValue,Error>({ producer in
			
			var accumulatedValue: NewValue = initial
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// only accumulation function is called
					accumulatedValue = reduce(accumulatedValue, value)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					// when `self` send a terminal event we want to dispatch
					// our accumulated event before...
					producer.send(value: accumulatedValue)
					// ...then ends
					producer.send(.finished)
				}
			})
		})
	}
	
	/// Transform current channel to a channel which dispatch an array of values only
	/// when enough values are accumulated.
	///
	/// - Parameter size: size of the buffer. once filled a new event with given array is dispatched.
	/// - Returns: new channel with `[Value]` as value type.
	public func buffer(size: Int) -> Channel<[Value], Error> {
		return Channel { producer in
			var buffer: [Value] = []
			
			// register to receive events from self (any other subscried callback
			// will be removed) and redirect the array to the new Channel of array
			// only when array is full.
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					buffer.append(value)
					// buffer is filled and we can dispatch a new event with the list.
					// just after, remove all items by keeping the capacity.
					if buffer.count == size {
						producer.send(value: buffer)
						buffer.removeAll(keepingCapacity: true)
					}
				// any other event type is forward immediately without further changes
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})

		}
	}
	
	/// Create a new channel which emits transformed value from `self`.
	///
	/// - Parameter transformer: transformer callback used to map a value into another value.
	/// - Returns: channel
	public func map<NewValue>(_ transformer: @escaping ((Value) -> (NewValue))) -> Channel<NewValue,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// apply transform to received value and dispatch it
					let transformedValue = transformer(value)
					producer.send(.next(transformedValue))
					
				// other values are forwarded without changes
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})
		})
	}
	
	/// Map each emitted value and give the opportunity to transform a `.next` value  into another type of `Event`.
	///
	/// - Parameter transform: transform function
	/// - Returns: new channel
	public func map<NewValue>(_ transform: @escaping ((Value) -> Event<NewValue, Error>)) -> Channel<NewValue, Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// transform value into another type of event
					let transformedEvent: Event<NewValue,Error> = transform(value)
					producer.send(transformedEvent)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.send(.finished)
				}
			})
			
		})
	}
	
	/// Map any error dispatched into `self` channel and give the opportunity to transform it into another error.
	/// Any other event is forwarded without changes.
	///
	/// - Parameter transform: transform callback for `.error` events.
	/// - Returns: channel with new error type
	public func mapError<NewError>(_ transform: @escaping ((Error) -> (NewError))) -> Channel<Value, NewError> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .error(let error):
					let transformedError = transform(error)
					producer.send(.error(transformedError))
				case .next(let value):
					producer.send(value: value)
				case .finished:
					producer.send(.finished)
				}
			})
			
		})
	}
	
	/// Map each element emitted by `self` channel, transform it to a new value and propagates
	/// only `.some` results (not-nil).
	///
	/// - Parameter transformer: transformer callback used to map a value to another (optional) value.
	/// - Returns: channel
	public func flatMap<NewValue>(_ transformer: @escaping ((Value) -> (NewValue?))) -> Channel<NewValue,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// transform received value from `self`. If transformation return a `nil`
					// value, channel will not dispatch `nil` over.
					guard let transformedValue = transformer(value) else {
						return
					}
					producer.send(value: transformedValue)
					
				// other values are forwarded without changes
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
				
			})
			
		})
	}

	/// Map each `.next` element from `self` channel to Void.
	///
	/// - Returns: new channel where type is Void
	public func mapToVoid() -> Channel<Void,Error> {
		return self.map({ _ in
			return Void()
		})
	}
	
	/// Map each `.next` element from `self` channel to specified value.
	///
	/// - Parameter value: value used to replace stream of `.next` values.
	/// - Returns: channel where type is the new type specified for replace
	public func mapTo<NewValue>(value: NewValue) -> Channel<NewValue,Error> {
		return self.map({ _ in
			return value
		})
	}

	
	/// Apply `combine` to each element starting with `initial` and emit each
	/// intermediate result.
	/// Note: This differs from `reduce` operation which emits only final result of the channel.
	///
	/// - Parameters:
	///   - initial: initial value
	///   - combine: combine function; it will receive partial accumulated value and new emitted value, to return a new value
	/// - Returns: new channel
	public func combine<NewValue>(_ initial: NewValue, _ combine: @escaping ((NewValue, Value) -> (NewValue))) -> Channel<NewValue, Error> {
		return Channel<NewValue,Error>({ producer in
			
			var accumulatedValue: NewValue = initial
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					accumulatedValue = combine(accumulatedValue, value)
					producer.send(.next(accumulatedValue))
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.send(.finished)
				}
			})
			
		})
	}
	
	/// Create a new channel by suppressing all received errors from `self`.
	/// This function give the opportunity to execute a callback where you can log the event.
	/// After suppression channel completes.
	///
	/// - Parameters:
	///   - callback: optional callback to log a received error.
	///   - file: log file
	///   - line: log line
	/// - Returns: new non failable channel
	public func suppressError(_ callback: ((_ error: Error, _ file: String, _ line: Int) -> (Void))? = nil,
							  file: String = #file, line: Int = #line) -> Channel<Value,NoError> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					producer.send(value: value)
				case .finished:
					producer.send(.finished)
				case .error(let error):
					callback?(error,file,line)
					producer.send(.finished)
				}
			})
			
		})
	}
	
	
	/// Recovers the signal by propagating specified value if error happens.
	/// After propagation channel complets.
	///
	/// - Parameter recoverValue: value used to recover
	/// - Returns: non failable recovered channel
	public func recover(with recoverValue: Value) -> Channel<Value,NoError> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					producer.send(value: value)
				case .error(_):
					producer.send(value: recoverValue)
					producer.send(.finished)
				case .finished:
					producer.send(.finished)
				}
			})
			
		})
	}
	
	/// Recover the signal by propagating value returned from specified callback.
	///
	/// - Parameter callback: callback used to recover; will receive as input the error, and return a `Value` type.
	/// - Returns: non failable recovered channel
	public func recover(with callback: @escaping ((Error) -> (Value))) -> Channel<Value,NoError> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					producer.send(value: value)
				case .error(let error):
					let recovered = callback(error)
					producer.send(value: recovered)
					producer.send(.finished)
				case .finished:
					producer.send(.finished)
				}
			})
			
		})
	}
	
	/// Create a channel which groups all values emitted by `self` in a single array
	/// dispatched when it finish.
	///
	/// - Returns: channel
	public func group() -> Channel<[Value],Error> {
		return self.combine([], { (list, new) in
			list + [new]
		})
	}
	
}
