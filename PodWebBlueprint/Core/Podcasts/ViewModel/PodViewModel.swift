import SwiftUI
import Firebase
import FirebaseAuth

class PodViewModel: ObservableObject {


    
    @Published var pod: Pod
    @Published var isLiked: Bool = false
    @Published var hasLoadedUser: Bool = false
    
    // Loading states for optimistic UI
    @Published var isLikeActionInProgress = false
    @Published var isSaveActionInProgress = false
    private let service = PodService()
    private let userService = UserService()
    private let notificationService = NotificationService()
    private var userLoadTask: Task<Void, Never>?
    
    
    init(pod: Pod) {
        self.pod = pod
        self.isLiked = pod.didLike ?? false
        
        
        // Only check likes/saves if pod has a valid id
        if let id = pod.id, !id.isEmpty {
            checkIfUserLikedPod()
            checkIfUserSavedPod()
        }
        
        // Load user data if not already present
        if pod.user == nil && !pod.userId.isEmpty {
            Task {
                await loadUser()
            }
        } else if pod.user != nil {
            hasLoadedUser = true
        }
    }
    
    deinit {
        userLoadTask?.cancel()
    }
    
    func likePod() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let id = pod.id, !id.isEmpty else { return }
        
        // Set loading state
        isLikeActionInProgress = true
        
        // Optimistic UI update - change immediately
        withAnimation {
            self.pod.didLike = true
            self.isLiked = true
            self.pod.likes = self.pod.likes + 1
        }
        
