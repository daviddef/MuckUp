import SwiftUI

/// Plays a folder of hand-illustrated frame PNGs (under
/// Resources/Sprites/<stage>/frame_NNN.png) as a looping animation —
/// the real, richer art gradually replacing GrubCharacterView's flat
/// Canvas-drawn stand-ins one lifecycle stage at a time as matching
/// frame sets arrive. Falls back to nothing (caller decides what to
/// show instead) if a stage has no sprite folder yet.
struct AnimatedGrubSpriteView: View {
    let stage: GrubLifecycleStage
    var size: CGFloat = 72
    /// Frames-per-second for the loop — the source frames were captured
    /// at 24fps; slowed slightly here so a 36-frame set reads as a
    /// gentle idle breathing loop rather than a frantic flicker.
    var framesPerSecond: Double = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameIndex = 0

    private var frames: [UIImage] { Self.loadedFrames(for: stage) }

    var body: some View {
        Group {
            if frames.isEmpty {
                EmptyView()
            } else if reduceMotion {
                Image(uiImage: frames[frames.count / 2])
                    .resizable()
                    .scaledToFit()
            } else {
                TimelineView(.animation) { timeline in
                    Image(uiImage: frames[currentFrame(at: timeline.date)])
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func currentFrame(at date: Date) -> Int {
        guard !frames.isEmpty else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate
        let frame = Int(elapsed * framesPerSecond) % frames.count
        return frame
    }

    /// Does the given lifecycle stage have a hand-illustrated frame set
    /// yet? Callers (GrubCharacterView) use this to decide between the
    /// sprite and the flat vector fallback.
    static func hasSprite(for stage: GrubLifecycleStage) -> Bool {
        !loadedFrames(for: stage).isEmpty
    }

    // Frames are loaded once per stage and cached — 36 small PNGs is
    // cheap to hold in memory, and re-reading from disk every frame
    // would be wasteful.
    private static var cache: [GrubLifecycleStage: [UIImage]] = [:]

    // Sprites.bundle is copied into the app as a plain folder (the
    // .bundle extension is what makes Xcode preserve its internal
    // structure verbatim instead of flattening every file to the
    // bundle's top level, which is what happens to ordinary folders).
    private static func loadedFrames(for stage: GrubLifecycleStage) -> [UIImage] {
        if let cached = cache[stage] { return cached }
        guard let folder = stage.spriteFolderName,
              let spritesBundleURL = Bundle.main.url(forResource: "Sprites", withExtension: "bundle") else {
            cache[stage] = []
            return []
        }
        let resourceURL = spritesBundleURL.appendingPathComponent(folder)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) else {
            cache[stage] = []
            return []
        }
        let frames = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { UIImage(contentsOfFile: $0.path) }
        cache[stage] = frames
        return frames
    }
}

extension GrubLifecycleStage {
    /// Folder name under Sprites.bundle/ for this stage's frame set,
    /// or nil if no hand-illustrated sprite exists yet (falls back to
    /// the flat vector body plan in GrubCharacterView).
    var spriteFolderName: String? {
        switch self {
        case .grub: return "grub"
        // .egg, .bigGrub, .cocoon, .wingsOut, .fullFlight: no sprite
        // set yet — add a case here as each stage's frames arrive.
        default: return nil
        }
    }
}
