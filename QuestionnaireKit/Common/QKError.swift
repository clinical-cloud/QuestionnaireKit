//
//  QKError.swift
//
//  Created by Pascal Pfiffner on 20/10/15.
//  Copyright © 2015 Boston Children's Hospital. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SMART


/// The FHIR version used by this instance of the framework.
public let QuestionnaireKitFHIRVersion = "4.0.0"


/**
Errors thrown around when working with QuestionnaireKit.
*/
public enum QKError: Error, CustomStringConvertible {
	
	/// The mentioned feature is not implemented.
	case notImplemented(String)
	
	/// An error holding on to multiple other errors.
	case multipleErrors(Array<Error>)
	
	
	// MARK: App
	
	/// The app's /Library directory is not present.
	case appLibraryDirectoryNotPresent
	
	/// Failed to refreish the App Store receipt.
	case appReceiptRefreshFailed
	
	/// The respective file was not found in the app bundle.
	case bundleFileNotFound(String)
	
	/// A JSON file does not have the expected structure.
	case invalidJSON(String)
	
	/// The layout of the storyboard is not as expected.
	case invalidStoryboard(String)
	
	
	// MARK: FHIR
	
	/// A FHIR extension is invalid in the respective context.
	case extensionInvalidInContext
	
	/// A FHIR extension is incomplete.
	case extensionIncomplete(String)
	
	
	// MARK: Server
	
	/// No server is configured.
	case serverNotConfigured
	
	
	// MARK: Questionnaire
	
	/// The questionnaire is not present.
	case questionnaireNotPresent
	
	/// The questionnaire does not have a top level item.
	case questionnaireInvalidNoTopLevelItem
	
	/// The given questionnaire question type cannot be represented in ResearchKit.
	case questionnaireQuestionTypeUnknownToResearchKit(QuestionnaireItem)
	
	/// The given question should provide choices but there are none.
	case questionnaireNoChoicesInChoiceQuestion(QuestionnaireItem)
	
	/// The 'item.enableWhen' property is incomplete.
	case questionnaireEnableWhenIncomplete(String)
	
	/// The questionnaire finished with an error (i.e. was not completed).
	case questionnaireFinishedWithError
	
	/// Unknown error handling questionnaire.
	case questionnaireUnknownError
	
	
	// MARK: - Custom String Convertible
	
	/// A string representation of the error.
	public var description: String {
		switch self {
		case .notImplemented(let message):
			return "Not yet implemented: \(message)"
		case .multipleErrors(let errs):
			if 1 == errs.count {
				return "\(errs[0])"
			}
			let summaries = errs.map() { "\($0)" }.reduce("") { $0 + (!$0.isEmpty ? "\n" : "") + $1 }
			return "Multiple errors occurred:\n\(summaries)"
		
		case .appLibraryDirectoryNotPresent:
			return "The app library directory could not be found; this is likely fatal"
		case .appReceiptRefreshFailed:
			return "App receipt refresh failed. Are you running on device?"
		case .bundleFileNotFound(let name):
			return name
		case .invalidJSON(let reason):
			return "Invalid JSON: \(reason)"
		case .invalidStoryboard(let reason):
			return "Invalid Storyboard: \(reason)"
		
		case .extensionInvalidInContext:
			return "This extension is not valid in this context"
		case .extensionIncomplete(let reason):
			return "Extension is incomplete: \(reason)"
		
		case .serverNotConfigured:
			return "No server has been configured"
		
		case .questionnaireNotPresent:
			return "I do not have a questionnaire just yet"
		case .questionnaireInvalidNoTopLevelItem:
			return "Invalid questionnaire, does not contain a top level item"
		case .questionnaireQuestionTypeUnknownToResearchKit(let question):
			return "Failed to map question type “\(question.type?.rawValue ?? "<nil>")” to ResearchKit answer format [linkId: \(question.linkId ?? "<nil>")]"
		case .questionnaireNoChoicesInChoiceQuestion(let question):
			return "There are no choices in question “\(question.text ?? "")” [linkId: \(question.linkId ?? "<nil>")]"
		case .questionnaireEnableWhenIncomplete(let reason):
			return "item.enableWhen is incomplete: \(reason)"
		case .questionnaireFinishedWithError:
			return "Unknown error finishing questionnaire"
		case .questionnaireUnknownError:
			return "Unknown error handling questionnaire"
		}
	}
}


/**
Ensures that the given block is executed on the main queue.

- parameter block: The block to execute on the main queue.
*/
public func qk_performOnMainQueue(_ block: @escaping (() -> Void)) {
	if Thread.current.isMainThread {
		block()
	}
	else {
		DispatchQueue.main.async {
			block()
		}
	}
}


/**
Prints the given message to stdout if `DEBUG` is defined and true. Prepends filename, line number and method/function name.
*/
public func qk_logIfDebug(_ message: @autoclosure () -> String, function: String = #function, file: NSString = #file, line: Int = #line) {
	#if DEBUG
		print("[\(file.lastPathComponent):\(line)] \(function)  \(message())")
	#endif
}


/**
Prints the given message to stdout. Prepends filename, line number, method/function name and "WARNING:".
*/
public func qk_warn(_ message: @autoclosure () -> String, function: String = #function, file: NSString = #file, line: Int = #line) {
	print("[\(file.lastPathComponent):\(line)] \(function)  WARNING: \(message())")
}

