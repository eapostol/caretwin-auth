import SwiftUI

struct ContentView: View {
    @StateObject private var auth = CareTwinAuth()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var models: [ModelData] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if auth.isAuthenticated() {
                    authenticatedView
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("CareTwin LiDAR")
            .padding()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("CareTwin LiDAR Scanner")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Sign in to access your 3D models and scanning tools")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: signIn) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Sign In")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(isLoading)
        }
    }
    
    private var authenticatedView: some View {
        VStack(spacing: 20) {
            userInfoView
            modelsView
            signOutButton
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(auth.user?.name ?? auth.user?.preferredUsername ?? "User")
                        .font(.headline)
                    
                    if let email = auth.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if !auth.getUserRoles().isEmpty {
                HStack {
                    Text("Roles:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(auth.getUserRoles().joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var modelsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("3D Models")
                    .font(.headline)
                
                Spacer()
                
                Button(action: loadModels) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("Loading models...")
                    .frame(maxWidth: .infinity)
            } else if models.isEmpty {
                Text("No models available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(models, id: \.id) { model in
                        ModelRowView(model: model)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            loadModels()
        }
    }
    
    private var signOutButton: some View {
        Button(action: signOut) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        auth.login { result in
            isLoading = false
            
            switch result {
            case .success(let user):
                print("Successfully signed in: \(user.name ?? user.preferredUsername ?? "Unknown")")
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func signOut() {
        auth.logout()
        models = []
    }
    
    private func loadModels() {
        guard let accessToken = auth.accessToken else { return }
        
        isLoading = true
        
        guard let url = URL(string: "http://localhost:8000/models") else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Failed to load models: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
                    models = response.models
                } catch {
                    errorMessage = "Failed to decode models: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct ModelRowView: View {
    let model: ModelData
    
    var body: some View {
        HStack {
            Image(systemName: "cube.fill")
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(model.filePath)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .monospaced()
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

struct ModelsResponse: Codable {
    let models: [ModelData]
}

struct ModelData: Codable {
    let id: String
    let name: String
    let description: String
    let filePath: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case filePath = "file_path"
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}