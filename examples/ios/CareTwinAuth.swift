import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

/**
 * CareTwin Keycloak iOS Integration
 *
 * This class provides authentication utilities for the LiDAR iOS App
 * to integrate with Keycloak for user authentication and authorization.
 */
class CareTwinAuth: NSObject {
    
    // MARK: - Configuration
    private let keycloakURL: String
    private let realm: String
    private let clientId: String
    private let redirectURI: String
    
    // MARK: - URLs
    private var baseURL: String { "\(keycloakURL)/realms/\(realm)" }
    private var authURL: String { "\(baseURL)/protocol/openid-connect/auth" }
    private var tokenURL: String { "\(baseURL)/protocol/openid-connect/token" }
    private var logoutURL: String { "\(baseURL)/protocol/openid-connect/logout" }
    private var userInfoURL: String { "\(baseURL)/protocol/openid-connect/userinfo" }
    
    // MARK: - Storage Keys
    private let accessTokenKey = "caretwin_access_token"
    private let refreshTokenKey = "caretwin_refresh_token"
    private let idTokenKey = "caretwin_id_token"
    
    // MARK: - Properties
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var idToken: String?
    private(set) var user: UserInfo?
    
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    init(keycloakURL: String = "http://localhost:8080",
         realm: String = "caretwin",
         clientId: String = "lidar-ios-app",
         redirectURI: String = "com.caretwin.lidar://oauth/callback") {
        
        self.keycloakURL = keycloakURL
        self.realm = realm
        self.clientId = clientId
        self.redirectURI = redirectURI
        
        super.init()
        
        loadStoredTokens()
        setupTokenRefresh()
    }
    
    // MARK: - Authentication
    
