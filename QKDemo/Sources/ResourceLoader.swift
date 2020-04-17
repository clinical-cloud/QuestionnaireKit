//
//  ResourceLoader.swift
//
//  Created by Dave Carlson on 12/7/19.
//  Copyright © 2019 Clinical Cloud Solutions, LLC. All rights reserved.
//

import Foundation
import FHIR

public class ResourceLoader {
	
	public static func loadResource<T: Resource>(type: T.Type, filename: String, directory: String) throws -> T? {
		var resource: T?
		
		// TODO Find a better way to detect when running on a device vs simulator
		// This doesn't work when running Debug on an iPhone device
		/*
		#if DEBUG
			resource = try instantiateFHIRResource(type: type, filename: filename)
		#else
			resource = try loadBundledResource(type: type, filename: filename)
		#endif
		*/
		
		// The first will fail when running on device
		do {
			resource = try instantiateFHIRResource(type: type, filename: filename, directory: directory)
		}
		catch {
			resource = try loadBundledResource(type: type, filename: filename, directory: directory)
		}
		
		return resource
	}
	
	private static func loadBundledResource<T: Resource>(type: T.Type, filename: String, directory: String) throws -> T? {
		return try Foundation.Bundle.main.fhir_bundledResource(filename, subdirectory: directory, type: type, strict: false)
	}

	private static func projectPath(for directory: String) -> String {
		let dir = #file as NSString
		let proj = ((dir.deletingLastPathComponent as NSString).deletingLastPathComponent as NSString) as NSString
		return proj.appendingPathComponent(directory)
	}
			
	private static func instantiateFHIRResource<T: Resource>(type: T.Type, filename: String, directory: String) throws -> T? {
		let json = try readJSONFile(filename, directory: projectPath(for: directory))
		var context = FHIRInstantiationContext(strict: false)
		let newResource = Resource.factory(type.resourceType, json: json, owner: nil, type: type, context: &context)
		return newResource
	}
	
	private static func readJSONFile(_ filename: String, directory: String) throws -> FHIRJSON {
		let path = (directory as NSString).appendingPathComponent(filename)
		let data = try Data(contentsOf: URL(fileURLWithPath: path).appendingPathExtension("json"))
		let json = try JSONSerialization.jsonObject(with: data, options: []) as? FHIRJSON
		if let json = json {
			return json
		}
		throw FHIRError.error("Unable to decode «\(path)» to JSON")
	}
	
}

public extension Foundation.Bundle {
	
	/**
	Attempts to read a JSON file with the given name (without ".json") from the given directory. Parses the JSON and instantiates a FHIR
	resource corresponding to "resourceType".
	
	- parameter name:         The filename, without ".json" extension, to read the resource from
	- parameter subdirectory: The directory name to search for the resource; `nil` for top level
	- parameter type:         The type the resource is expected to be; must be a subclass of `Resource`
	- returns:                A Resource subclass corresponding to the "resourceType" entry, as specified under `type`
	*/
	func fhir_bundledResource<T: Resource>(_ name: String, subdirectory: String?, type: T.Type, strict: Bool) throws -> T {
		let json = try fhir_json(from: name, subdirectory: subdirectory)
		var context = FHIRInstantiationContext(strict: strict)
		let resource = T.instantiate(from: json, owner: nil, context: &context)
		try context.validate()
		return resource
	}
	
}
