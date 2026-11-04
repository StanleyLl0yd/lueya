import Foundation

/// Fail-closed rules for renewing a short-lived provider-signed raw media URL.
/// A fresh 403 is an access denial, not evidence that the signature expired.
public enum MediaSourceRenewalPolicy {
    public static let maximumRenewals = 6

    public static func shouldRenew(
        _ error: MediaRangeError, source: PlayableSource, now: Date = Date()
    ) -> Bool {
        switch error {
        case .expiredSource:
            return true
        case .forbidden:
            return !source.isFresh(now: now)
        default:
            return false
        }
    }

    public static func accepts(original: ResolvedTrack, replacement: ResolvedTrack) -> Bool {
        replacement.metadata.id == original.metadata.id &&
            replacement.source.codec == original.source.codec &&
            replacement.source.quality == original.source.quality &&
            replacement.source.isFresh() &&
            MusicCDNPolicy.accepts(replacement.source.url)
    }
}
