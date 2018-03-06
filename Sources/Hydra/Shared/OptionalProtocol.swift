//
//  OptionalProtocol.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 27/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public protocol OptionalProtocol {
	associatedtype UnwrappedValue
	
	var unwrapValue: Optional<UnwrappedValue> { get }
	
	init(nilLiteral: ())
	
	init(_ some: UnwrappedValue)
}

extension Optional: OptionalProtocol {
	
	public var unwrapValue: Optional<Wrapped> {
		return self
	}
	
}

func ==<O: OptionalProtocol>(lhs: O, rhs: O) -> Bool where O.UnwrappedValue: Equatable {
	return lhs.unwrapValue == rhs.unwrapValue
}

func !=<O: OptionalProtocol>(lhs: O, rhs: O) -> Bool where O.UnwrappedValue: Equatable {
	return !(lhs == rhs)
}
