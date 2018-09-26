import UIKit
import MapKit
import SwiftMQTT

class ViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var geoStopBtn: UIButton!
    
    @IBOutlet weak var reconnectBtn: UIButton!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    @IBOutlet weak var ledSwitch: UISwitch!
    @IBOutlet weak var tvSwitch: UISwitch!
    @IBOutlet weak var arSwitch: UISwitch!
    @IBOutlet weak var lampSwitch: UISwitch!
    
    var mqttSession: MQTTSession?
    var centerLocation: CLLocation?
    var locationManager = CLLocationManager()
    var distance: Double = 500
    var distanceMarked: Double?
    var centered = false
    var authorized = false
    var inside: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.distanceLabel.text = "Distância: \(self.distance)"
        locationManager.delegate = self
        mapView.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        connectMqtt()
    }
    
    @IBAction func setLocation(_ sender: Any) {
        if let location = locationManager.location{
            mapView.removeOverlays(mapView.overlays)
            self.centerLocation = location
            self.distanceMarked = self.distance
            let circle = MKCircle(center: location.coordinate, radius: CLLocationDistance(self.distance))
            self.inside = true
            mapView.add(circle)
        }
    }
    
    @IBAction func activateLocalization(_ sender: Any) {
        if !authorized{
            self.geoStopBtn.setTitle("Ativar Localização", for: UIControlState.normal)
            self.geoStopBtn.backgroundColor = .blue
            locationManager.stopUpdatingLocation()
            authorized = true
        } else {
            self.geoStopBtn.setTitle("Parar Localização", for: UIControlState.normal)
            self.geoStopBtn.backgroundColor = .red
            locationManager.startUpdatingLocation()
            authorized = false
        }
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let circelOverLay = overlay as? MKCircle else {return MKOverlayRenderer()}
        
        let circleRenderer = MKCircleRenderer(circle: circelOverLay)
        circleRenderer.strokeColor = .red
        circleRenderer.fillColor = .red
        return circleRenderer
    }
    
    @IBAction func tryReconnect(_ sender: Any) {
        LoadingAnimation.run()
        DispatchQueue.main.async {
            self.mqttSession!.connect { (result, error) in
                if result == false {
                    self.statusLabel.text = "Desconectado"
                    self.statusLabel.textColor = .red
                    self.reconnectBtn.isHidden = false
                } else {
                    self.statusLabel.text = "Conectado"
                    self.statusLabel.textColor = .black
                    self.reconnectBtn.isHidden = true
                }
                LoadingAnimation.stop()
            }
        }
    }
    
    @IBAction func changeDistance(_ sender: UISlider) {
        self.distance = Double(sender.value*1000)
        self.distanceLabel.text = "Distância: \(Int(self.distance))m"
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
            clientID: "swiftItalusTeste", // must be unique to the client
            cleanSession: true,
            keepAlive: 15,
            useSSL: false
        )
        
        LoadingAnimation.run()
        DispatchQueue.main.async {
            self.mqttSession!.connect { (result, error) in
                if result == false {
                    self.statusLabel.text = "Desconectado"
                    self.statusLabel.textColor = .red
                    self.reconnectBtn.isHidden = false
                } else {
                    self.statusLabel.text = "Conectado"
                    self.statusLabel.textColor = .black
                    self.reconnectBtn.isHidden = true
                }
                LoadingAnimation.stop()
            }
        }
        
    }
    
    func someAsyncFunction(completion: @escaping (Error?) -> Void) {
        // Something that takes some time to complete.
        completion(nil) // Or completion(SomeError.veryBadError)
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
            self.authorized = true
            self.mapView.showsUserLocation = true
            if let location = locationManager.location{
//                let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 200, 200)
//                self.mapView.setRegion(region, animated: true)
                self.mapView.userTrackingMode = MKUserTrackingMode.follow
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.mapView.userTrackingMode = MKUserTrackingMode.follow
        guard let location = locationManager.location else {return}
        //let region = MKCoordinateRegionMakeWithDistance(location.coordinate, 200, 200)
        //self.mapView.setRegion(region, animated: true)
        guard let center = centerLocation else {return}
        guard let inside = self.inside else {return}
        guard let distance = self.distanceMarked else {return}
        
        if location.distance(from: center) < distance && !inside{
            Alert.show(title: "Entrando", msg: "")
            self.inside = true
            automaticMessage(entering: true)
        } else if location.distance(from: center) > distance && inside {
            Alert.show(title: "Saindo", msg: "")
            self.inside = false
            automaticMessage(entering: false)
        }
    }
    
    func automaticMessage(entering: Bool){
        if entering{
            if ledSwitch.isOn{
                sendMqttMessage(string: "Ativar LED")
            } else {
                sendMqttMessage(string: "Desativar LED")
            }
            if tvSwitch.isOn{
                sendMqttMessage(string: "Ativar TV")
            } else {
                sendMqttMessage(string: "Desativar TV")
            }
            if arSwitch.isOn{
                sendMqttMessage(string: "Ativar Ar")
            } else {
                sendMqttMessage(string: "Desativar Ar")
            }
            if lampSwitch.isOn{
                sendMqttMessage(string: "Ativar Lampada")
            } else {
                sendMqttMessage(string: "Desativar Lampada")
            }
        } else {
            sendMqttMessage(string: "Desativar LED")
            sendMqttMessage(string: "Desativar TV")
            sendMqttMessage(string: "Desativar Ar")
            sendMqttMessage(string: "Desativar Lampada")
        }
    }
}

