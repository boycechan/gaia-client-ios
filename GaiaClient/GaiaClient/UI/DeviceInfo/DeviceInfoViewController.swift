//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import UIKit

class DeviceInfoViewController: UIViewController, GaiaViewControllerProtocol {
    var viewModel: GaiaViewModelProtocol?

    private enum ConnectionButtonType {
        case show
        case connect
        case disconnect
    }

    @IBOutlet weak var chargeStatusImageView: UIImageView!
    @IBOutlet weak var deviceImageView: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var variantNameLabel: UILabel!
	@IBOutlet weak var applicationVersionLabel: UILabel!
    @IBOutlet weak var apiVersionLabel: UILabel!

    @IBOutlet weak var batteryStackView: UIStackView!
    @IBOutlet weak var batteryLabel: UILabel!

    @IBOutlet weak var serialNumberLabel: UILabel!
    @IBOutlet weak var secondSerialNumberLabel: UILabel!

    @IBOutlet weak var connectionButton: UIButton!
    @IBOutlet weak var updatingContainer: UIStackView?

    override var title: String? {
        get {
        	return viewModel?.title
        }
        set {}
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let image = Theming.navBarAppImage()
        let iv = UIImageView(image: image)
        navigationItem.titleView = iv
        
        viewModel?.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.deactivate()
    }

    private func setConnectionButtonTitleAndColor(_ type: ConnectionButtonType) {
        var color: UIColor?
        var title = ""

        switch type {
        case .show:
            title = String(localized: "Show Devices", comment: "Connection Button")
            color = Theming.regularButtonColor()
        case .connect:
            title = String(localized: "Connect", comment: "Connection Button")
            color = Theming.affirmativeButtonColor()
        case .disconnect:
            title = String(localized: "Disconnect", comment: "Connection Button")
            color = Theming.destructiveButtonColor()
        }

        if let connectionButton = connectionButton {
            connectionButton.setTitle(title, for: .normal)
            connectionButton.setTitle(title, for: .highlighted)
            connectionButton.setTitle(title, for: .selected)

            if let color = color {
                connectionButton.setTitleColor(color, for: .normal)
                connectionButton.setTitleColor(color, for: .highlighted)
                connectionButton.setTitleColor(color, for: .selected)
            }
        }
    }

