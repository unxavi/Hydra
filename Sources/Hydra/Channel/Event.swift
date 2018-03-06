//
//  Event.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public enum Event<Value, Error: Swift.Error> {
	case next(Value)
	case error(Error)
	case finished

	public var value: Value? {
		guard case .next(let v) = self else { return nil }
		return v
	}
	
	public var error: Error? {
		guard case .error(let e) = self else { return nil }
		return e
	}
	
	public var isFinal: Bool {
		switch self {
		case .error(_), .finished:	return true
		case .next(_):				return false
		}
	}
}

