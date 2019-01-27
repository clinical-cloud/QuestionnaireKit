//
//  ResourceJsonViewController.swift
//
//  Created by David Carlson on 3/15/18.
//

import UIKit
import SMART

class ResourceJsonViewController: UIViewController {
	
	@IBOutlet var detailDescriptionLabel: UILabel?
	
	/// The resource to show JSON detail
	var resource: Resource? {
		didSet {
			configureView()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		configureView()
	}

	func configureView() {
		guard let label = detailDescriptionLabel else {
			return
		}
		if let detail = resource {
			self.title? = type(of: detail).resourceType
			
			do {
				let data = try JSONSerialization.data(withJSONObject: detail.asJSON(), options: .prettyPrinted)
				let string = String(data: data, encoding: String.Encoding.utf8)
				label.text = string ?? "Unable to generate JSON"
			}
			catch let error {
				label.text = "\(error)"
			}
		}
		else {
			var style = UIFont.TextStyle.headline
			if #available(iOS 9, *) {
				style = .title1
			}
			let p = NSMutableParagraphStyle()
			p.alignment = .center
			p.paragraphSpacingBefore = 200.0
			let attr = NSAttributedString(string: "Select a FHIR Resource first", attributes: convertToOptionalNSAttributedStringKeyDictionary([
				convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.preferredFont(forTextStyle: style),
				convertFromNSAttributedStringKey(NSAttributedString.Key.paragraphStyle): p,
				]))
			label.attributedText = attr
		}
	}
	
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
