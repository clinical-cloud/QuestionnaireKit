//
//  QuestionnaireItemPromise.swift
//
//  Created by Pascal Pfiffner on 4/20/15.
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

import Foundation
import ModelsR4
import ResearchKit


/**
A promise that can fulfill a questionnaire question into an ORKQuestionStep.
*/
class QuestionnaireItemPromise: QuestionnairePromiseProto {
	
    static let RootId = "{root}"
    
    /// This is the questionnaire root item.
    var isRoot: Bool {
        QuestionnaireItemPromise.RootId == self.linkId
    }
    
	/// The promises' item.
	let item: QuestionnaireItem
    
    /// This questionnaire item is a  sub-group of items, rendered as ORKFormStep
    var isSubGroup: Bool {
        !isRoot && .group == self.item.type && self.parent?.item.item?.count ?? 0 > 1
    }
    
	/// Parent item, if any.
	weak var parent: QuestionnaireItemPromise?
	
	/// The step(s), internally assigned after the promise has been successfully fulfilled.
	internal var steps: [ORKStep]?
    
    /// The item(s), internally assigned after the promise has been successfully fulfilled.
    internal var items: [ORKFormItem]?
    
	
	/**
	Designated initializer.
	
	- parameter question: The question the receiver represents
	*/
    init(item: QuestionnaireItem, parent: QuestionnaireItemPromise? = nil) {
		self.item = item
		self.parent = parent
	}
	
	
	// MARK: - Fulfilling
	
	/**
	Fulfill the promise.
	
	Once the promise has been successfully fulfilled, the `step` property will be assigned. No guarantees as to on which queue the callback
	will be called.
	
	- parameter parentRequirements: Requirements from the parent that must be inherited
	- parameter callback: The callback to be called when done; note that even when you get an error, some steps might have successfully been
	                      allocated still, so don't throw everything away just because you receive errors
	*/
	func fulfill(requiring parentRequirements: [ResultRequirement]?, callback: @escaping (([Error]?) -> Void)) {
		
		// resolve answer format, THEN resolve sub-groups, if any
		item.qk_asAnswerFormat() { format, error in
			var steps = [ORKStep]()
            var items = [ORKFormItem]()
			var thisStep: ConditionalStep?
			var errors = [Error]()
			var requirements = parentRequirements ?? [ResultRequirement]()
//			let (title, text) = self.item.qk_bestTitleAndText()
			let title = self.bestTitle()
			let text = self.item.qk_bestText()
			
			// find item's "enableWhen" requirements
			do {
				if let myreqs = try self.item.qk_enableQuestionnaireElementWhen() {
					requirements.append(contentsOf: myreqs)
				}
			}
			catch let error {
				errors.append(error)
			}
			
			// a question may be hidden from user presentation
			if true == self.item.qk_questionHidden() {
				// skip
			}
            
            // a question may include a display item intended as Help Button text
            if true == self.item.qk_questionHelpButton() {
                // TODO include this as RK info button on question
                // skip
            }
            
//            else if self.isSubGroup && self.item.type == .group {
            else if self.isSubGroup {
                thisStep = ConditionalFormStep(identifier: self.linkId, linkIds: self.linkIds, title: title, text: nil)
            }
            
            // Issue with ResearchKit: presentation of text, numeric or date value entry fields within a Form; exclude from Form, add as question.
            else if self.parent?.isSubGroup == true, let format = format,
                    !(format is ORKTextAnswerFormat), !(format is ORKNumericAnswerFormat),
                    !(format is ORKDateAnswerFormat), !(format is ORKTimeOfDayAnswerFormat) {
                let step = ConditionalFormItem(identifier: self.linkId, linkIds: self.linkIds, text: text, answer: format)
                step.fhirType = self.item.type.value?.rawValue
                step.isOptional = !(self.item.required?.value?.bool ?? false)
                thisStep = step
            }
                
			// we know the answer format, so this is a question, create a conditional step
			else if let fmt = format {
				let step = ConditionalQuestionStep(identifier: self.linkId, linkIds: self.linkIds, title: title, answer: fmt)
				step.fhirType = self.item.type.value?.rawValue
				step.text = text
				step.isOptional = !(self.item.required?.value?.bool ?? false)
				thisStep = step
			}
			else if let error = error {
				errors.append(error)
			}
				
			// no error and no answer format but title and text - must be "display" or "group" item that has something to show!
			else if .display == self.item.type && (nil != text) {
				thisStep = ConditionalInstructionStep(identifier: self.linkId, linkIds: self.linkIds, title: title, text: text)
			}
			
			// TODO: also look at "initial[x]" value and prepopulate
			
			// collect the step
			if var step = thisStep {
				if !requirements.isEmpty {
					step.add(requirements: requirements)
				}
				if let step = step as? ORKStep {
					steps.append(step)
				}
                else if let item = step as? ORKFormItem {
                    items.append(item)
                }
			}
			
			// do we have sub-groups?
			if self.item.qk_questionHidden() != true, let subitems = self.item.item {
                let subpromises = subitems.map() { QuestionnaireItemPromise(item: $0, parent: self) }
				
				// fulfill all group promises
				let queueGroup = DispatchGroup()
				for subpromise in subpromises {
					queueGroup.enter()
					subpromise.fulfill(requiring: requirements) { berrors in
						if nil != berrors {
							errors.append(contentsOf: berrors!)
						}
						queueGroup.leave()
					}
				}
				
				// all done
				queueGroup.notify(queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)) {
					let gsteps = subpromises.filter() { return nil != $0.steps }.flatMap() { return $0.steps! }
                    // Omit form steps that contain no items, e.g. all items were value entry format
                    let gstepsComplete = gsteps.filter() {
                        if let formStep = $0 as? ORKFormStep {
                            return (false == formStep.formItems?.isEmpty) ? true : false
                        }
                        return true
                    }
					steps.append(contentsOf: gstepsComplete)
					self.steps = steps
                                 
                    let gitems = subpromises.filter() { return nil != $0.items }.flatMap() { return $0.items! }
                    items.append(contentsOf: gitems)
                    self.items = items
                    if let form = thisStep as? ORKFormStep {
                        form.formItems = self.items
                    }
                                 
					callback(errors.count > 0 ? errors : nil)
				}
			}
			else {
				self.steps = steps
                self.items = items
				callback(errors)
			}
		}
	}
	
	func bestTitle() -> String? {
		var title: String?
		
		var promise: QuestionnaireItemPromise? = self
		while title == nil, promise != nil {
			title = promise?.item.qk_questionTitle()
			if nil == title, promise?.item.type.value == .group {
				title = promise?.item.text?.value?.string
			}
			promise = promise?.parent
		}
		// TODO get Questionnaire.title if no groups include text element
		
		return title
	}
	
	// MARK: - Properties
	
	var linkId: String {
		return item.linkId.value?.string ?? UUID().uuidString
	}
	
	/// Returns an array of all linkIds of the parents down to the receiver.
	var linkIds: [String] {
		var ids = [String]()
		var prnt = parent
        while let parent = prnt {
            if parent.linkId != QuestionnaireItemPromise.RootId {
                ids.append(parent.linkId)
            }
			prnt = parent.parent
		}
		return ids
	}
	
	
	// MARK: - Printable
	
	/// String representation of the receiver.
	var description: String {
		return "<\(type(of: self))>"
	}
}
