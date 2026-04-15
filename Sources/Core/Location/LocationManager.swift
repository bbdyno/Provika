import CoreLocation
import os

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "Location")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        logger.info("위치 업데이트 시작")
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        logger.info("위치 업데이트 중지")
    }

    func enableBackgroundUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    func disableBackgroundUpdates() {
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("위치 권한 상태 변경: \(String(describing: manager.authorizationStatus.rawValue))")

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        case .denied, .restricted:
            logger.warning("위치 권한 거부됨")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("위치 오류: \(error.localizedDescription)")
    }
}
