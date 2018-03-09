//
//  Binding.swift
//  Hydra
//
//  Created by Daniele Margutti on 06/03/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public protocol BindingProtocol {
	
	associatedtype BindedValue
	
	func bind(channel: Channel<BindedValue, NoError>) -> DisposableProtocol
}
