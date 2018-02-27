//
//  Channel+Filters.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 27/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension ChannelProtocol {
	
	/// Convert `self` to a concrete channel; if it's already a channel it just return self.
	/// If it's not a channel it act return a new channel and subscribing to receive events
	/// from self.
	///
	/// - Returns: channel
	public func asChannel() -> Channel<Value,Error> {
		guard let channel = self as? Channel<Value,Error> else {
			return Channel({ producer in
				return self.subscribe(producer.send)
			})
		}
		return channel
	}

	
	/// Emit a `.next` value only if specified interval is passed without emitting another value.
	/// The idea of "Debouncing" is to limit the rate a function or task can execute by waiting
	/// a certain amount of time before executing it.
	///
	/// - Parameters:
	///   - interval: minimum interval necessary between events.
	///   - queue: queue in which timer is called.
	/// - Returns: channel
	public func debounce(interval: TimeInterval, queue: DispatchQueue? = nil) -> Channel<Value,Error> {
		return Channel({ producer in
			
			// create a queue if necessary
			let q = (queue ?? DispatchQueue(label: "debounce.hydra"))
			var valueToDispatch: Value? = nil
			var timer: Disposable? = nil
			
			return self.subscribe({ event in
				
				// discard previous debounce dispatch
				timer?.dispose()
				
				switch event {
				case .next(let value):
					// store new value and queue to dispatch it after
					// specified interval.
					valueToDispatch = value
					timer = q.after(interval, {
						// if, after given interval, this queue will be executed
						// (not disposed by a new arrived event) we want to dispatch
						// the value itself.
						if let v = valueToDispatch {
							producer.send(value: v)
							valueToDispatch = nil
						}
					})
				case .error(let error):
					producer.send(error: error)
				case .finished:
					if let v = valueToDispatch {
						producer.send(value: v)
						producer.complete()
					}
				}
			})
			
		})
	}
	

	/// Create a new channel which emits, after the first value, only values which differs from previous value.
	/// To accomplish it, function provide a evaluator function which is called passing the predecessor and current
	/// value: this function must return `true` or `false` to identify if values are different or not.
	/// Other events are dispatched normally.
	///
	/// NOTE: If your values are conform to `Equatable` it will be handled automatically by `distinct()` function
	///       available in `ChannelProtocol` extension for `Equatable` values.
	///
	/// - Parameter evaluator: evaluator function, return `true` if objects are different and can be dispatched, `false` otherwise.
	/// - Returns: channel
	public func distinct(_ evaluator: @escaping ((_ predecessor: Value, _ current: Value) -> (Bool))) -> Channel<Value,Error> {
		return Channel({ producer in
			var precedessor: Value? = nil
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// only for first or non-equals elements producer will dispatch new arrived value
					if precedessor == nil || evaluator(precedessor!,value) == true {
						producer.send(value: value)
					}
					precedessor = value
				case .error(let error):
					producer.send(.error(error))
				case .finished:
					producer.send(.finished)
				}
			})
		})
	}
	
	/// Return a channel which emits only values at given indexes.
	/// and only if its produced.
	/// Other events are dispatched normally.
	///
	/// - Parameter index: indexe of the `.next` values to emit
	/// - Returns: channel
	public func valueAt(_ indexes: IndexSet) -> Channel<Value,Error> {
		return Channel({ producer in
			
			var indexesList: IndexSet = indexes
			var index: Int = 0
			return self.subscribe({ event in
				// only if index is in our index set value is dispatched
				if indexesList.contains(index) {
					producer.send(event)
					// remove from our index set to avoid unecessary checks
					indexesList.remove(index)
				}
				index += 1
			})
			
		})
	}
	
	
	/// Create a channel which filters all events received from `self` using a filter callback.
	/// If filter callback return `false` events is not dispatched thought the graph.
	///
	/// - Parameter filter: filter function, return `true` to allow dispatch.
	/// - Returns: channel wich emits only filtered values.
	public func filter(_ filter: @escaping ((Value) -> (Bool))) -> Channel<Value,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					guard filter(value) else { return } // skip if not pass the test
					producer.send(value: value)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})
			
		})
	}
	
	
	/// Create a channel to dispatch only terminal events by ignoring all `.next` values.
	///
	/// - Returns: channel
	public func skipValues() -> Channel<Value,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				// We want to ignore all `.next` events and dispatch only terminal events.
				guard event.isTerminal else { return }
				producer.send(event)
			})
			
		})
	}
	
	
	/// Create a channel to dispatch only `.next` events by ignoring all terminal types.
	///
	/// - Returns: channel
	public func skipTerminals() -> Channel<Value,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				// ignore all terminal events
				guard case .next(let value) = event else { return }
				producer.send(value: value)
			})
			
		})
	}
	
	/// Create a channel which dispatch only the first `count` number of items, then
	/// complete channel.
	///
	/// - Parameter count: number of items to keep.
	/// - Returns: channel
	public func first(_ count: Int) -> Channel<Value,Error> {
		return Channel({ producer in
			guard count > 0 else { // invalid buffer's size
				producer.complete()
				return Disposable.dontCare
			}
			
			var buffer: [Value] = []
			buffer.reserveCapacity(count)
			
			let disposable = Disposable()
			disposable.linked = self.subscribe({ event in
				switch event {
				case .next(let value):
					guard buffer.count < count else {
						producer.complete()
						disposable.linked?.dispose()
						return
					}
					buffer.append(value)
					producer.send(value: value)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})
			
			return disposable
		})
	}
	
	/// Create a channel to dispatch only the last `count` values emitted by `self` channel.
	///
	/// - Parameter count: number of latest item to keep
	/// - Returns: channel
	public func last(_ count: Int) -> Channel<Value,Error> {
		return Channel({ producer in
			
			guard count > 0 else { // invalid buffer's size
				producer.complete()
				return Disposable.dontCare
			}
			
			// Create a buffer array where we keep only the last `count`
			// values received from `self` channel.
			var buffer: [Value] = []
			buffer.reserveCapacity(count)
			
			let disposable = Disposable()
			disposable.linked = self.subscribe({ event in
				switch event {
				case .next(let value):
					if (buffer.count + 1) > count {
						buffer.removeFirst(buffer.count - count + 1)
					}
					buffer.append(value)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					buffer.forEach { producer.send(value: $0) }
					producer.complete()
				}
			})
			return disposable
		})
	}

	/// Create a channel which emit at most one element per given `seconds` interval.
	///
	/// - Parameter seconds: seconds of the interval
	/// - Returns: channel
	public func throttle(seconds: Double) -> Channel<Value,Error> {
		return Channel({ producer in
			var lastDispatch: DispatchTime?
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// first value is allowed, then only a value after seconds since predecessor is allowed to be dispatched
					let isPassedEnough = (lastDispatch == nil || DispatchTime.now().rawValue > (lastDispatch! + seconds).rawValue)
					guard isPassedEnough else { return }
					producer.send(value: value)
					lastDispatch = DispatchTime.now()
				default:
					producer.send(event)
				}
			})
			
		})
	}
	
	/// Delay the dispatch of any event produced by channel `self` by a specified amount of seconds.
	///
	/// - Parameters:
	///   - interval: delay interval in seconds.
	///   - queue: queue to execute the dispatch, `nil` to demand the creation to the function itself.
	/// - Returns: channel
	public func delay(_ interval: Double, queue: DispatchQueue? = nil) -> Channel<Value,Error> {
		return Channel({ producer in
			// Create a queue if necessary
			let q = (queue ?? DispatchQueue(label: "delay.queue.hydra"))
			return self.subscribe({ event in
				// Dispatch any received event with a delay of interval
				q.after(interval, {
					producer.send(event)
				})
			})
			
		})
	}
	
	/// Create a channel used to log events received from `self` channel.
	///
	/// - Parameters:
	///   - log: log function called to produce the log string (it receives file, function and line of the executed caller).
	///   - file: debug file (don't touch)
	///   - function: debug function (don't touch)
	///   - line: debug line (don't touch)
	/// - Returns: channel
	public func log(_ log: @escaping ((_ file: String, _ function: String, _ line: Int) -> (Void)),
					file: String = #file, function: String = #function, line: Int = #line) -> Channel<Value,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				log(file,function,line)
				producer.send(event)
			})
			
		})
	}
	
	/// Create a channel which restart the operation if it fails.
	/// It perform a maximum of `attempts` retries before ending with given error (if specified)
	/// or last error.
	///
	/// - Parameters:
	///   - attempts: number of attempts
	///   - error: if specified this is the error reported at the end of max `attempts` if operation still fail.
	/// - Returns: channel
	public func retry(_ attempts: Int, error custom: Error? = nil) -> Channel<Value,Error> {
		guard attempts > 0 else {
			// invalid number of attempts; just return the channel without changes
			return self.asChannel()
		}
		
		return Channel({ producer in
			var leftAttempts = attempts
			
			// The executorTask is a function which dispose any previous running task
			// and re-subscribe the channel which re-execute the input function which generate
			// the result. If result is okay or finished we just dispatch it; if false we need
			// to check if we have any further attempt (in this case we allocate a new executorTask)
			// or leave the channel to dispatch a terminal error event.
			var executorDisposable: DisposableProtocol? = nil
			var executorTask: (() -> (Void))? = nil
			executorTask = {
				// dispose any previous task
				executorDisposable?.dispose()
				// by creating a new subscriber we re-execute the producer of the channel.
				executorDisposable = self.subscribe({ event in
					switch event {
					case .error(let error):
						// No more attempts remaining, end channel
						// with passed custom error or last received error
						// from producer.
						guard leftAttempts > 0 else {
							producer.send(error: (custom ?? error))
							executorTask = nil
							return
						}
						// We have another attempt; increment the counter and re-execute this
						// function to re-execute the task itself.
						leftAttempts -= 1
						executorTask?()
					default: // any other event is forwarded without changes
						producer.send(event)
					}
				})
			}
		
	
			return Disposable.onDispose({
				// dispose the executor
				executorDisposable?.dispose()
				executorTask = nil
			})
		})
	}

}

