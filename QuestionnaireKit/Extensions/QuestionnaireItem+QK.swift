//
//  FHIR+QK.swift
//
//  Created by Pascal Pfiffner on 7/29/15.
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

import ModelsR4


extension QuestionnaireItem {
	
	/**
	Returns the extension defining the inclusive lower bound, if any, via "http://hl7.org/fhir/StructureDefinition/minValue".
	Use with "valueInteger", "valueDecimal" or other supported type.
	
	- returns: A list of `Extension` resources for the _minValue_ extension
	*/
	final func qk_minValues() -> [Extension]? {
		return extensions(for: "http://hl7.org/fhir/StructureDefinition/minValue")
	}
	
	final func qk_minValueInt() -> Int32? {
		if case .integer(let value) = qk_minValues()?.first?.value {
			return value.value?.integer
		}
		return nil
	}
	
	final func qk_minValueDecimal() -> Decimal? {
		if case .decimal(let value) = qk_minValues()?.first?.value {
			return value.value?.decimal
		}
		return nil
	}
	
	final func qk_minValueDate() -> Date? {
		if case .date(let value) = qk_minValues()?.first?.value {
			return try? value.value?.asNSDate()
		}
		return nil
	}
	
	final func qk_minValueString() -> String? {
		if case .string(let value) = qk_minValues()?.first?.value {
			return value.value?.string
		}
		return nil
	}
	
	/**
	Returns the extension defining the inclusive upper bound, if any, via "http://hl7.org/fhir/StructureDefinition/maxValue".
	Use with "valueInteger", "valueDecimal" or other supported type.
	
	- returns: A list of `Extension` resources for the _maxValue_ extension
	*/
	final func qk_maxValues() -> [Extension]? {
		return extensions(for: "http://hl7.org/fhir/StructureDefinition/maxValue")
	}
	
	final func qk_maxValueInt() -> Int32? {
		if case .integer(let value) = qk_maxValues()?.first?.value {
			return value.value?.integer
		}
		return nil
	}
	
	final func qk_maxValueDecimal() -> Decimal? {
		if case .decimal(let value) = qk_maxValues()?.first?.value {
			return value.value?.decimal
		}
		return nil
	}
	
	final func qk_maxValueDate() -> Date? {
		if case .date(let value) = qk_maxValues()?.first?.value {
			return try? value.value?.asNSDate()
		}
		return nil
	}
	
	final func qk_maxValueString() -> String? {
		if case .string(let value) = qk_maxValues()?.first?.value {
			return value.value?.string
		}
		return nil
	}
	
	func qk_questionMinOccurs() -> Int32? {
		if case .integer(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-minOccurs").first?.value {
			return value.value?.integer
		}
		return nil
	}
	
	func qk_questionMaxOccurs() -> Int32? {
		if case .integer(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-maxOccurs").first?.value {
			return value.value?.integer
		}
		return nil
	}
	
	func qk_numericAnswerUnit() -> Coding? {
		if case .coding(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-unit").first?.value {
			return value
		}
		return nil
	}
	
	/*
	 TODO: This does not appear to be in current list of extensions.
	 */
	func qk_defaultAnswer() -> Extension? {
		return extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-defaultValue").first
	}
	
	func qk_questionTitle() -> String? {
		if case .string(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-title").first?.value {
			return value.value?.string.qk_localized
		}
		return nil
	}
	
	func qk_questionHidden() -> Bool? {
		if case .boolean(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-hidden").first?.value {
			return value.value?.bool
		}
		return nil
	}
	
	func qk_questionInstruction() -> String? {
		if case .string(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-instruction").first?.value {
			return value.value?.string.qk_localized
		}
		return nil
	}
	
	func qk_questionHelpText() -> String? {
		if case .string(let value) = extensions(for: "http://hl7.org/fhir/StructureDefinition/questionnaire-help").first?.value {
			return value.value?.string.qk_localized
		}
		return nil
	}
	
	func qk_valuePickerFormat() -> Bool? {
		if case .boolean(let value) = extensions(for: "http://fhir-registry.smarthealthit.org/StructureDefinition/value-picker").first?.value {
			return value.value?.bool
		}
		return nil
	}
	
}