    /**
     * Start OAuth authentication flow using ASWebAuthenticationSession
     */
    func login(completion: @escaping (Result<UserInfo, AuthError>) -> Void) {
        let state = generateState()
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        let authSession = ASWebAuthenticationSession(
            url: components.url!,
            callbackURLScheme: "com.caretwin.lidar"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleAuthCallback(
                    callbackURL: callbackURL,
                    error: error,
                    codeVerifier: codeVerifier,
                    state: state,
                    completion: completion
                )
            }
        }
        
        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = false
        authSession.start()
    }
    
    /**
     * Handle OAuth callback and exchange code for tokens
     */
    private func handleAuthCallback(callbackURL: URL?,
                                   error: Error?,
                                   codeVerifier: String,
                                   state: String,
                                   completion: @escaping (Result<UserInfo, AuthError>) -> Void) {
        
        if let error = error {
            completion(.failure(.authenticationFailed(error.localizedDescription)))
            return
        }
        
        guard let callbackURL = callbackURL else {
            completion(.failure(.authenticationFailed("No callback URL received")))
            return
        }
        
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            completion(.failure(.authenticationFailed("No authorization code received")))
            return
        }
        
        let receivedState = components?.queryItems?.first(where: { $0.name == "state" })?.value
        guard receivedState == state else {
            completion(.failure(.authenticationFailed("State mismatch")))
            return
        }
        
        exchangeCodeForTokens(code: code, codeVerifier: codeVerifier) { [weak self] result in
            switch result {
            case .success(let tokenResponse):
                self?.storeTokens(tokenResponse)
                self?.loadUserInfo { userResult in
                    completion(userResult)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /**
     * Exchange authorization code for tokens
     */
    private func exchangeCodeForTokens(code: String,
                                      codeVerifier: String,
                                      completion: @escaping (Result<TokenResponse, AuthError>) -> Void) {
        
        guard let url = URL(string: tokenURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleTokenResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    /**
     * Refresh access token using refresh token
     */
    func refreshAccessToken(completion: @escaping (Result<TokenResponse, AuthError>) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(.failure(.noRefreshToken))
            return
        }
        
        guard let url = URL(string: tokenURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleTokenResponse(data: data, response: response, error: error) { result in
                    switch result {
                    case .success(let tokenResponse):
                        self.storeTokens(tokenResponse)
                        completion(.success(tokenResponse))
                    case .failure:
                        self.logout()
                        completion(result)
                    }
                }
            }
        }.resume()
    }
    
    /**
     * Load user information from Keycloak
     */
    private func loadUserInfo(completion: @escaping (Result<UserInfo, AuthError>) -> Void) {
        guard let accessToken = accessToken else {
            completion(.failure(.noAccessToken))
            return
        }
        
        guard let url = URL(string: userInfoURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error.localizedDescription)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
                    self?.user = userInfo
                    completion(.success(userInfo))
                } catch {
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
            }
        }.resume()
    }
    
    /**
     * Logout user and clear tokens
     */
    func logout() {
        clearStoredTokens()
        user = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Token Management
    
    private func storeTokens(_ tokenResponse: TokenResponse) {
        accessToken = tokenResponse.accessToken
        refreshToken = tokenResponse.refreshToken
        idToken = tokenResponse.idToken
        
        UserDefaults.standard.set(tokenResponse.accessToken, forKey: accessTokenKey)
        if let refreshToken = tokenResponse.refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }
        if let idToken = tokenResponse.idToken {
            UserDefaults.standard.set(idToken, forKey: idTokenKey)
        }
        
        setupTokenRefresh()
    }
    
    private func loadStoredTokens() {
        accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        idToken = UserDefaults.standard.string(forKey: idTokenKey)
    }
    
    private func clearStoredTokens() {
        accessToken = nil
        refreshToken = nil
        idToken = nil
        
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: idTokenKey)
    }
    
    private func setupTokenRefresh() {
        refreshTimer?.invalidate()
        
        guard let accessToken = accessToken,
              let payload = decodeJWTPayload(accessToken) else {
            return
        }
        
        let exp = payload["exp"] as? TimeInterval ?? 0
        let expiryDate = Date(timeIntervalSince1970: exp)
        let refreshDate = expiryDate.addingTimeInterval(-60) // Refresh 1 minute before expiry
        
        if refreshDate > Date() {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshDate.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                self?.refreshAccessToken { _ in }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func isAuthenticated() -> Bool {
        guard let accessToken = accessToken else { return false }
        return !isTokenExpired(accessToken)
    }
    
    private func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        
        return Date() >= Date(timeIntervalSince1970: exp)
    }
    
    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else { return nil }
        
        let payloadSegment = segments[1]
        guard let payloadData = Data(base64URLEncoded: payloadSegment) else { return nil }
        
        return try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    }
    
    func getUserRoles() -> [String] {
        return user?.realmAccess?.roles ?? []
    }
    
    func hasRole(_ role: String) -> Bool {
        return getUserRoles().contains(role)
    }
    
    // MARK: - PKCE Helper Methods
    
    private func generateState() -> String {
        return UUID().uuidString
    }
    
    private func generateCodeVerifier() -> String {
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return data.base64URLEncodedString()
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
    
    // MARK: - Network Helper
    
    private func handleTokenResponse(data: Data?,
                                   response: URLResponse?,
                                   error: Error?,
                                   completion: @escaping (Result<TokenResponse, AuthError>) -> Void) {
        if let error = error {
            completion(.failure(.networkError(error.localizedDescription)))
            return
        }
        
        guard let data = data else {
            completion(.failure(.noData))
            return
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            completion(.success(tokenResponse))
        } catch {
            completion(.failure(.decodingError(error.localizedDescription)))
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension CareTwinAuth: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Data Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct UserInfo: Codable {
    let sub: String
    let email: String?
    let name: String?
    let preferredUsername: String?
    let realmAccess: RealmAccess?
    
    enum CodingKeys: String, CodingKey {
        case sub, email, name
        case preferredUsername = "preferred_username"
        case realmAccess = "realm_access"
    }
}

struct RealmAccess: Codable {
    let roles: [String]
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed(String)
    case networkError(String)
    case noData
    case decodingError(String)
    case noAccessToken
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .noAccessToken:
            return "No access token available"
        case .noRefreshToken:
            return "No refresh token available"
        }
    }
}

// MARK: - Data Extension for Base64URL

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        self.init(base64Encoded: base64)
    }
}