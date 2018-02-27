//
//  Dispatch.swift
//  Hydra-iOS
//
//  Created by danielemargutti on 27/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public extension DispatchQueue {
	
	/// Dispatch the execution of given callback by a specified interval expressed in seconds.
	///
	/// - Parameters:
	///   - interval: interval since the execution of the job.
	///   - job: job to execute.
	/// - Returns: disposable
	@discardableResult
	public func after(_ interval: TimeInterval, _ job: @escaping (() -> (Void))) -> Disposable {
		let disposable = Disposable()
		self.asyncAfter(deadline: .now() + interval) {
			guard disposable.disposed == false else { return } // already disposed, ignore call
			job()
		}
		return disposable
	}
	
}
