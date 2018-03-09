//
//  Context.swift
//  Hydra
//
//  Created by Daniele Margutti on 09/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Execution context.
///
/// - main: main thread
/// - inline: same thread of the caller
/// - background: background thread
/// - priority: background thread with given priority
public enum Context {
	case main
	case inline
	case background
	case priority(_: ContextPriority)
	
	private var queue: DispatchQueue? {
		switch self {
		case .main:				return DispatchQueue.main
		case .inline:			return nil
		case .background:		return DispatchQueue.global(qos: .background)
		case .priority(let p):	return DispatchQueue.global(qos: p.qOS)
		}
	}
	
	public func execute(_ block: @escaping () -> Void) {
		guard let q = self.queue else { // inline, same thread of the caller
			block()
			return
		}
		q.async { // custom queue
			block()
		}
	}

}

/// Context priorioty
public enum ContextPriority {
	case low
	case normal
	case high
	case max
	
	public var qOS: DispatchQoS.QoSClass {
		switch self {
		case .low:		return .background
		case .normal:	return .default
		case .high:		return .userInitiated
		case .max:		return .userInteractive
		}
	}
}
