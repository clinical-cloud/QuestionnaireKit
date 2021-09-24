//
//  ORKTaskResult+FHIR.swift
//
//  Created by Pascal Pfiffner on 6/26/15.
//  Copyright © 2015 Boston Children's Hospital. All rights reserved.
//
//  Modified by Dave Carlson on 08/30/2021.
//  Copyright © 2021 Clinical Cloud Solutions, LLC. All rights reserved.
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
import ModelsR4


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
		
		let answer = QuestionnaireResponse(status: QuestionnaireResponseStatus.completed.asPrimitive())
        answer.id = UUID().uuidString.asFHIRStringPrimitive()
        answer.authored = try? DateTime(date: Date()).asPrimitive()
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
						var response = QuestionnaireResponseItem(linkId: result.identifier.asFHIRStringPrimitive())
                        response.text = question.text?.asFHIRStringPrimitive()
						response.answer = answers
						
						// wrap into parent items - will dedupe by linkId later
						if let conditional = question as? ConditionalStep {
							var parentIds = conditional.linkIds
							while let parentId = parentIds.popLast() {
								let parent = QuestionnaireResponseItem(linkId: parentId.asFHIRStringPrimitive())
								parent.item = [response]
								response = parent
							}
						}
						items.append(response)
                    }
                    else if let orderedTask = task as? ORKOrderedTask {
                        for step in orderedTask.steps {
                            if let form = step as? ORKFormStep {
                                for formItem in form.formItems ?? [] {
                                    if formItem.identifier == result.identifier, let answers = result.qk_responseItemAnswers(from: formItem) {
                                        var response = QuestionnaireResponseItem(linkId: result.identifier.asFHIRStringPrimitive())
                                        response.text = formItem.text?.asFHIRStringPrimitive()
                                        response.answer = answers
                                        
                                        // wrap into parent items - will dedupe by linkId later
                                        if let conditional = formItem as? ConditionalStep {
                                            var parentIds = conditional.linkIds
                                            while let parentId = parentIds.popLast() {
                                                let parent = QuestionnaireResponseItem(linkId: parentId.asFHIRStringPrimitive())
                                                parent.item = [response]
                                                response = parent
                                            }
                                        }
                                        items.append(response)
                                    }
                                }
                            }
                        }
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
    
    func qk_responseItemAnswers(from item: ORKFormItem?) -> [QuestionnaireResponseItemAnswer]? {
        let fhirType = (item as? ConditionalFormItem)?.fhirType
        
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
            if let coding = try? JSONDecoder().decode(Coding.self, from: choice.data(using: .utf8)!) {
                answer.value = QuestionnaireResponseItemAnswer.ValueX.coding(coding)
            }
            else {
                answer.value = QuestionnaireResponseItemAnswer.ValueX.string(choice.asFHIRStringPrimitive())
            }
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
		if let fhir = ofFHIRType, "url" == fhir, let uri = text.asFHIRURIPrimitive() {
			answer.value = QuestionnaireResponseItemAnswer.ValueX.uri(uri)
		}
		else {
			answer.value = QuestionnaireResponseItemAnswer.ValueX.string(text.asFHIRStringPrimitive())
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
			let quantity = Quantity(unit: unit?.asFHIRStringPrimitive(), value: numeric.doubleValue.asFHIRDecimalPrimitive())
			answer.value = QuestionnaireResponseItemAnswer.ValueX.quantity(quantity)
		}
		else if let fhir = ofFHIRType, "integer" == fhir {
			answer.value = QuestionnaireResponseItemAnswer.ValueX.integer(numeric.intValue.asFHIRIntegerPrimitive())
		}
		else {
			answer.value = QuestionnaireResponseItemAnswer.ValueX.decimal(numeric.doubleValue.asFHIRDecimalPrimitive())
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
		answer.value = QuestionnaireResponseItemAnswer.ValueX.decimal(numeric.doubleValue.asFHIRDecimalPrimitive())
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
		answer.value = QuestionnaireResponseItemAnswer.ValueX.boolean(boolean.asPrimitive())
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
		let fhirTime = FHIRTime(hour: UInt8(components.hour ?? 0), minute: UInt8(components.minute ?? 0), second: 0.0)
		answer.value = QuestionnaireResponseItemAnswer.ValueX.time(fhirTime.asPrimitive())
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
			if let fhirDate = try? FHIRDate(date: date) {
				answer.value = QuestionnaireResponseItemAnswer.ValueX.date(fhirDate.asPrimitive())
			}
		case "dateTime":
//			if let tz = timeZone {
//				dateTime.timeZone = tz			// TODO: reported NSDate is in UTC, convert to the given time zone
//			}
			if let fhirDateTime = try? DateTime(date: date) {
				answer.value = QuestionnaireResponseItemAnswer.ValueX.dateTime(fhirDateTime.asPrimitive())
			}
		default:
			qk_warn("unknown date-time FHIR type “\(ofFHIRType!)”, treating as dateTime")
			if let fhirDateTime = try? DateTime(date: date) {
				answer.value = QuestionnaireResponseItemAnswer.ValueX.dateTime(fhirDateTime.asPrimitive())
			}
		}
		return [answer]
	}
}

