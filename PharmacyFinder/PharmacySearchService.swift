import Foundation
import CoreLocation
import MapKit

final class PharmacySearchService {
    func findNearbyPharmacies(
        around location: CLLocation,
        radius: CLLocationDistance = 3000,
        completion: @escaping (Result<[Pharmacy], Error>) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "药店"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let response else {
                completion(.success([]))
                return
            }

            let pharmacies = response.mapItems.compactMap { item -> Pharmacy? in
                guard let name = item.name else { return nil }
                let placemark = item.placemark
                let coordinate = placemark.coordinate
                let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                let addressParts = [
                    placemark.administrativeArea,
                    placemark.locality,
                    placemark.thoroughfare,
                    placemark.subThoroughfare
                ].compactMap { $0 }

                return Pharmacy(
                    name: name,
                    phoneNumber: item.phoneNumber ?? "暂无电话",
                    address: addressParts.joined(),
                    coordinate: coordinate,
                    distanceMeters: location.distance(from: target),
                    mapItem: item
                )
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }

            completion(.success(pharmacies))
        }
    }
}
