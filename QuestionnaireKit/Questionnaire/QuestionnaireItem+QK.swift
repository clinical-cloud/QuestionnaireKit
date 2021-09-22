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


let kORKTextChoiceSystemSeparator: Character = " "
let kORKTextChoiceDefaultSystem = "https://fhir.smalthealthit.org"
let kORKTextChoiceMissingCodeCode = "⚠️"


extension QuestionnaireItem {
    
    /**
    Attempts to create a text display from the various fields of the group.
    
    - returns: string for text field
    */
    func qk_bestText() -> String? {
        let cDisplay = code?.compactMap() { return $0.display?.value?.string.qk_localized }
        let cCodes = code?.compactMap() { return $0.code?.value?.string }        // TODO: can these be localized?
        
        var txt = text?.value?.string.qk_localized
        
        if nil == txt {
            txt = qk_questionInstruction() ?? qk_questionHelpText()        // even if the title is still nil, we won't want to populate the title with help text
        }
        // TODO: Even if we have instructions, show help somewhere if present
        
        if nil == txt {
            // txt should not be nil at this point, but use code as a last resort
            txt = cDisplay?.first ?? cCodes?.first
        }
        
        return txt?.qk_stripMultipleSpaces()
    }
    
    /**
    Attempts to create a nice title and text from the various fields of the group.
    
    - returns: A tuple of strings for title and text
    */
    func qk_bestTitleAndText() -> (String?, String?) {
        let cDisplay = code?.compactMap() { return $0.display?.value?.string.qk_localized }
        let cCodes = code?.compactMap() { return $0.code?.value?.string }        // TODO: can these be localized?
        
//        var ttl = cDisplay?.first ?? cCodes?.first
        let ttl = qk_questionTitle()
        var txt = text?.value?.string.qk_localized
        
        if nil == txt {
            txt = qk_questionInstruction() ?? qk_questionHelpText()        // even if the title is still nil, we won't want to populate the title with help text
        }
        // TODO: Even if we have title and instructions, show help somewhere if present
        
        if nil == txt {
            // txt should not be nil at this point, but use code as a last resort
            txt = cDisplay?.first ?? cCodes?.first
        }
        
        return (ttl?.qk_stripMultipleSpaces(), txt?.qk_stripMultipleSpaces())
    }
    
    /**
    Determine ResearchKit's answer format for the question type.
    
    Questions are multiple choice if "repeats" is set to true and the "max-occurs" extension is either not defined or larger than 1. See
    `qk_answerChoiceStyle`.
    
    TODO: "open-choice" allows to choose an option OR to give a textual response: implement
    
    [x] ORKScaleAnswerFormat:           "integer" plus min- and max-values defined, where max > min
    [ ] ORKContinuousScaleAnswerFormat:
    [x] ORKValuePickerAnswerFormat:     "choice" (not multiple) plus extension `kQKValuePickerFormatExtensionURL` (bool)
    [ ] ORKImageChoiceAnswerFormat:
    [x] ORKTextAnswerFormat:            "string", "text", "url"
    [x] ORKTextChoiceAnswerFormat:      "choice", "choice-open" (!)
    [x] ORKBooleanAnswerFormat:         "boolean"
    [x] ORKNumericAnswerFormat:         "decimal", "integer", "quantity"
    [x] ORKDateAnswerFormat:            "date", "dateTime", "instant"
    [x] ORKTimeOfDayAnswerFormat:       "time"
    [ ] ORKTimeIntervalAnswerFormat:
    */
    func qk_asAnswerFormat(callback: @escaping ((ORKAnswerFormat?, Error?) -> Void)) {
        if let itemType = type.value {
            switch itemType {
            case .boolean:      callback(ORKAnswerFormat.booleanAnswerFormat(), nil)
            case .decimal:      callback(ORKAnswerFormat.decimalAnswerFormat(withUnit: nil), nil)
            case .integer:
                let minVal = qk_minValueInt()
                let maxVal = qk_maxValueInt()
                if let minVal = minVal, let maxVal = maxVal, maxVal > minVal {
                    let minDesc = qk_minValueString()?.qk_localized
                    let maxDesc = qk_maxValueString()?.qk_localized
                    
                    // TOOD default value in R4?
//                    let defVal = qk_defaultAnswer()?.valueInteger?.int ?? minVal
                    let defVal =  minVal
                    let format = ORKAnswerFormat.scale(withMaximumValue: Int(maxVal), minimumValue: Int(minVal), defaultValue: Int(defVal),
                        step: 1, vertical: (maxVal - minVal > 5),
                        maximumValueDescription: maxDesc, minimumValueDescription: minDesc)
                    callback(format, nil)
                    
                }
                else {
                    callback(ORKAnswerFormat.integerAnswerFormat(withUnit: nil), nil)
                }
            case .quantity:  callback(ORKAnswerFormat.decimalAnswerFormat(withUnit: qk_numericAnswerUnit()?.code?.value?.string), nil)
            case .date:      callback(ORKAnswerFormat.dateAnswerFormat(), nil)
            case .dateTime:  callback(ORKAnswerFormat.dateTime(), nil)
            case .time:      callback(ORKAnswerFormat.timeOfDayAnswerFormat(), nil)
            case .string:    callback(ORKAnswerFormat.textAnswerFormat(), nil)
            case .text:      callback(ORKAnswerFormat.textAnswerFormat(), nil)
            case .url:       callback(ORKAnswerFormat.textAnswerFormat(), nil)
            case .choice:
                qk_resolveAnswerChoices() { choices, error in
                    if nil != error || nil == choices {
                        callback(nil, error ?? QKError.questionnaireNoChoicesInChoiceQuestion(self))
                    }
                    else {
                        let multiStyle = self.qk_answerChoiceStyle()
                        if .multipleChoice != multiStyle, self.qk_valuePickerFormat() ?? false {
                            callback(ORKAnswerFormat.valuePickerAnswerFormat(with: choices!), nil)
                        }
                        else {
                            callback(ORKAnswerFormat.choiceAnswerFormat(with: multiStyle, textChoices: choices!), nil)
                        }
                    }
                }
            case .openChoice:
                qk_resolveAnswerChoices() { choices, error in
                    if nil != error || nil == choices {
                        callback(nil, error ?? QKError.questionnaireNoChoicesInChoiceQuestion(self))
                    }
                    else {
                        callback(ORKAnswerFormat.choiceAnswerFormat(with: self.qk_answerChoiceStyle(), textChoices: choices!), nil)
                    }
                }
            //case .attachment:    callback(format: nil, error: nil)
            //case .reference: callback(format: nil, error: nil)
            case .display:
                callback(nil, nil)
            case .group:
                callback(nil, nil)
            default:
                callback(nil, QKError.questionnaireQuestionTypeUnknownToResearchKit(self))
            }
        }
    }
    
