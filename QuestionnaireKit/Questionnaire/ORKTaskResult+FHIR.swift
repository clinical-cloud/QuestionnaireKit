//
//  ORKTaskResult+FHIR.swift
//
//  Created by Pascal Pfiffner on 6/26/15.
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

import ResearchKit
import FHIR


/**
Extend ORKTaskResult to add functionality to convert to QuestionnaireResponse.
*/
extension ORKTaskResult {
	
	/**
	Extracts all results from the task and converts them to a FHIR QuestionnaireResponse.
	
	- parameter for: The task the receiver is a result for
	- returns:       A `QuestionnaireResponse` resource or nil
	*/
	public func qk_asQuestionnaireResponse(for task: ORKTask?) -> QuestionnaireResponse? {
		guard let results = results as? [ORKStepResult] else {
			return nil
		}
		
		// loop results to collect groups
		var groups = [QuestionnaireResponseItem]()
		for result in results {
			if let items = result.qk_responseItems(from: task) {
				groups.append(contentsOf: items)
			}
		}
		
		// create and return questionnaire answers
//		let questionnaire = Reference()
//		questionnaire.reference = FHIRString(identifier)
		
		let answer = QuestionnaireResponse(status: .completed)
		//TODO need the source Questionnaire canonical URI
//		answer.questionnaire = questionnaireURI
		answer.item = groups
		answer.deduplicateItemsByLinkId()
		return answer
	}
}


extension ORKStepResult {
	
	/**
	Creates a QuestionnaireResponseItem resource from all ORKSteps in the given ORKTask. Questions that do not have answers will be omitted,
	and groups that do not have at least a single question with answer will likewise be omitted.
	
	- parameter task: The ORKTask the result belongs to
	- returns: A QuestionnaireResponseItem element or nil
	*/
	func qk_responseItems(from task: ORKTask?) -> [QuestionnaireResponseItem]? {
		if let results = results {
			var items = [QuestionnaireResponseItem]()
			
			// loop results to collect answers; omit questions that do not have answers
			for result in results {
				if let result = result as? ORKQuestionResult {
					if let question = task?.step?(withIdentifier: result.identifier) as? ORKQuestionStep, let answers = result.qk_responseItemAnswers(from: question) {
						var response = QuestionnaireResponseItem(linkId: result.identifier.fhir_string)
						response.answer = answers
						
						// wrap into parent items - will dedupe by linkId later
						if let conditional = question as? ConditionalStep {
							var parentIds = conditional.linkIds
							while let parentId = parentIds.popLast() {
								let parent = QuestionnaireResponseItem(linkId: parentId.fhir_string)
								parent.item = [response]
								response = parent
							}
						}
						items.append(response)
					}
				}
				else {
					qk_warn("I cannot handle ORKStepResult result \(result)")
				}
			}
			
			// return non-nil if we have at least one response item
			if items.count > 0 {
				return items
			}
		}
		return nil
	}
}


extension ORKQuestionResult {
	
	/**
	Instantiate a QuestionnaireResponse.item.answer element from the receiver's answer, if any.
	
	TODO: Cannot override methods defined in extensions, hence we need to check for the ORKQuestionResult subclass and then call the
	method implemented in the extensions below.
	
	- parameter from: The ORKQuestionStep the responses belong to
	- returns:        An array of question answers or nil
	*/
	func qk_responseItemAnswers(from step: ORKQuestionStep?) -> [QuestionnaireResponseItemAnswer]? {
		let fhirType = (step as? ConditionalQuestionStep)?.fhirType
		
		if let this = self as? ORKChoiceQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKTextQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKNumericQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKScaleQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKBooleanQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKTimeOfDayQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKTimeIntervalQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		if let this = self as? ORKDateQuestionResult {
			return this.qk_responseItems(ofFHIRType: fhirType)
		}
		qk_warn("I don't understand ORKQuestionResult answer from \(self)")
		return nil
	}
	
	/**
	Checks whether the receiver is the same result as the other result.
	
	- parameter other: The result to compare against
	- returns: A bool indicating whether the results are the same
	*/
	func qk_hasSameResponse(_ other: ORKQuestionResult) -> Bool {
		if let myChoiceAnswers = answer as? NSArray {
			if let otherAnswers = other.answer as? NSArray {
				for otherAnswer in otherAnswers {
					if myChoiceAnswers.contains(otherAnswer) {
						return true
					}
				}
			}
			else if let otherAnswer = other.answer as? NSObject {
				return myChoiceAnswers.contains(otherAnswer)
			}
		}
		else if let myAnswer = answer as? NSObject {
			if let otherAnswers = other.answer as? NSArray {
				return otherAnswers.contains(myAnswer)
			}
			else if let otherAnswer = other.answer as? NSObject {
				return myAnswer.isEqual(otherAnswer)
			}
		}
		return false
	}
}


