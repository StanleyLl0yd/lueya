import Foundation
import LueyaCore
import Observation

@MainActor
@Observable
final class MusicSignInModel {
    enum Status {
        case restoring
        case signedOut
        case requestingCode
        case awaitingAuthorization
        case signedIn(String)
        case failed(String)
    }

    private(set) var status: Status = .restoring
    private(set) var code: OAuthDeviceCode?

    @ObservationIgnored private let session = YandexMusicSession()
    @ObservationIgnored private var hasRestored = false
    @ObservationIgnored private var signInTask: Task<Void, Never>?

    func restoreIfNeeded() async {
        guard !hasRestored else { return }
        hasRestored = true

        do {
            if let account = try await session.restoreAccount() {
                status = .signedIn(account.account?.login ?? "Yandex Music account")
            } else {
                status = .signedOut
            }
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    func signIn() {
        signInTask?.cancel()
        code = nil
        status = .requestingCode

        signInTask = Task {
            do {
                let received = try await session.beginSignIn()
                try Task.checkCancellation()
                code = received
                status = .awaitingAuthorization

                let account = try await session.completeSignIn(code: received)
                try Task.checkCancellation()
                code = nil
                status = .signedIn(account.account?.login ?? "Yandex Music account")
            } catch is CancellationError {
                code = nil
                status = .signedOut
            } catch {
                code = nil
                status = .failed(Self.message(for: error))
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        code = nil
        status = .signedOut
    }

    func signOut() {
        signInTask?.cancel()
        signInTask = nil
        code = nil

        Task {
            do {
                try await session.signOut()
                status = .signedOut
            } catch {
                status = .failed(Self.message(for: error))
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let oauth = error as? YandexOAuthError {
            switch oauth {
            case .authorizationDenied:
                return "Authorization was declined."
            case .expired:
                return "Authorization expired. Please try again."
            case .invalidClient, .invalidCredentials:
                return "Yandex rejected the login session."
            case .rateLimited:
                return "Too many requests. Please try later."
            case .invalidResponse, .invalidVerificationURL, .httpStatus:
                return "Yandex authorization is currently unavailable."
            }
        }
        if let api = error as? MusicAPIError {
            switch api {
            case .unauthorized, .forbidden:
                return "This account cannot access Yandex Music."
            default:
                return "Could not verify the Yandex Music account."
            }
        }
        if error is TokenStorageError {
            return "Unable to access the local Keychain session."
        }
        return "Could not connect. Check your network and try again."
    }
}