public extension ChannelProtocol where Value: Equatable {
	
	/// Create a new channel which emits, after the first value, only values which differs from previous value.
	/// NOTE: This is a shortcut to `distinct` function which rely to `Equatable` protocol to produce automatic evaluator function.
	///
	/// - Returns: channel
	public func distinct() -> Channel<Value,Error> {
		return self.distinct( != )
	}
	
}

public extension ChannelProtocol where Value: OptionalProtocol, Value.UnwrappedValue: Equatable {
	
	/// Create a new channel which emits, after the first value, only values which differs from previous value.
	/// NOTE: This is a shortcut to `distinct` function which rely to `Equatable` protocol to produce automatic evaluator function.
	///
	/// - Returns: channel
	public func distinct() -> Channel<Value, Error> {
		return distinct( != )
	}
	
	/// Create a channel which ignores all `nil` produced values.
	///
	/// - Returns: channel
	public func skipNils() -> Channel<Value.UnwrappedValue,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					// attempt to unwrap optional value
					// if `nil` dispatch the value itself, else skip.
					guard let v = value.unwrapValue else { return }
					producer.send(value: v)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})
			
		})
	}
	
	/// Create a new channel which replaces any `.next` events with optional `nil` value
	/// and replace it with a givn value.
	///
	/// - Parameter value: value used to replace `nil` values.
	/// - Returns: channel
	public func replaceNils(_ replace: Value.UnwrappedValue) -> Channel<Value.UnwrappedValue,Error> {
		return Channel({ producer in
			
			return self.subscribe({ event in
				switch event {
				case .next(let value):
					guard let value = value.unwrapValue else {
						producer.send(value: replace)
						return
					}
					producer.send(value: value)
				case .error(let error):
					producer.send(error: error)
				case .finished:
					producer.complete()
				}
			})
			
		})
	}
}