extension ORKChoiceQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; ignored, always "coding"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let choices = choiceAnswers as? [String] else {
			if let choices = choiceAnswers {
				qk_warn("expecting choice question results to be strings, but got: \(choices)")
			}
			return nil
		}
		var answers = [QuestionnaireResponseItemAnswer]()
		for choice in choices {
			let answer = QuestionnaireResponseItemAnswer()
			let splat = choice.split() { $0 == kORKTextChoiceSystemSeparator }.map() { String($0) }
			let system = splat[0]
			let code = (splat.count > 1) ? splat[1..<splat.endIndex].joined(separator: String(kORKTextChoiceSystemSeparator)) : kORKTextChoiceMissingCodeCode
			answer.valueCoding = Coding()
			answer.valueCoding!.system = FHIRURL(system)
			answer.valueCoding!.code = FHIRString(code)
			answers.append(answer)
		}
		return answers
	}
}


extension ORKTextQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; "url" or defaults to "string"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let text = textAnswer else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		if let fhir = ofFHIRType, "url" == fhir {
			answer.valueUri = FHIRURL(text)
		}
		else {
			answer.valueString = FHIRString(text)
		}
		return [answer]
	}
}


extension ORKNumericQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; "quantity", "integer" or defaults to "number"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let numeric = numericAnswer else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		if let fhir = ofFHIRType, "quantity" == fhir {
			answer.valueQuantity = Quantity()
			answer.valueQuantity!.value = FHIRDecimal(numeric.decimalValue)
			answer.valueQuantity!.unit = unit?.fhir_string
		}
		else if let fhir = ofFHIRType, "integer" == fhir {
			answer.valueInteger = FHIRInteger(numeric.int32Value)
		}
		else {
			answer.valueDecimal = FHIRDecimal(numeric.decimalValue)
		}
		return [answer]
	}
}


extension ORKScaleQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; ignored, always "number"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let numeric = scaleAnswer else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		answer.valueDecimal = FHIRDecimal(numeric.decimalValue)
		return [answer]
	}
}


extension ORKBooleanQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; ignored, always "boolean"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let boolean = booleanAnswer?.boolValue else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		answer.valueBoolean = FHIRBool(boolean)
		return [answer]
	}
}


extension ORKTimeOfDayQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; ignored, always "time"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let components = dateComponentsAnswer else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		answer.valueTime = FHIRTime(hour: UInt8(components.hour ?? 0), minute: UInt8(components.minute ?? 0), second: 0.0)
		return [answer]
	}
}


extension ORKTimeIntervalQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	TODO: implement!
	
	- parameter ofFHIRType: The FHIR answer type that's expected; ignored, always "interval"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let interval = intervalAnswer else {
			return nil
		}
		//let answer = QuestionnaireResponseItemAnswer()
		// TODO: support interval answers
		print("--->  \(interval) for FHIR type “\(String(describing: ofFHIRType))”")
		return nil
	}
}


extension ORKDateQuestionResult {
	
	/**
	Creates question answers of the receiver.
	
	- parameter ofFHIRType: The FHIR answer type that's expected; supports "date", "dateTime" (default) and "instant"
	- returns: An array of question answers or nil
	*/
	func qk_responseItems(ofFHIRType: String?) -> [QuestionnaireResponseItemAnswer]? {
		guard let date = dateAnswer else {
			return nil
		}
		let answer = QuestionnaireResponseItemAnswer()
		switch ofFHIRType ?? "dateTime" {
		case "date":
			answer.valueDate = date.fhir_asDate()
		case "dateTime":
			let dateTime = date.fhir_asDateTime()
//			if let tz = timeZone {
//				dateTime.timeZone = tz			// TODO: reported NSDate is in UTC, convert to the given time zone
//			}
			answer.valueDateTime = dateTime
		default:
			qk_warn("unknown date-time FHIR type “\(ofFHIRType!)”, treating as dateTime")
			let dateTime = date.fhir_asDateTime()
//			if let tz = timeZone {
//				dateTime.timeZone = tz
//			}
			answer.valueDateTime = dateTime
		}
		return [answer]
	}
}