    /**
    For `choice` type questions, retrieves the possible answers and returns them as ORKTextChoice in the callback.
    
    The `value` property of the text choice is a combination of the coding system URL and the code, separated by
    `kORKTextChoiceSystemSeparator` (a space). If no system URL is provided, "https://fhir.smalthealthit.org" is used.
    */
    func qk_resolveAnswerChoices(callback: @escaping (([ORKTextChoice]?, Error?) -> Void)) {
        
        // options are defined inline
        if let optionList = answerOption {
            // TODO: implement localization of option text
            // TODO: implement date, integer, and time
            // TODO Get option score from extension -- Where/how to recored in questionnaire response?
            
            var choices = [ORKTextChoice]()
            
            for optionItem in optionList {
                if case .string(let valueString) = optionItem.value, let value = valueString.value?.string {
                    let text = ORKTextChoice(text: value, value: value as NSCoding & NSCopying & NSObjectProtocol)
                    choices.append(text)
                }
                else if case .coding(let valueCoding) = optionItem.value {
                    // TODO Implement a Coding: Codeable class to use as value and record into response.
                    //         Also use this for value set options.
                    
                    let system = valueCoding.system?.value?.url.absoluteString ?? kORKTextChoiceDefaultSystem
                    let code = valueCoding.code?.value?.string ?? kORKTextChoiceMissingCodeCode
                    let valueString = "\(system)\(kORKTextChoiceSystemSeparator)\(code)"
                    let text = ORKTextChoice(text: valueCoding.display?.value?.string ?? code, value: valueString as NSCoding & NSCopying & NSObjectProtocol)
                    choices.append(text)
                }
            }
            
            // all done
            if choices.count > 0 {
                callback(choices, nil)
            }
            else {
                callback(nil, QKError.questionnaireNoChoicesInChoiceQuestion(self))
            }
        }
        
        // options are a referenced ValueSet
        else if let options = answerValueSet {
            QKDebugLogger().warn(msg: "Error: Cannot resolve answer ValueSet reference: \(options.value ?? "unknown")")
            callback(nil, QKError.questionnaireNoChoicesInChoiceQuestion(self))
            
            /*
            options.resolve(ValueSet.self) { valueSet in
                var choices = [ORKTextChoice]()
                
                // we have an expanded ValueSet
                if let expansion = valueSet?.expansion?.contains {
                    for option in expansion {
                        let system = option.system?.absoluteString ?? kORKTextChoiceDefaultSystem
                        let code = option.code?.string ?? kORKTextChoiceMissingCodeCode
                        let value = "\(system)\(kORKTextChoiceSystemSeparator)\(code)"
                        let text = ORKTextChoice(text: option.display_localized ?? code, value: value as NSCoding & NSCopying & NSObjectProtocol)
                        choices.append(text)
                    }
                }
                
                // valueset includes or defines codes
                else if let compose = valueSet?.compose {
                    if let options = compose.include {
                        for option in options {
                            let system = option.system?.absoluteString ?? kORKTextChoiceDefaultSystem    // system is a required property
                            if let concepts = option.concept {
                                for concept in concepts {
                                    let code = concept.code?.string ?? kORKTextChoiceMissingCodeCode    // code is a required property, so SHOULD always be present
                                    let value = "\(system)\(kORKTextChoiceSystemSeparator)\(code)"
                                    let text = ORKTextChoice(text: concept.display_localized ?? code, value: value as NSCoding & NSCopying & NSObjectProtocol)
                                    choices.append(text)
                                }
                            }
                        }
                    }
                    // TODO: also support `import`
                }
                
                // all done
                if choices.count > 0 {
                    callback(choices, nil)
                }
                else {
                    callback(nil, QKError.questionnaireNoChoicesInChoiceQuestion(self))
                }
            }
            */
        }
        else {
            callback(nil, QKError.questionnaireNoChoicesInChoiceQuestion(self))
        }
    }
    
    /**
    For `choice` type questions, inspect if the given question is single or multiple choice. Questions are multiple choice if "repeats" is
    true and the "max-occurs" extension is either not defined or larger than 1.
    */
    func qk_answerChoiceStyle() -> ORKChoiceAnswerStyle {
        let multiple = (repeats?.value?.bool ?? false) && ((qk_questionMaxOccurs() ?? 2) > 1)
        return multiple ? .multipleChoice : .singleChoice
    }
}

