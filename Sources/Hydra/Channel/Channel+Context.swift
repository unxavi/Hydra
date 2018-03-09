//
//  Channel+Context.swift
//  Hydra
//
//  Created by Daniele Margutti on 09/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension ChannelProtocol {
	
	/// Execute receiver signal in context specified.
	///
	/// - Parameter context: context of the execution
	/// - Returns: channel
	public func exec(in context: Context) -> Channel<Value,Error> {
		return Channel({ producer in
			return self.subscribe({ event in
				context.execute {
					producer.send(event)
				}
			})
		})
	}
	
}
