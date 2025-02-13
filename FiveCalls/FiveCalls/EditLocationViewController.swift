//
//  EditLocationViewController.swift
//  FiveCalls
//
//  Created by Ben Scheirman on 1/31/17.
//  Copyright © 2017 5calls. All rights reserved.
//

import UIKit
import CoreLocation

protocol EditLocationViewControllerDelegate : NSObjectProtocol {
    func editLocationViewController(_ vc: EditLocationViewController, didUpdateLocation location: UserLocation)
    func editLocationViewControllerDidCancel(_ vc: EditLocationViewController)
}

class EditLocationViewController : UIViewController, CLLocationManagerDelegate, UITextFieldDelegate {
    weak var delegate: EditLocationViewControllerDelegate?
    private var lookupLocation: CLLocation?
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var submitButton: BlueButton!

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()

    @IBOutlet weak var useMyLocationButton: UIButton!
    @IBOutlet weak var addressTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addressTextField.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addressTextField.becomeFirstResponder()
        
        if case .address? = UserLocation.current.locationType {
            addressTextField.text = UserLocation.current.locationValue
            addressTextFieldChanged()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        addressTextField.resignFirstResponder()
    }
    
    @IBAction func useMyLocationTapped(_ sender: Any) {
        if CLLocationManager.authorizationStatus() == .denied {
            AnalyticsManager.shared.trackEventOld(withName: "Action: Denied Location")
            informUserOfPermissions()
        } else {
            AnalyticsManager.shared.trackEventOld(withName: "Action: Used Location")
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        delegate?.editLocationViewControllerDidCancel(self)
    }
    
    @IBAction func submitAddressTapped(_ sender: Any) {
        submitAddress()
        
    }
    
    func submitAddress() {
        AnalyticsManager.shared.trackEventOld(withName: "Action: Used Address")
        
        UserLocation.current.setFrom(address: addressTextField.text ?? "") { [weak self] updatedLocation in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.delegate?.editLocationViewController(strongSelf, didUpdateLocation: updatedLocation)
        }
    }
    
    @IBAction func addressTextFieldChanged() {
        let address = addressTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        submitButton.isEnabled = address.count > 0
    }
    
    //MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let address = addressTextField.text?.trimmingCharacters(in: .whitespaces) {
            if address.isEmpty {
                return false
            }
        }
        
        textField.resignFirstResponder()
        submitAddress()
        return true
    }

    //MARK: - CLLocationManagerDelegate methods
    
    func informUserOfPermissions() {
        let alertController = UIAlertController.settingsAlertView(
            title: R.string.localizable.locationPermissionDeniedTitle(),
            message: R.string.localizable.locationPermissionDeniedMessage())
        present(alertController, animated: true, completion: nil)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied {
            informUserOfPermissions()
        } else {
            useMyLocationButton.isEnabled = false // prevent starting it twice...
            activityIndicator.startAnimating()
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard lookupLocation == nil else { //only want to call delegate one time
            return
        }

        if let location = locations.first {
            locationManager.stopUpdatingLocation()
            lookupLocation = location
            let userLocation = UserLocation.current
            userLocation.setFrom(location: location) {
                self.delegate?.editLocationViewController(self, didUpdateLocation: userLocation)
            }
            
        }
    }

}
