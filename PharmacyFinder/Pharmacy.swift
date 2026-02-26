import Foundation
import CoreLocation
import MapKit

struct Pharmacy: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: CLLocationDistance
    let mapItem: MKMapItem
}
