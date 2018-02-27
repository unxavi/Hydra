//
//  Channel+Extras.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension Channel {
	
	/// Create a new channel with a single emitted value and then complete.
	///
	/// - Parameter value: value to emit.
	/// - Returns: channel
	public static func just(_ value: Value) -> Channel<Value,Error> {
		return Channel({ producer in
			producer.complete(value: value)
			return Disposable.dontCare
		})
	}
	
	/// Create a new channel to emit given sequence at the same specified order, then complete.
	///
	/// - Parameter sequence: sequence of values to emit.
	/// - Returns: channel
	public static func sequence<S: Sequence>(_ sequence: S) -> Channel<Value, Error> where S.Iterator.Element == Value {
		return Channel({ producer in
			sequence.forEach { producer.send(.next($0)) }
			producer.complete()
			return Disposable.dontCare
		})
	}
	
	
	/// Create a new channel which completes immediately without producing any value.
	///
	/// - Returns: channel
	public static func completed() -> Channel<Value,Error> {
		return Channel({ producer in
			producer.complete()
			return Disposable.dontCare
		})
	}
	
	/// Create a new channel which fail with given error without producing any value.
	///
	/// - Parameter error: error for failure.
	/// - Returns: channel
	public static func failed(_ error: Error) -> Channel<Value,Error> {
		return Channel({ producer in
			producer.send(.error(error))
			return Disposable.dontCare
		})
	}
	
	
	/// Create a new channel that never complete and don't produce any value.
	///
	/// - Returns: channel
	public static func never() -> Channel<Value,Error> {
		return Channel({ producer in
			return Disposable.dontCare
		})
	}
	
	
	/// Create a channel which emit given value at regular intervals by calling a generator function.
	///
	/// - Parameters:
	///   - interval: interval of the repetition.
	///   - generator: callback called each interval to produce a new value. Input parameter is the iteration count.
	///   - queue: queue in which execute the the timer. If `nil` a newly queue is created.
	/// - Returns: channel
	public static func every(interval: Repeat.Interval,
							 generator: @escaping ((_ iteration: Int) -> (Value)),
							 queue: DispatchQueue? = nil) -> Channel<Value,Error> {
		return Channel({ producer in
			var iteration: Int = 0
			
			let timer = Repeat(interval: interval, mode: .infinite, queue: queue, observer: { _ in
				let value = generator(iteration)
				producer.send(.next(value))
				iteration += 1
			})
			timer.start()
			
			return Disposable.onDispose({
				timer.pause()
			})
		})
	}
	
	
	/// Create a channel which emits given value after a specified interval.
	///
	/// - Parameters:
	///   - interval: time interval to produce the new value.
	///   - value: value to generate.
	///   - queue: queue in which execute the the timer. If `nil` a newly queue is created.
	/// - Returns: channel
	public static func after(interval: Repeat.Interval, value: Value, queue: DispatchQueue? = nil) -> Channel<Value,Error> {
		return Channel({ producer in
			let timer = Repeat.once(after: interval, { _ in
				producer.send(.next(value))
			})
			timer.start()
			
			return Disposable.onDispose({
				timer.pause()
			})
		})
	}
	
}
