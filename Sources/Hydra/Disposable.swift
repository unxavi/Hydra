//
//  Disposable.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

public protocol DisposableProtocol {
	func dispose()
	
	var disposed: Bool { get }
}

public struct NotDisposable: DisposableProtocol {
	
	public static let shared = NotDisposable()
	
	public func dispose() {}
	public var disposed: Bool = false
}

public final class Disposable: DisposableProtocol {
	
	public static let dontCare: NotDisposable = NotDisposable.shared
	
	public typealias DisposeCallback = (() -> (Void))

	public var disposed: Bool = false
	
	private var lock: Mutex = Mutex()
	
	private var callback: DisposeCallback?
	
	public init(onDispose callback: DisposeCallback? = nil) {
		self.callback = callback
	}
	
	public static func onDispose(_ callback: DisposeCallback? = nil) -> Disposable {
		return Disposable(onDispose: callback)
	}
	
	public init() {
		
	}
	
	public var linked: DisposableProtocol? {
		didSet {
			self.lock.sync {
				guard self.disposed else { return }
				self.linked?.dispose()
			}
		}
	}
	
	deinit {
		self.dispose()
	}
	
	public func dispose() {
		self.lock.sync {
			guard self.disposed == false else { return }
			
			if let callback = self.callback {
				self.callback = nil
				callback()
			}
			
			self.linked?.dispose()
			self.disposed = true
		}
	}
}
