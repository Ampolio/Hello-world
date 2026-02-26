import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var pharmacies: [Pharmacy] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let searchService = PharmacySearchService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在查询附近药店…")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "查询失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if pharmacies.isEmpty {
                    ContentUnavailableView(
                        "暂无结果",
                        systemImage: "cross.case",
                        description: Text("请先授权定位，并点击“查找附近药店”")
                    )
                } else {
                    List(pharmacies) { pharmacy in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(pharmacy.name)
                                .font(.headline)
                            Text(pharmacy.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(pharmacy.phoneNumber)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            Text(String(format: "距离 %.0f 米", pharmacy.distanceMeters))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            pharmacy.mapItem.openInMaps()
                        }
                    }
                }
            }
            .navigationTitle("附近药店")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("查找附近药店") {
                        fetchNearbyPharmacies()
                    }
                }
            }
            .onAppear {
                locationManager.requestPermissionAndLocation()
            }
            .onChange(of: locationManager.errorMessage) { _, newValue in
                if let newValue {
                    errorMessage = newValue
                }
            }
        }
    }

    private func fetchNearbyPharmacies() {
        errorMessage = nil
        guard let location = locationManager.currentLocation else {
            locationManager.requestPermissionAndLocation()
            errorMessage = "尚未获取到当前位置，请稍后重试。"
            return
        }

        isLoading = true
        searchService.findNearbyPharmacies(around: location) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case let .success(items):
                    pharmacies = items
                    if items.isEmpty {
                        errorMessage = "未找到附近药店，请尝试扩大搜索范围。"
                    }
                case let .failure(error):
                    errorMessage = "搜索失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
