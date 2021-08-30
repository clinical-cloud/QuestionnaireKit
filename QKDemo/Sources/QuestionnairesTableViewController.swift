//
//  QuestionnairesTableViewController.swift
//
//  Created by Dave Carlson on 08/30/2021.
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


import UIKit
import ModelsR4
import QuestionnaireKit

class QuestionnairesTableViewController: UITableViewController {
	
	var endpointURL: String? = nil

//	var smart: Client?
	
	var questionnaires: [Questionnaire]?
	
	var controller: QuestionnaireController?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Questionnaies"
		self.clearsSelectionOnViewWillAppear = false
    }
	
	override func viewWillAppear(_ animated: Bool) {
		if questionnaires == nil {
			loadQuestionnaires()
		}
	}

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return questionnaires?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QuestionnaireCell", for: indexPath)

		if let questionnaire = questionnaires?[indexPath.row] {
			cell.textLabel?.text = questionnaire.title?.value?.string
			cell.detailTextLabel?.text = questionnaire.id?.value?.string
		}

        return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let questionnaire = questionnaires?[indexPath.row] {
			showQuestionnaire(questionnaire)
		}
	}
	
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		var questionnaire: Questionnaire?
		
		if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
			// when detail accessory is selected
			questionnaire = questionnaires?[indexPath.row]
		}
		else if let indexPath = tableView.indexPathForSelectedRow {
			// when row is selected
			questionnaire = questionnaires?[indexPath.row]
		}
		
		if let questionnaire = questionnaire {
			if segue.identifier == "showResource" {
				if let vc = segue.destination as? ResourceJsonViewController {
					vc.resource = questionnaire
				}
			}
		}
    }
	
	// MARK: - Questionnaire support

	@objc private func loadQuestionnaires() {
		self.questionnaires = []
		let questionnaireFiles = [
			"questionnaire-44249-1",
			"questionnaire-62199-5",
			"questionnaire-sdoh-screening",
			"questionnaire-example-sampler",
		]
		
		for fileName in questionnaireFiles {
			do {
				let q = try getQuestionnaire(withID: fileName)
				self.questionnaires?.append(q)
			}
			catch {
				print("Error loading sample data file: \(fileName)")
			}
		}
	}
	
	private func getQuestionnaire(withID id: String) throws -> Questionnaire {
		guard let fileURL = Bundle.main.url(forResource: "samples/\(id)", withExtension: "json")
		else {
			throw QKError.bundleFileNotFound(id)
		}
		let data = try! Data(contentsOf: fileURL)
		return try JSONDecoder().decode(Questionnaire.self, from: data)
	}
		
	private func showQuestionnaire(_ questionnaire: Questionnaire) {
		controller = QuestionnaireController(questionnaire: questionnaire)
		controller?.whenCompleted = { viewController, response in
			if let response = response {
				let resourceVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ResourceJsonViewController") as! ResourceJsonViewController
				resourceVC.resource = response
				self.navigationController?.pushViewController(resourceVC, animated: true)
			}
			self.dismiss(animated: true)
		}
		controller?.whenCancelledOrFailed = { viewController, error in
			if let error = error {
				self.show(error: error)
			}
			self.dismiss(animated: true)
		}
		controller?.prepareQuestionnaireViewController() { viewController, error in
			if let vc = viewController {
				self.present(vc, animated: true)
			}
			else if let error = error {
				self.show(error: error, title: "Error Preparing Questionnaire")
			}
		}
	}
	
	func markBusy() {
		DispatchQueue.main.async() {
			self.refreshControl?.beginRefreshing()
		}
	}
	
	func markReady() {
		DispatchQueue.main.async() {
			self.refreshControl?.endRefreshing()
		}
	}
	
	func show(error: Error, title: String? = nil) {
		let alert = UIAlertController(title: title ?? "Error", message: "\(error)", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .cancel))
		if nil != presentedViewController {
			dismiss(animated: true) {
				self.present(alert, animated: true)
			}
		}
		else {
			present(alert, animated: true)
		}
	}
}
