# QuestionnaireKit
Swift framework for presenting FHIR Questionnaires in your iOS app using Apple ResearchKit surveys.

QuestionnaireKit is currently compatible with: 
* HL7 FHIR R4
* iOS 14 and newer
* Swift 5.5
* XCode 13.0

Dependencies include:
* [**FHIRModels**](https://github.com/apple/FHIRModels) via Swift Package Manager (SPM)
* Apple ResearchKit version 2.1, integrated as a git submodule (does not yet support SPM)

This framework was extracted from the [C3-Pro](http://c3-pro.org), [c3-pro-ios-framework](https://github.com/C3-PRO/c3-pro-ios-framework) 
to enable iOS apps to easily include FHIR Questionnaires presented using the Apple ResearchKit framework surveys. The orginal code was also
updated to support HL7 FHIR R4.

Installation
------------

Download _QuestionnaireKit_ from GitHub as follows:
* Using Terminal.app, navigate to your project directory and execute:

``$ git clone --recursive https://github.com/clinical-cloud/QuestionnaireKit.git``

* This will download the latest codebase and all dependencies of the master branch. To use a different branch, e.g. the develop branch, add -b develop to the clone command or checkout the appropriate branch after cloning. 
* Open QuestionnaireKit.xcworkspace using XCode

See the _QKDemo_ app included in this repo for an example on how to include FHIR Questionnaires in your app, presented using ResearchKit surveys.
The demo app includes 4 sample FHIR Questionnaire resources that illustrate this framework's capabilities.

For more detail on usage, see [Questionnaires](Questionnaire.md)

License
-------

This work is [Apache 2](./LICENSE) licensed.
FHIR® is the registered trademark of [HL7][] and is used with the permission of HL7.

[hl7]: http://hl7.org/
