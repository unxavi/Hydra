//
//  Disposable.swift
//  Hydra
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import Foundation

/// Protocol for disposable
public protocol DisposableProtocol {
	
	/// Implement this method to do some stuff and mark the disposable
	/// as disposed at the end.
	func dispose()
	
	/// Is the disposable disposed?
	var disposed: Bool { get }
}

/// Non disposable is just a disposable which never dispose.
/// Typically you will return it using `Disposable.dontCare` when
/// you don't need to make a channel provider or a subscription disposable.
public struct NotDisposable: DisposableProtocol {
	
	/// Singleton
	public static let shared = NotDisposable()
	
	/// Dispose (don't anything)
	public func dispose() {}
	
	/// A `NotDisposable` cannot be disposed anytime soon.
	public var disposed: Bool = false
}

/// Disposable class
public final class Disposable: DisposableProtocol {
	
	/// Shortcut to dont care disposable class
	public static let dontCare: NotDisposable = NotDisposable.shared
	
	/// Callback
	public typealias DisposeCallback = (() -> (Void))

	/// is disposable disposed
	public var disposed: Bool = false
	
	/// thread-safe
	private var lock: Mutex = Mutex()
	
	/// callback called on dispose
	private var callback: DisposeCallback?
	
	/// Initialize a new dispose with optional callback to call on dispose.
	///
	/// - Parameter callback: callback called on dispose
	public init(onDispose callback: DisposeCallback? = nil) {
		self.callback = callback
	}
	
	/// Create a new disposable with given callback called on dispose.
	///
	/// - Parameter callback: callback called on dispose.
	/// - Returns: disposable
	public static func onDispose(_ callback: DisposeCallback? = nil) -> Disposable {
		return Disposable(onDispose: callback)
	}

	
	/// Associate a linked disposable which will be disposed upon the dispose of `self`.
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
	
	/// Dispose disposable in thread-safe manner.
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


/// DisposeBag manage a collection of DisposableProtocol instances.
/// Once you dispose the bag all managed disposables will be also disposed too.
/// Both dispose and insertion of a new disposable into the bag is thread safe.
public class DisposableBag: DisposableProtocol {
	
	/// Is bag disposed yet
	public var disposed: Bool = false
	
	/// List of disposable managed by the bag
	private var list: [DisposableProtocol]
	
	/// Lock mutex
	private var lock: Mutex = Mutex()
	
	/// Initialize with a list of disposable.
	///
	/// - Parameter disposables: optional list of disposable
	public init(disposables: [DisposableProtocol]? = nil) {
		self.list = (disposables ?? [])
	}
	
	/// Add a disposable to the bag.
	/// If disposable bag is disposed yet we just dispose input disposable.
	///
	/// - Parameter disposable: disposable to add
	public func insert(_ disposable: DisposableProtocol) {
		self.lock.sync {
			// If the bag is disposed yet we just dispose our new
			// disposable.
			guard self.disposed == false else {
				disposable.dispose()
				return
			}
			// Otherwise just append disposable
			self.list.append(disposable)
			self.list = self.list.filter { !$0.disposed }
		}
	}
	
	/// + operator to append a disposable to the bag.
	///
	/// - Parameters:
	///   - lhs: disposable bag destination of the operation.
	///   - rhs: disposable to add
	public static func += (lhs: DisposableBag, rhs: DisposableProtocol) {
		lhs.insert(rhs)
	}
	
	/// Dispose a bag
	public func dispose() {
		self.lock.sync {
			self.list.forEach { $0.dispose() }
			self.list.removeAll()
			self.disposed = true
		}
	}
	
}