        service.likePod(pod) { [weak self] in
            DispatchQueue.main.async {
                // Success - keep optimistic changes
                print("✅ Like successful - likes = \(self?.pod.likes ?? 0)")
                
                // Create notification for the pod creator
                self?.notificationService.createNotification(
                    type: .like,
                    senderId: currentUid,
                    recipientId: self?.pod.userId ?? "",
                    contentId: self?.pod.id ?? ""
                ) { _ in }
                
                // Reset loading state
                self?.isLikeActionInProgress = false
            }
        }
    }
    
    func unlikePod() {
        guard let id = pod.id, !id.isEmpty else { return }
        
        // Set loading state
        isLikeActionInProgress = true
        
        // Store current state for potential rollback
        let wasLiked = pod.didLike
        let previousLikes = pod.likes
        
        // Optimistic UI update - change immediately
        withAnimation {
            self.pod.didLike = false
            self.isLiked = false
            self.pod.likes = max(0, self.pod.likes - 1)
        }
        
        service.unlikePod(pod) { [weak self] in
            DispatchQueue.main.async {
                // Success - keep optimistic changes
                print("✅ Unlike successful - likes = \(self?.pod.likes ?? 0)")
                
                // Reset loading state
                self?.isLikeActionInProgress = false
            }
        }
    }
    
    func checkIfUserLikedPod() {
        guard let id = pod.id, !id.isEmpty else { return }
        service.checkIfUserLikedPod(pod) { didLike in
            if didLike {
                self.pod.didLike = true
                self.isLiked = true
            }
        }
    }
    
    func checkIfUserSavedPod() {
        guard let id = pod.id, !id.isEmpty else { return }
        service.checkIfUserSavedPod(pod) { didSave in
            if didSave {
                self.pod.didSave = true
            }
        }
    }
    
    func savePod() {
        guard let id = pod.id, !id.isEmpty else { return }
        
        // Prevent multiple simultaneous save operations
        guard !isSaveActionInProgress else { 
            print("⚠️ Save already in progress, ignoring duplicate call")
            return 
        }
        
        // Set loading state
        isSaveActionInProgress = true
        
        // Debug: Check pod description
        print("🔍 SavePod Debug - Pod ID: \(id)")
        print("🔍 SavePod Debug - Pod title: '\(pod.title)'")
        print("🔍 SavePod Debug - Pod description: '\(pod.description)'")
        print("🔍 SavePod Debug - Description isEmpty: \(pod.description.isEmpty)")
        
        // Optimistic UI update - change immediately
        withAnimation {
            self.pod.didSave = true
        }
        
        service.savePod(pod) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Success - keep optimistic changes
                    print("✅ Save successful - pod saved")
                case .failure(let error):
                    // Rollback optimistic changes
                    print("❌ Save failed: \(error.localizedDescription)")
                    withAnimation {
                        self?.pod.didSave = false
                    }
                }
                
                // Reset loading state
                self?.isSaveActionInProgress = false
            }
        }
    }
    
    func unsavePod() {
        guard let id = pod.id, !id.isEmpty else { return }
        
        // Prevent multiple simultaneous unsave operations
        guard !isSaveActionInProgress else { 
            print("⚠️ Unsave already in progress, ignoring duplicate call")
            return 
        }
        
        // Set loading state
        isSaveActionInProgress = true
        
        // Store current state for potential rollback
        let wasSaved = pod.didSave
        
        // Optimistic UI update - change immediately
        withAnimation {
            self.pod.didSave = false
        }
        
        service.unsavePod(pod) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Success - keep optimistic changes
                    print("✅ Unsave successful - pod unsaved")
                case .failure(let error):
                    // Rollback optimistic changes
                    print("❌ Unsave failed: \(error.localizedDescription)")
                    withAnimation {
                        self?.pod.didSave = wasSaved
                    }
                }
                
                // Reset loading state
                self?.isSaveActionInProgress = false
            }
        }
    }
    


    
    func deletePod(completion: @escaping () -> Void = {}) {
        guard let id = pod.id, !id.isEmpty else { 
            print("❌ [PodViewModel] Pod has no ID, skipping deletion")
            completion()
            return 
        }
        print("🗑️ [PodViewModel] Calling PodService.deletePod for: \(pod.title) (ID: \(id))")
        print("🗑️ [PodViewModel] Pod fileUrl: \(pod.fileUrl)")
        print("🗑️ [PodViewModel] Pod userId: \(pod.userId)")
        
        service.deletePod(pod: pod) {
            print("✅ [PodViewModel] PodService.deletePod completed for: \(self.pod.title)")
            completion()
        }
    }
    
    @MainActor
    func loadUser() async {
        print("🔍 POD_VIEWMODEL: loadUser called for pod: \(pod.id ?? "no-id")")
        print("🔍 POD_VIEWMODEL: pod.userId: \(pod.userId)")
        print("🔍 POD_VIEWMODEL: hasLoadedUser: \(hasLoadedUser)")
        print("🔍 POD_VIEWMODEL: current pod.user: \(pod.user?.username ?? "nil")")
        print("🔍 POD_VIEWMODEL: pod.title: \(pod.title)")
        print("🔍 POD_VIEWMODEL: pod.fileUrl: \(pod.fileUrl)")
        
        // If we already have the user data, don't load it again
        if hasLoadedUser {
            print("🔍 POD_VIEWMODEL: User already loaded, skipping")
            return
        }
        
        // If we're already loading the user, don't start another load
        if userLoadTask != nil {
            print("🔍 POD_VIEWMODEL: User loading already in progress, skipping")
            return
        }
        
        // Only try to load user if pod.userId is not empty
        guard !pod.userId.isEmpty else { 
            print("❌ POD_VIEWMODEL: pod.userId is empty, cannot load user")
            return 
        }
        
        print("🔍 POD_VIEWMODEL: Starting user load for userId: \(pod.userId)")
        
        // Create a new task for loading the user using shared cache
        userLoadTask = Task { @MainActor in
            UserCacheService.shared.getUser(userId: pod.userId) { user in
                // Only update if the task hasn't been cancelled
                if !Task.isCancelled {
                    if let user = user {
                        self.pod.user = user
                        self.hasLoadedUser = true
                        print("✅ POD_VIEWMODEL: User loaded successfully: \(user.username)")
                        print("✅ POD_VIEWMODEL: hasLoadedUser set to: \(self.hasLoadedUser)")
                    } else {
                        print("❌ POD_VIEWMODEL: Failed to load user from cache service")
                    }
                } else {
                    print("⚠️ POD_VIEWMODEL: Task was cancelled, not updating user")
                }
            }
            userLoadTask = nil
        }
    }
    
    var isSaved: Bool {
        return pod.didSave ?? false
    }

    func toggleLike() {
        if isLiked {
            unlikePod()
        } else {
            likePod()
        }
    }

    func toggleSave() {
        if isSaved {
            unsavePod()
        } else {
            savePod()
        }
    }
    
    func refreshSaveState() {
        // Only check saves if pod has a valid id
        if let id = pod.id, !id.isEmpty {
            checkIfUserSavedPod()
        }
    }

    

    
}
