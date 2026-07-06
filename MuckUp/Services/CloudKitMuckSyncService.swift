import CloudKit
import CoreLocation

// Public-database sync for Mucks — the piece that makes Grub actually
// multi-user. SwiftData's CloudKit integration only mirrors a user's own
// devices (private database); everyone who installs the app shares the
// SAME public database for a given container, so writing Mucks there is
// what lets one person's report show up for a stranger's phone.
//
// Scope of this first pass: text + location fields only. Photos aren't
// synced yet (would need CKAsset + temp-file handling) — until that
// lands, cross-user mucks show up without their photo.
//
// Failures here (no iCloud account, container not yet provisioned,
// offline) are swallowed and logged rather than surfaced — consistent
// with how the other external data services in this app degrade.
@MainActor
final class CloudKitMuckSyncService {
    static let shared = CloudKitMuckSyncService()

    private let recordType = "Muck"
    private let container = CKContainer(identifier: "iCloud.com.daviddef.grub")
    private var database: CKDatabase { container.publicCloudDatabase }

    private init() {}

    /// Fire-and-forget upload after a Muck is raised locally.
    func upload(_ muck: Muck) async {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: muck.id))
        record["muckId"] = muck.id
        record["location"] = muck.location
        record["muckDescription"] = muck.muckDescription
        record["typeRaw"] = muck.typeRaw
        record["isHazardous"] = muck.isHazardous ? 1 : 0
        record["reportedDate"] = muck.reportedDate
        record["latitude"] = muck.latitude
        record["longitude"] = muck.longitude
        record["votes"] = muck.votes
        record["eventCount"] = muck.eventCount
        record["isClosed"] = muck.isClosed ? 1 : 0
        record["ownerId"] = muck.ownerId
        record["flagCount"] = muck.flagCount
        record["location_loc"] = CLLocation(latitude: muck.latitude, longitude: muck.longitude)

        do {
            _ = try await database.save(record)
            muck.syncedToCloud = true
        } catch {
            print("⚠️ CloudKitMuckSyncService.upload failed, will retry later: \(error)")
        }
    }

    /// Re-attempts upload for any local mucks that never confirmed a
    /// successful sync — the case where Raise a Muck happened offline,
    /// or the earlier attempt hit a transient CloudKit/network error.
    /// Call this opportunistically (e.g. on Home's load) rather than
    /// wiring up a persistent background queue.
    func retryPendingUploads(_ mucks: [Muck]) async {
        for muck in mucks where !muck.syncedToCloud {
            await upload(muck)
        }
    }

    /// Push a vote/close-state change up to the shared record so other
    /// users see it too. Best-effort — local state is already the source
    /// of truth for this device regardless of outcome.
    func update(_ muck: Muck) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: muck.id))
            record["votes"] = muck.votes
            record["isClosed"] = muck.isClosed ? 1 : 0
            record["flagCount"] = muck.flagCount
            _ = try await database.save(record)
        } catch {
            print("⚠️ CloudKitMuckSyncService.update failed: \(error)")
        }
    }

    /// Fetch mucks other users have raised nearby. Returns plain, unmanaged
    /// Muck instances — the caller is responsible for de-duping against
    /// local SwiftData by `id` before inserting. Mucks that have already
    /// been flagged past the hide threshold on the shared database are
    /// filtered out here so they never even reach a device that hasn't
    /// seen them yet.
    func fetchNearby(_ coordinate: CLLocationCoordinate2D, radiusMetres: Double) async -> [Muck] {
        let centre = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let predicate = NSPredicate(
            format: "distanceToLocation:fromLocation:(%K, %@) < %f",
            "location_loc", centre, radiusMetres
        )
        let query = CKQuery(recordType: recordType, predicate: predicate)

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 200)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return Muck(from: record)
            }.filter { !$0.isHiddenByFlags }
        } catch {
            print("⚠️ CloudKitMuckSyncService.fetchNearby failed: \(error)")
            return []
        }
    }

    /// A user flagged a muck as spam/abuse/duplicate — increments the
    /// shared flag count. Read-modify-write against the current record
    /// rather than the caller's stale copy, since multiple people may be
    /// flagging concurrently.
    func flag(muckId: String) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: muckId))
            let current = record["flagCount"] as? Int ?? 0
            record["flagCount"] = current + 1
            _ = try await database.save(record)
        } catch {
            print("⚠️ CloudKitMuckSyncService.flag failed: \(error)")
        }
    }
}

extension Muck {
    convenience init?(from record: CKRecord) {
        guard
            let id = record["muckId"] as? String,
            let location = record["location"] as? String,
            let description = record["muckDescription"] as? String,
            let typeRaw = record["typeRaw"] as? String,
            let type = MuckType(rawValue: typeRaw),
            let reportedDate = record["reportedDate"] as? Date,
            let latitude = record["latitude"] as? Double,
            let longitude = record["longitude"] as? Double
        else { return nil }

        self.init(
            id: id,
            location: location,
            description: description,
            type: type,
            isHazardous: (record["isHazardous"] as? Int ?? 0) == 1,
            reportedDate: reportedDate,
            latitude: latitude,
            longitude: longitude,
            votes: record["votes"] as? Int ?? 0,
            eventCount: record["eventCount"] as? Int ?? 0,
            isClosed: (record["isClosed"] as? Int ?? 0) == 1,
            ownerId: record["ownerId"] as? String ?? "",
            flagCount: record["flagCount"] as? Int ?? 0
        )
    }
}
