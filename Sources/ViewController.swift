import UIKit
import WebKit
import CoreBluetooth

class ViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate,
                       CBCentralManagerDelegate, CBPeripheralDelegate {

    var webView: WKWebView!
    var centralManager: CBCentralManager!
    var arm: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?

    let deviceName = "Arduino_Robot_Arm"
    let serviceUUID = CBUUID(string: "4FAFC201-1FB5-459E-8FCC-C5C9C331914B")
    let charUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")

    override func viewDidLoad() {
        super.viewDidLoad()

        let contentController = WKUserContentController()
        contentController.add(self, name: "native")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard let command = message.body as? String else { return }
        sendCommand(command)
    }

    func sendCommand(_ command: String) {
        guard let peripheral = arm, let characteristic = writeCharacteristic else { return }
        guard let data = command.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.name == deviceName {
            arm = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeCharacteristic = nil
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == charUUID {
            writeCharacteristic = characteristic
        }
    }
}
