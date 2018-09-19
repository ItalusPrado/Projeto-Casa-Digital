import UIKit
import MapKit
import SwiftMQTT

class ViewController: UIViewController {
    
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    @IBOutlet weak var ledSwitch: UISwitch!
    @IBOutlet weak var tvSwitch: UISwitch!
    @IBOutlet weak var arSwitch: UISwitch!
    @IBOutlet weak var lampSwitch: UISwitch!
    
    var mqttSession: MQTTSession?
    var locationManager = CLLocationManager()
    var distance = 500
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.distanceLabel.text = "Distância: \(self.distance)"
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        connectMqtt()
    }
    
    @IBAction func setLocation(_ sender: Any) {
        if let location = locationManager.location{
            locationManager.startMonitoring(for: CLCircularRegion(center: location.coordinate, radius: CLLocationDistance(self.distance), identifier: "centro"))
        }
    }
    
    @IBAction func changeDistance(_ sender: UISlider) {
        self.distance = Int(sender.value*1000)
        self.distanceLabel.text = "Distância: \(self.distance)"
    }
    
    @IBAction func activateDispositive(_ sender: UISwitch) {
        switch sender {
        case ledSwitch:
            if sender.isOn{
                sendMqttMessage(string: "Ativar LED")
            } else {
                sendMqttMessage(string: "Desativar LED")
            }
        case tvSwitch:
            if sender.isOn{
                sendMqttMessage(string: "Ativar TV")
            } else {
                sendMqttMessage(string: "Desativar TV")
            }
        case arSwitch:
            if sender.isOn{
                sendMqttMessage(string: "Ativar Ar")
            } else {
                sendMqttMessage(string: "Desativar Ar")
            }
        case lampSwitch:
            if sender.isOn{
                sendMqttMessage(string: "Ativar Lampada")
            } else {
                sendMqttMessage(string: "Desativar Lampada")
            }
        default:
            print("Erro, switch não encontrado")
        }
    }
    
    func connectMqtt(){
        self.mqttSession = MQTTSession(
            host: "ifce.sanusb.org",
            port: 1883,
            clientID: "swiftItalus", // must be unique to the client
            cleanSession: true,
            keepAlive: 15,
            useSSL: false
        )
        self.mqttSession!.connect { (result, error) in
            if result == false {
                self.statusLabel.text = "Desconectado"
                self.statusLabel.textColor = .red
            } else {
                self.statusLabel.text = "Conectado"
                self.statusLabel.textColor = .black
            }
        }
    }
    
    func sendMqttMessage(string: String){
        let data = string.data(using: .utf8)
        if let mqtt = self.mqttSession{
            mqtt.publish(data!, in: "/italus", delivering: .atLeastOnce, retain: false) { (result, error) in
            }
        }
        
    }
    
}

extension ViewController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse{
            manager.startUpdatingLocation()
            self.mapView.showsUserLocation = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first{
            let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 200, 200)
            self.mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Saiu")
    }
 
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entrou")
    }
}

