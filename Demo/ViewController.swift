//
//  ViewController.swift
//  Demo
//
//  Created by Daniele Margutti on 26/02/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import UIKit

public enum Errors: Error {
	
}

class ViewController: UIViewController {
	
	var signal: Channel<Int,NoError>?
	var s1: DisposableProtocol?
	var signalDispose: DisposableProtocol?
	var t: Repeat?

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		self.signal = Channel<Int,NoError>.every(interval: .seconds(2), generator: { iteration in
			return iteration
		})
		
		self.signalDispose = self.signal?.subscribe({ event in
			print("s1 ---> \(event)")
		})
		
		self.t = Repeat.once(after: .seconds(10)) { _ in
			self.signalDispose?.dispose()
		}
		
		/*self.signal = Channel<Int,NoError>({ producer in
			
			self.t = Repeat.every(.seconds(5), { _ in
				let random = Int(arc4random_uniform(100))
				producer.send(.next(random))
			})
			
			return Disposable.onDispose {
				self.t?.pause()
			}
		})
		
		self.signalDispose = self.signal?.subscribe({ event in
			print("s1 ---> \(event)")
		})
		
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(13)) {
			self.signalDispose?.dispose()
		}*/
		
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

