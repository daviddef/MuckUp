import CloudKit

/// Squads on the same public database as Mucks — a join-code-based group
/// with a shared point total, so two friends or a whole class can see one
/// number climb together instead of just their own. No SwiftData model:
/// a squad is just shared metadata (name, code, totals), so a plain
/// CloudKit record is enough — nothing here needs to live offline-first.
@MainActor
final class CloudKitSquadSyncService {
    static let shared = CloudKitSquadSyncService()

    private let recordType = "Squad"
    private let container = CKContainer(identifier: "iCloud.com.daviddef.grub")
    private var database: CKDatabase { container.publicCloudDatabase }

    private init() {}

    struct SquadInfo {
        let code: String
        let name: String
        let totalPoints: Int
        let memberCount: Int
    }

    /// 6-character codes are short enough to read out loud or type from
    /// memory, and collisions are astronomically unlikely at this app's
    /// scale — no need for a uniqueness check against the database.
    static func generateCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no 0/O/1/I ambiguity
        return String((0..<6).map { _ in letters.randomElement()! })
    }

    func create(name: String) async -> SquadInfo? {
        let code = Self.generateCode()
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: code))
        record["name"] = name
        record["totalPoints"] = 0
        record["memberCount"] = 1
        do {
            _ = try await database.save(record)
            return SquadInfo(code: code, name: name, totalPoints: 0, memberCount: 1)
        } catch {
            print("⚠️ CloudKitSquadSyncService.create failed: \(error)")
            return nil
        }
    }

    func join(code: String) async -> SquadInfo? {
        let upperCode = code.uppercased()
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: upperCode))
            let memberCount = (record["memberCount"] as? Int ?? 0) + 1
            record["memberCount"] = memberCount
            _ = try await database.save(record)
            return SquadInfo(
                code: upperCode,
                name: record["name"] as? String ?? "Squad",
                totalPoints: record["totalPoints"] as? Int ?? 0,
                memberCount: memberCount
            )
        } catch {
            print("⚠️ CloudKitSquadSyncService.join failed: \(error)")
            return nil
        }
    }

    func refresh(code: String) async -> SquadInfo? {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: code))
            return SquadInfo(
                code: code,
                name: record["name"] as? String ?? "Squad",
                totalPoints: record["totalPoints"] as? Int ?? 0,
                memberCount: record["memberCount"] as? Int ?? 1
            )
        } catch {
            print("⚠️ CloudKitSquadSyncService.refresh failed: \(error)")
            return nil
        }
    }

    /// Read-modify-write since multiple members may be scoring
    /// concurrently — a stale local total would silently overwrite theirs.
    func addPoints(code: String, amount: Int) async {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: code))
            let current = record["totalPoints"] as? Int ?? 0
            record["totalPoints"] = current + amount
            _ = try await database.save(record)
        } catch {
            print("⚠️ CloudKitSquadSyncService.addPoints failed: \(error)")
        }
    }

    func fetchLeaderboard(limit: Int = 20) async -> [SquadInfo] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "totalPoints", ascending: false)]
        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: limit)
            return results.compactMap { id, result in
                guard let record = try? result.get() else { return nil }
                return SquadInfo(
                    code: id.recordName,
                    name: record["name"] as? String ?? "Squad",
                    totalPoints: record["totalPoints"] as? Int ?? 0,
                    memberCount: record["memberCount"] as? Int ?? 1
                )
            }
        } catch {
            print("⚠️ CloudKitSquadSyncService.fetchLeaderboard failed: \(error)")
            return []
        }
    }
}
