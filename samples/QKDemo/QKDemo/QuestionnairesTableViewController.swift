//
//  QuestionnairesTableViewController.swift
//
//  Created by Dave Carlson on 9/11/18.
//

import UIKit
import SMART
import QuestionnaireKit

class QuestionnairesTableViewController: UITableViewController {
	
	let endpoint = "https://api-v5-stu3.hspconsortium.org/CareGuide/open"
//	let endpoint = "http://sqlonfhir-stu3.azurewebsites.net/fhir"

	var smart: Client?
	
	var questionnaires: [Questionnaire]?
	
	var controller: QuestionnaireController?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = "Questionnaies"
		self.clearsSelectionOnViewWillAppear = false
		self.refreshControl = UIRefreshControl()
		self.refreshControl?.addTarget(self, action: #selector(loadQuestionnaires(_:)), for: .valueChanged)
    }
	
	override func viewWillAppear(_ animated: Bool) {
		if questionnaires == nil {
			loadQuestionnaires(self)
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
			cell.textLabel?.text = questionnaire.title?.string
			cell.detailTextLabel?.text = questionnaire.id?.string
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

	@objc private func loadQuestionnaires(_ sender: Any) {
		guard let base = URL(string: endpoint) else {
			return
		}
		markBusy()
		smart = Client(baseURL: base, settings: [:])
		smart?.ready() { error in
			if let error = error {
				self.show(error: error, title: "SMART client error")
				self.markReady()
				return
			}
			
			let queryArgs = [String: String]()
			let search = FHIRSearch(type: Questionnaire.self, query: queryArgs as Any)
			search.perform(self.smart!.server) { bundle, error in
				if nil != error {
					DispatchQueue.main.async() {
						self.show(error: error!)
					}
				}
				else {
					self.questionnaires = bundle?.entries(ofType: Questionnaire.self, typeName: Questionnaire.resourceType) as? [Questionnaire]
				}
				
				DispatchQueue.main.async() {
					self.tableView.reloadData()
					self.markReady()
				}
			}
		}
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
