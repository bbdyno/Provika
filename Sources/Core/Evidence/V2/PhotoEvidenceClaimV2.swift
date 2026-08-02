import Foundation

struct PhotoEvidenceClaimV2: Codable, Equatable {
    let schemaVersion: String
    let packageID: UUID
    let media: Media
    let capture: Capture
    let app: App
    let device: Device
    let location: Location?
    let context: Context?

    init(
        packageID: UUID,
        media: Media,
        capture: Capture,
        app: App,
        device: Device,
        location: Location? = nil,
        context: Context? = nil
    ) {
        self.schemaVersion = "2.0"
        self.packageID = packageID
        self.media = media
        self.capture = capture
        self.app = app
        self.device = device
        self.location = location
        self.context = context
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, packageID, media, capture, app, device, location, context
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == "2.0" else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: container, debugDescription: "Unsupported schemaVersion: \(schemaVersion)")
        }

        self.schemaVersion = schemaVersion
        self.packageID = try container.decode(UUID.self, forKey: .packageID)
        self.media = try container.decode(Media.self, forKey: .media)
        self.capture = try container.decode(Capture.self, forKey: .capture)
        self.app = try container.decode(App.self, forKey: .app)
        self.device = try container.decode(Device.self, forKey: .device)
        self.location = try container.decodeIfPresent(Location.self, forKey: .location)
        self.context = try container.decodeIfPresent(Context.self, forKey: .context)
    }

    struct Media: Codable, Equatable {
        let fileName: String
        let mediaType: String
        let pixelWidth: Int
        let pixelHeight: Int
        let sha256: String

        init(fileName: String, mediaType: String, pixelWidth: Int, pixelHeight: Int, sha256: String) {
            self.fileName = fileName
            self.mediaType = mediaType
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.sha256 = sha256
        }
    }

    struct Capture: Codable, Equatable {
        let deviceTime: String
        let timeSource: String

        init(deviceTime: String) {
            self.deviceTime = deviceTime
            self.timeSource = "device-clock"
        }

        private enum CodingKeys: String, CodingKey {
            case deviceTime, timeSource
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let timeSource = try container.decode(String.self, forKey: .timeSource)
            guard timeSource == "device-clock" else {
                throw DecodingError.dataCorruptedError(forKey: .timeSource, in: container, debugDescription: "Unsupported timeSource: \(timeSource)")
            }

            self.deviceTime = try container.decode(String.self, forKey: .deviceTime)
            self.timeSource = timeSource
        }
    }

    struct App: Codable, Equatable {
        let name: String
        let version: String
        let build: String

        init(name: String, version: String, build: String) {
            self.name = name
            self.version = version
            self.build = build
        }
    }

    struct Device: Codable, Equatable {
        let model: String
        let systemVersion: String

        init(model: String, systemVersion: String) {
            self.model = model
            self.systemVersion = systemVersion
        }
    }

    struct Location: Codable, Equatable {
        let lat: Double
        let lng: Double
        let horizontalAccuracyMeters: Double
        let altitudeMeters: Double?
        let verticalAccuracyMeters: Double?
        let headingDegrees: Double?
        let speedMetersPerSecond: Double?
        let source: String

        init(
            lat: Double,
            lng: Double,
            horizontalAccuracyMeters: Double,
            altitudeMeters: Double? = nil,
            verticalAccuracyMeters: Double? = nil,
            headingDegrees: Double? = nil,
            speedMetersPerSecond: Double? = nil
        ) {
            self.lat = lat
            self.lng = lng
            self.horizontalAccuracyMeters = horizontalAccuracyMeters
            self.altitudeMeters = altitudeMeters
            self.verticalAccuracyMeters = verticalAccuracyMeters
            self.headingDegrees = headingDegrees
            self.speedMetersPerSecond = speedMetersPerSecond
            self.source = "core-location-device"
        }

        private enum CodingKeys: String, CodingKey {
            case lat, lng, horizontalAccuracyMeters, altitudeMeters, verticalAccuracyMeters, headingDegrees, speedMetersPerSecond, source
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let source = try container.decode(String.self, forKey: .source)
            guard source == "core-location-device" else {
                throw DecodingError.dataCorruptedError(forKey: .source, in: container, debugDescription: "Unsupported location source: \(source)")
            }

            self.lat = try container.decode(Double.self, forKey: .lat)
            self.lng = try container.decode(Double.self, forKey: .lng)
            self.horizontalAccuracyMeters = try container.decode(Double.self, forKey: .horizontalAccuracyMeters)
            self.altitudeMeters = try container.decodeIfPresent(Double.self, forKey: .altitudeMeters)
            self.verticalAccuracyMeters = try container.decodeIfPresent(Double.self, forKey: .verticalAccuracyMeters)
            self.headingDegrees = try container.decodeIfPresent(Double.self, forKey: .headingDegrees)
            self.speedMetersPerSecond = try container.decodeIfPresent(Double.self, forKey: .speedMetersPerSecond)
            self.source = source
        }
    }

    struct Context: Codable, Equatable {
        let projectID: String?
        let projectName: String?
        let note: String?
        let organizationName: String?

        init(projectID: String? = nil, projectName: String? = nil, note: String? = nil, organizationName: String? = nil) {
            self.projectID = projectID
            self.projectName = projectName
            self.note = note
            self.organizationName = organizationName
        }

        private enum CodingKeys: String, CodingKey {
            case projectID, projectName, note, organizationName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
            self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
            self.note = try container.decodeIfPresent(String.self, forKey: .note)
            self.organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
        }
    }
}
