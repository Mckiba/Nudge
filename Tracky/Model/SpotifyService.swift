//
//  SpotifyService.swift
//  Tracky
//
//  Created by McKiba Williams on 4/5/25.
//

import Foundation
import Combine

// MARK: - Spotify Service

class SpotifyService: ObservableObject {
    // Authentication properties
    private let clientID: String
    private let clientSecret: String
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?
    
    // Playback state
    @Published var isPlaying: Bool = false
    @Published var currentTrack: SpotifyTrack?
    @Published var currentPlaylist: SpotifyPlaylist?
    @Published var recommendedPlaylists: [SpotifyPlaylist] = []
    @Published var isAuthorized: Bool = false
    
    // Constants
    private let authURL = "https://accounts.spotify.com/authorize"
    private let tokenURL = "https://accounts.spotify.com/api/token"
    private let apiBaseURL = "https://api.spotify.com/v1"
    private let redirectURI = "attentiontracker://callback"
    
    private var cancellables = Set<AnyCancellable>()
    private var playbackTimer: Timer?
    
    init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        
        // Check if we already have stored credentials
        loadCredentials()
        setupPlaybackTimer()
        
        // Set up notification observer for code
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyAuthCode"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let code = notification.userInfo?["code"] as? String {
                print("SpotifyService: Received auth code from notification: \(String(code.prefix(10)))...")
                self?.exchangeCodeForToken(code: code)
            }
        }
    }
    
    // MARK: - Authentication
    
    func getAuthorizationURL() -> URL? {
        let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing streaming"
        let urlString = "\(authURL)?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&scope=\(scopes)"
        let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        print("Opening Spotify auth URL: \(encodedURL)")
        return URL(string: encodedURL)
    }
    
    func handleAuthCallback(url: URL) {
        print("SpotifyService: Received callback URL: \(url)")
        print("SpotifyService: URL Scheme: \(url.scheme ?? "nil"), Path: \(url.path), Query: \(url.query ?? "nil")")
        
        guard let code = extractCode(from: url) else {
            print("SpotifyService: Failed to extract auth code from URL: \(url)")
            return
        }
        print("SpotifyService: Successfully extracted auth code: \(String(code.prefix(10)))...")
        
        // Exchange code for token
        print("SpotifyService: Calling exchangeCodeForToken with code...")
        exchangeCodeForToken(code: code)
    }
    
    private func extractCode(from url: URL) -> String? {
        // First try with a direct query parameter check
        if let query = url.query {
            print("SpotifyService.extractCode: Direct query string approach")
            let queryComponents = query.components(separatedBy: "&")
            for component in queryComponents {
                let keyValuePair = component.components(separatedBy: "=")
                if keyValuePair.count == 2 && keyValuePair[0] == "code" {
                    let code = keyValuePair[1]
                    return code
                }
            }
        }
        
        // Try the URLComponents approach as a fallback
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("SpotifyService.extractCode: Failed to create URL components")
            return nil
        }
        
        
        // First try to get code from query items
        if let queryItems = components.queryItems {
            print("SpotifyService.extractCode: Query items: \(queryItems)")
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                print("SpotifyService.extractCode: Found code in query items: \(String(code.prefix(10)))...")
                return code
            }
        }
        
        print("SpotifyService.extractCode: No code found in URL: \(url)")
        return nil
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: tokenURL) else {
            print("SpotifyService.exchangeCodeForToken: Invalid token URL")
            return
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let parameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        
        print("SpotifyService.exchangeCodeForToken: Token exchange parameters: \(parameters)")
        
        let bodyString = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        print("SpotifyService.exchangeCodeForToken: Request body: \(bodyString)")
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        print("SpotifyService.exchangeCodeForToken: Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        print("SpotifyService.exchangeCodeForToken: Sending token exchange request to \(url)")
        // Use a traditional URLSession data task for better debugging
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("SpotifyService.exchangeCodeForToken: Received response from token exchange")
            
            if let error = error {
                print("SpotifyService.exchangeCodeForToken: Token exchange network error: \(error)")
                return
            }
            
            guard response is HTTPURLResponse else {
                print("SpotifyService.exchangeCodeForToken: No HTTP response received")
                return
            }
              
            guard let data = data else {
                print("SpotifyService.exchangeCodeForToken: No data received in token exchange")
                return
            }
            
            // Try to decode the response
            do {
                // First try to parse as JSON to see what's in there
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("SpotifyService.exchangeCodeForToken: JSON response: \(json)")
                }
                
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(SpotifyTokenResponse.self, from: data)
               
                DispatchQueue.main.async {
                    print("SpotifyService.exchangeCodeForToken: Updating app state with token")
                    self?.accessToken = tokenResponse.accessToken
                    self?.refreshToken = tokenResponse.refreshToken
                    self?.tokenExpirationDate = Date().addingTimeInterval(Double(tokenResponse.expiresIn))
                    self?.isAuthorized = true
                    self?.saveCredentials()
                    print("SpotifyService.exchangeCodeForToken: Token saved and user authorized!")
                    print("SpotifyService.exchangeCodeForToken: Fetching recommended playlists")
                    self?.fetchRecommendedPlaylists()
                }
            } catch {
                print("SpotifyService.exchangeCodeForToken: Failed to decode token response: \(error)")
                
                // Try to get more specific decoding error details
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("SpotifyService.exchangeCodeForToken: Key '\(key.stringValue)' not found: \(context.debugDescription)")
                        print("SpotifyService.exchangeCodeForToken: codingPath: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("SpotifyService.exchangeCodeForToken: Value '\(type)' not found: \(context.debugDescription)")
                        print("SpotifyService.exchangeCodeForToken: codingPath: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("SpotifyService.exchangeCodeForToken: Type '\(type)' mismatch: \(context.debugDescription)")
                        print("SpotifyService.exchangeCodeForToken: codingPath: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("SpotifyService.exchangeCodeForToken: Data corrupted: \(context.debugDescription)")
                        print("SpotifyService.exchangeCodeForToken: codingPath: \(context.codingPath)")
                    @unknown default:
                        print("SpotifyService.exchangeCodeForToken: Unknown decoding error: \(decodingError)")
                    }
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("SpotifyService.exchangeCodeForToken: JSON response: \(json)")
                    if let errorInfo = json["error"] as? String {
                        print("SpotifyService.exchangeCodeForToken: Error from Spotify: \(errorInfo)")
                    } else if let errorObj = json["error"] as? [String: Any], 
                              let errorDesc = errorObj["message"] as? String {
                        print("SpotifyService.exchangeCodeForToken: Error from Spotify: \(errorDesc)")
                    }
                }
            }
        }.resume()
    }
    
    private func refreshTokenIfNeeded() {
        guard let refreshToken = refreshToken,
              let expirationDate = tokenExpirationDate,
              expirationDate.timeIntervalSinceNow < 300 else { return }
        
        guard let url = URL(string: tokenURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyTokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Token refresh error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                self?.accessToken = response.accessToken
                self?.tokenExpirationDate = Date().addingTimeInterval(Double(response.expiresIn))
                self?.saveCredentials()
            })
            .store(in: &cancellables)
    }
    
    private func saveCredentials() {
        let credentials: [String: Any] = [
            "accessToken": accessToken as Any,
            "refreshToken": refreshToken as Any,
            "expirationDate": tokenExpirationDate as Any
        ]
        
        UserDefaults.standard.set(credentials, forKey: "SpotifyCredentials")
    }
    
    private func loadCredentials() {
        guard let credentials = UserDefaults.standard.dictionary(forKey: "SpotifyCredentials") else { return }
        
        accessToken = credentials["accessToken"] as? String
        refreshToken = credentials["refreshToken"] as? String
        tokenExpirationDate = credentials["expirationDate"] as? Date
        
        isAuthorized = accessToken != nil
        
        if isAuthorized {
            refreshTokenIfNeeded()
            fetchCurrentPlayback()
            fetchRecommendedPlaylists()
        }
    }
    
    // MARK: - Playback Control
    
    func playPlaylist(_ playlist: SpotifyPlaylist) {
        guard let accessToken = accessToken else { return }
        
        let endpoint = "\(apiBaseURL)/me/player/play"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["context_uri": playlist.uri]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Play playlist error: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                self?.isPlaying = true
                self?.currentPlaylist = playlist
                self?.fetchCurrentPlayback()
            })
            .store(in: &cancellables)
    }
    
    func togglePlayPause() {
        guard let accessToken = accessToken else { return }
        
        let endpoint = "\(apiBaseURL)/me/player/\(isPlaying ? "pause" : "play")"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Toggle play/pause error: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                self?.isPlaying.toggle()
            })
            .store(in: &cancellables)
    }
    
    func nextTrack() {
        guard let accessToken = accessToken else { return }
        
        let endpoint = "\(apiBaseURL)/me/player/next"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Next track error: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.fetchCurrentPlayback()
                }
            })
            .store(in: &cancellables)
    }
    
    func previousTrack() {
        guard let accessToken = accessToken else { return }
        
        let endpoint = "\(apiBaseURL)/me/player/previous"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Previous track error: \(error)")
                }
            }, receiveValue: { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.fetchCurrentPlayback()
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Data Fetching
    
    func fetchCurrentPlayback() {
        guard let accessToken = accessToken else { return }
        
        let endpoint = "\(apiBaseURL)/me/player/currently-playing"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyCurrentPlaybackResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Fetch playback error: \(error)")
                }
            }, receiveValue: { [weak self] response in
                self?.isPlaying = response.isPlaying
                self?.currentTrack = response.item
            })
            .store(in: &cancellables)
    }
    
    func fetchRecommendedPlaylists() {
        guard let accessToken = accessToken else { return }
        
        print("SpotifyService: Fetching recommended playlists")
        
        // Use a simpler approach with just one focused search query
        let endpoint = "\(apiBaseURL)/search?q=study&type=playlist&limit=10"
        guard let url = URL(string: endpoint) else {
            print("SpotifyService: Invalid URL for playlist search")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Use traditional data task for better error handling and debugging
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("SpotifyService: Network error fetching playlists: \(error)")
                return
            }
            
            guard let data = data else {
                print("SpotifyService: No data received from playlists search")
                return
            }
            
            // Debug the response
            if let responseString = String(data: data, encoding: .utf8) {
                print("SpotifyService: Received playlist search response: \(responseString.prefix(300))...")
            }
            
            // Try to parse as raw JSON first
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("SpotifyService: Playlist JSON structure: \(json.keys)")
                
                // Manual extraction as fallback
                if let playlistsObj = json["playlists"] as? [String: Any],
                   let items = playlistsObj["items"] as? [[String: Any]] {
                    print("SpotifyService: Found \(items.count) playlists in JSON")
                    
                    var extractedPlaylists: [SpotifyPlaylist] = []
                    
                    for item in items {
                        if let id = item["id"] as? String,
                           let name = item["name"] as? String,
                           let description = item["description"] as? String,
                           let uri = item["uri"] as? String,
                           let images = item["images"] as? [[String: Any]] {
                            
                            var spotifyImages: [SpotifyImage] = []
                            for img in images {
                                if let url = img["url"] as? String {
                                    spotifyImages.append(SpotifyImage(
                                        url: url,
                                        width: img["width"] as? Int,
                                        height: img["height"] as? Int
                                    ))
                                }
                            }
                            
                            let playlist = SpotifyPlaylist(
                                id: id,
                                name: name,
                                description: description,
                                images: spotifyImages,
                                uri: uri
                            )
                            extractedPlaylists.append(playlist)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        print("SpotifyService: Setting \(extractedPlaylists.count) recommended playlists")
                        self?.recommendedPlaylists = extractedPlaylists
                    }
                    return
                }
            }
            
            // Try normal decoding if manual extraction wasn't necessary
            do {
                let response = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
                let nonNilPlaylists = response.playlists.items.compactMap { $0 }

                DispatchQueue.main.async {
                    print("SpotifyService: Successfully decoded \(response.playlists.items.count) playlists")
                    self?.recommendedPlaylists = nonNilPlaylists
                }
            } catch {
                print("SpotifyService: Failed to decode playlists: \(error)")
                
                // Try to add some example playlists as fallback
                DispatchQueue.main.async {
                    print("SpotifyService: Using fallback example playlists")
                    self?.recommendedPlaylists = [
                        SpotifyPlaylist(
                            id: "37i9dQZF1DX3PFzdbtx1Us",
                            name: "Deep Focus",
                            description: "Keep calm and focus with ambient and post-rock music.",
                            images: [SpotifyImage(url: "https://i.scdn.co/image/ab67706f00000003ca5a7517156021292e5663a4", width: 300, height: 300)],
                            uri: "spotify:playlist:37i9dQZF1DX3PFzdbtx1Us"
                        ),
                        SpotifyPlaylist(
                            id: "37i9dQZF1DWZeKCadgRdKQ",
                            name: "Lo-Fi Beats",
                            description: "Beats to relax, study, and focus.",
                            images: [SpotifyImage(url: "https://i.scdn.co/image/ab67706f000000035a3d24c35636cfaf0be91d1b", width: 300, height: 300)],
                            uri: "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ"
                        ),
                        SpotifyPlaylist(
                            id: "37i9dQZF1DX8NTLI2TtZa6",
                            name: "Instrumental Study",
                            description: "Focus with soft study music in the background.",
                            images: [SpotifyImage(url: "https://i.scdn.co/image/ab67706f000000035ec8c003898b362476ad7ae9", width: 300, height: 300)],
                            uri: "spotify:playlist:37i9dQZF1DX8NTLI2TtZa6"
                        )
                    ]
                }
            }
        }.resume()
    }
    
    func getPlaylistsForAttentionState(_ state: AttentionState) -> [SpotifyPlaylist] {
        return recommendedPlaylists
    }
    
    private func setupPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchCurrentPlayback()
        }
    }
    
    deinit {
        playbackTimer?.invalidate()
    }
    
    // MARK: - Debugging
    
    func debugCheckAuthorization() {
        print("DEBUG: Spotify authorization status")
        print("DEBUG: isAuthorized = \(isAuthorized)")
        print("DEBUG: accessToken exists = \(accessToken != nil)")
        print("DEBUG: refreshToken exists = \(refreshToken != nil)")
        
        if let token = accessToken, let expDate = tokenExpirationDate {
            print("DEBUG: Token expiration: \(expDate)")
            print("DEBUG: Time until expiration: \(expDate.timeIntervalSinceNow)")
            
            // Test a simple API call
            let endpoint = "\(apiBaseURL)/me"
            guard let url = URL(string: endpoint) else {
                print("DEBUG: Invalid API URL")
                return
            }
            
            print("DEBUG: Testing API call to /me endpoint")
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("DEBUG: API error: \(error)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: HTTP response status: \(httpResponse.statusCode)")
                    
                    // If we get a 401, try to refresh the token
                    if httpResponse.statusCode == 401 {
                        print("DEBUG: Token is invalid, trying to refresh...")
                        self.tryToRefreshToken()
                    }
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("DEBUG: API response: \(responseString)")
                }
            }.resume()
        } else {
            print("DEBUG: No valid token available")
            print("DEBUG: Checking if any stored credentials are available...")
            
            // Try to load from UserDefaults
            if let storedData = UserDefaults.standard.dictionary(forKey: "SpotifyCredentials") {
                print("DEBUG: Found stored credentials: \(storedData)")
            } else {
                print("DEBUG: No stored credentials found in UserDefaults")
            }
            
            // Test direct URL opening for re-authentication
            print("DEBUG: You can try re-authenticating by clicking 'Connect Spotify' again")
        }
    }
    
    private func tryToRefreshToken() {
        guard let refreshToken = refreshToken else {
            print("No refresh token available")
            return
        }
        
        print("Attempting to refresh token...")
        
        guard let url = URL(string: tokenURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Token refresh network error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Token refresh HTTP status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("No data received in token refresh")
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Token refresh raw response: \(responseString)")
            }
            
            do {
                let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                print("Refresh successful, new token received")
                
                DispatchQueue.main.async {
                    self?.accessToken = tokenResponse.accessToken
                    self?.tokenExpirationDate = Date().addingTimeInterval(Double(tokenResponse.expiresIn))
                    if let newRefreshToken = tokenResponse.refreshToken {
                        self?.refreshToken = newRefreshToken
                    }
                    self?.isAuthorized = true
                    self?.saveCredentials()
                    print("Refreshed token saved!")
                }
            } catch {
                print("Failed to decode refresh token response: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Special handlers
    
    /// Method that can be called via a static function to handle an authentication callback
    /// even if there's no direct reference to the SpotifyService instance
    static func handleCallbackUrlStatic(_ url: URL) {
        print("SpotifyService.handleCallbackUrlStatic: Called with URL \(url)")
        
        // Try to extract code directly as a backup
        func extractCodeFromUrl(_ url: URL) -> String? {
            print("SpotifyService.handleCallbackUrlStatic: Directly extracting code")
            
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems,
               let code = queryItems.first(where: { $0.name == "code" })?.value {
                return code
            }
            
            // Try direct query parsing
            if let query = url.query {
                let pairs = query.components(separatedBy: "&")
                for pair in pairs {
                    let keyValue = pair.components(separatedBy: "=")
                    if keyValue.count == 2 && keyValue[0] == "code" {
                        return keyValue[1]
                    }
                }
            }
            
            return nil
        }
        
        // Use the notification to broadcast the extracted code
        if let code = extractCodeFromUrl(url) {
            print("SpotifyService.handleCallbackUrlStatic: Found code: \(String(code.prefix(10)))...")
            
            // Post a notification with the code for any listening SpotifyService
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpotifyAuthCode"),
                    object: nil,
                    userInfo: ["code": code]
                )
            }
        } else {
            print("SpotifyService.handleCallbackUrlStatic: Failed to extract code from URL: \(url)")
        }
    }
}

// MARK: - Spotify API Models

struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct SpotifyTrack: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SpotifyTrack, rhs: SpotifyTrack) -> Bool {
        return lhs.id == rhs.id
    }
}

struct SpotifyArtist: Decodable, Identifiable {
    let id: String
    let name: String
}

struct SpotifyAlbum: Decodable {
    let name: String
    let images: [SpotifyImage]
}

struct SpotifyImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

struct SpotifyPlaylist: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let images: [SpotifyImage]
    let uri: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SpotifyPlaylist, rhs: SpotifyPlaylist) -> Bool {
        return lhs.id == rhs.id
    }
}

struct SpotifyCurrentPlaybackResponse: Decodable {
    let isPlaying: Bool
    let item: SpotifyTrack
    
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
    }
}

struct SpotifyPlaylistsResponse: Decodable {
    let items: [SpotifyPlaylist?]
}

struct SpotifySearchResponse: Decodable {
    let playlists: SpotifyPlaylistsResponse
}