    func update() {
        guard let deviceInfoViewModel = viewModel as? DeviceInfoViewModel,
              isViewLoaded else {
            return
        }

        if let device = deviceInfoViewModel.deviceInfo {
            if device.isUpdating {
                connectionButton.isHidden = true
                updatingContainer?.isHidden = false
            } else {
                connectionButton.isHidden = false
                updatingContainer?.isHidden = true
                if deviceInfoViewModel.devicesAreAvailable {
                    connectionButton.isEnabled = true
                    if device.version == .unknown || device.connectionKind == .iap2 {
                        setConnectionButtonTitleAndColor(.show)
                    } else {
                        setConnectionButtonTitleAndColor(deviceInfoViewModel.isDeviceConnected() ? .disconnect : .connect)
                    }
                } else {
                    connectionButton.isEnabled = false
                    setConnectionButtonTitleAndColor(.connect)
                }
            }

            deviceNameLabel.text = device.name

            if !device.applicationVersion.isEmpty {
                applicationVersionLabel.isHidden = false
                applicationVersionLabel.text = String(localized: "Application Version:", comment: "App Version") + " \(device.applicationVersion)"
            } else {
                applicationVersionLabel.isHidden = true
            }

            if !device.apiVersion.isEmpty {
                apiVersionLabel.isHidden = false
                apiVersionLabel.text = String(localized: "API Version:", comment: "API Version") + "\(device.apiVersion)"
            } else {
                apiVersionLabel.isHidden = true
            }

            if let battStatus = device.batteryState {
                batteryLabel.text = battStatus
                batteryStackView.isHidden = false
            } else {
                batteryStackView.isHidden = true
            }

            if !device.serialNumber.isEmpty {
                serialNumberLabel.isHidden = false
                if device.isEarbud {
                    // We need to deal with left and right earbud serial numbers etc
                    let leftSerialNumberTitle = String(localized: "Left Serial Number:", comment: "Serial number text")
                    let rightSerialNumberTitle = String(localized: "Right Serial Number:", comment: "Serial number text")

                    if let secondarySerial = device.secondEarbudSerialNumber {
                        secondSerialNumberLabel.isHidden = false
                        if deviceInfoViewModel.deviceInfo?.isLeftEarbudPrimary ?? false {
                            serialNumberLabel.text = leftSerialNumberTitle + " \(device.serialNumber)"
                            secondSerialNumberLabel.text = rightSerialNumberTitle + " \(secondarySerial)"
                        } else {
                            serialNumberLabel.text = leftSerialNumberTitle + " \(secondarySerial)"
                            secondSerialNumberLabel.text = rightSerialNumberTitle + " \(device.serialNumber)"
                        }
                    } else {
                        secondSerialNumberLabel.isHidden = true
                        // We can't find out the secondarySerial
                        if deviceInfoViewModel.deviceInfo?.isLeftEarbudPrimary ?? false {
                            serialNumberLabel.text = leftSerialNumberTitle + " \(device.serialNumber)"
                        } else {
                            serialNumberLabel.text = rightSerialNumberTitle + " \(device.serialNumber)"
                        }
                    }
                } else {
                    secondSerialNumberLabel.isHidden = true
                    let serialNumberTitle = String(localized: "Serial Number:", comment: "Serial number text")
                    serialNumberLabel.text = serialNumberTitle + " \(device.serialNumber)"
                }
            } else {
                serialNumberLabel.isHidden = true
                secondSerialNumberLabel.isHidden = true
            }
            variantNameLabel.isHidden = false
            chargeStatusImageView.isHighlighted = device.version != .v3

            switch device.state {
            case .disconnected:
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "Awaiting Connection", comment: "Awaiting Connection")
            case .awaitingTransportSetUp:
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "Awaiting Initial Setup", comment: "Awaiting Connection")
            case .settingUpTransport:
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "Setting up GAIA Connection", comment: "Preparing Connection")
            case .transportReady:
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "GAIA Connected", comment: "Made Connection")
            case .settingUpGaia:
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "Fetching Device Info", comment: "Determining GAIA Version")
            case .gaiaReady:
                if device.version == .v3 {
                    switch device.deviceType {
                    case .unknown:
                        deviceImageView.image = UIImage(systemName: "questionmark")
                    case .earbud:
                        deviceImageView.image = UIImage(named: "icon-device-earbuds")
                    case .headset:
                        deviceImageView.image = UIImage(named: "icon-device-headphones")
                    case .chargingCase:
                        deviceImageView.image = UIImage(named: "icon-device-chargingcase")
                    }

                    chargeStatusImageView.image = device.isCharging ?
                        UIImage(systemName: "bolt.fill") :
                        UIImage(systemName: "bolt.slash.fill")
                    variantNameLabel.text = device.deviceVariant

                } else if device.version == .v2 {
                    deviceImageView.image = UIImage(named: "icon-device-earbuds")
                    variantNameLabel.text = String(localized: "This device may be updated in Settings", comment: "This device may be updated in Settings")
                } else {
                    deviceImageView.image = UIImage(systemName: "questionmark")
                    variantNameLabel.text = String(localized: "This is not a supported device", comment: "This is not a supported device")
                }
            case .failed(let error):
                deviceImageView.image = UIImage(systemName: "questionmark")
                variantNameLabel.text = String(localized: "Set up failed: ", comment: "Setup failed") + error.userVisibleDescription()
            }
        } else {
            setConnectionButtonTitleAndColor(.connect)
            connectionButton.isEnabled = deviceInfoViewModel.devicesAreAvailable

            deviceNameLabel.text = "No Device"
            variantNameLabel.isHidden = true
            applicationVersionLabel.isHidden = true
            apiVersionLabel.isHidden = true
            serialNumberLabel.isHidden = true
            secondSerialNumberLabel.isHidden = true
            batteryStackView.isHidden = true
        }
    }
}

extension DeviceInfoViewController {
    @IBAction func connectionButtonTapped(_ button: UIButton) {
        guard let deviceInfoViewModel = viewModel as? DeviceInfoViewModel else {
            return
        }

        deviceInfoViewModel.connectDisconnect()
    }
}
