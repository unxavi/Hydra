//
//  Promise+Operators.swift
//  Hydra
//
//  Created by Daniele Margutti on 13/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension Promise {
	
	public func then<V>(in context: Context? = nil, _ body: @escaping ((V) -> ()) ) -> Promise<V> {
		return self.chain(in: context ?? .background, fulfill: { value in
			body(value)
			return value
		}, reject: nil) as! Promise<V>
	}
	
}
