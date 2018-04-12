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


	var promise: Promise<Int>? = nil
	var timer: Repeater?
	var di: DisposableProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()
	
		self.promise = Promise<Int>({ (r, rj) in
			
		})
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

