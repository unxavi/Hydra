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
	
	var channel_1: Channel<Int,NoError>?
	var channel_2: Channel<Int,NoError>?

	var timer_1 : Repeater?
	var timer_2 : Repeater?

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		var count_1: Int = 0
		var count_2: Int = 0
	
		self.channel_1 = Channel({ producer in
			self.timer_1 = Repeater.every(.seconds(1), { _ in
				count_1 += 1
				producer.send(value: count_1)
				if count_1 == 5 {
					producer.complete()
					self.timer_1?.pause()
				}
			})
			return Disposable.dontCare
		})
		
		self.channel_2 = Channel({ producer in
			self.timer_2 = Repeater.every(.seconds(1), { _ in
				count_2 += 1
				producer.send(value: count_2)
				if count_2 == 5 {
					producer.complete()
					self.timer_2?.pause()
				}
			})
			return Disposable.dontCare
		})
		
		self.channel_1!.concat(to: self.channel_2!).subscribe({ event in
			print("\(event)")
		})
		
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

