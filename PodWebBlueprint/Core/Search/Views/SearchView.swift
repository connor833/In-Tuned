import SwiftUI

struct SearchView: View {
    @State private var selectedFilter: SearchFilterViewModel = .pods
    @Namespace var animation
    @Environment(\.presentationMode) var mode
    @StateObject private var searchViewModel: SearchViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State var grid = false
    @State var searchText = ""
    @State var isSearching = false
    @State var isTyping = false
    @FocusState private var keyboardFocused: Bool
    
    @State private var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    @State private var podViewModels: [String: PodViewModel] = [:]

    let minDragTranslationForSwipe: CGFloat = 50
    
    var user: User
    
    init(user: User) {
        self.user = user
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(authViewModel: AuthViewModel.shared))
    }
    
    var body: some View {
        VStack {
            // Header with cool back button
            HStack {
                Button {
                    withAnimation {
                        mode.wrappedValue.dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Search")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            // Search bar section
            HStack {
                TextField("Search...", text: $searchText)
                    .padding(8)
                    .padding(.horizontal, 24)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .focused($keyboardFocused)
                    .onSubmit {
                        searchBoth()
                    }
                    .submitLabel(.search)
                
                Button {
                    searchBoth()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .frame(alignment: .trailing)
                            .padding(.trailing, 8)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if keyboardFocused {
                VStack {
                    HStack {
                        Text("Recent Searches")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if !recentSearches.isEmpty {
                            Button {
                                withAnimation {
                                    clearAllSearches()
                                }
                            } label: {
                                Text("Remove All")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    
                    Divider()
                        .padding(.horizontal)
                    
                    ScrollView {
                        ForEach(recentSearches, id: \.self) { search in
                            HStack {
                                Button {
                                    searchText = search
                                    searchBoth()
                                } label: {
                                    HStack {
                                        Text(search)
                                            .padding(.vertical)
                                            .foregroundColor(Color("textColor"))
                                        
                                        Spacer()
                                    }
                                }
                                
                                Button {
                                    withAnimation {
                                        deleteSearch(search) // Animate search deletion
                                    }
                                } label: {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .padding(.trailing)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .transition(.move(edge: .bottom)) // Animate the recent search list
            } else {
                SearchFilterBar
                    .padding()
                
                if selectedFilter == .pods {
                    if isSearching {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    } else {
                        if searchViewModel.pods.isEmpty && searchText != "" {
                            Spacer()
                            Text("Sorry there are no pods matching your search.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchViewModel.pods) { pod in
                                    PodRowViewThin(pod: pod)
                                        .foregroundColor(Color("textColor"))
                                        .onAppear {
                                            // Load more when reaching the last few items
                                            if pod.id == searchViewModel.pods.last?.id {
                                                searchViewModel.loadMorePods() {}
                                            }
                                        }
                                }
                                
                                // Loading indicator at bottom
                                if searchViewModel.isLoadingMore && searchViewModel.hasMorePods {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                        Text("Loading more pods...")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                }
                                
                                // End of results indicator
                                if !searchViewModel.hasMorePods && !searchViewModel.pods.isEmpty {
                                    Text("No more pods to load")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                        }
                    }
                } else if selectedFilter == .users {
                    if searchViewModel.users.isEmpty && searchText != "" {
                        Spacer()
                        Text("Sorry there are no users matching your search.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    ScrollView {
                        LazyVStack {
                            ForEach(searchViewModel.users) { user in
                                NavigationLink {
                                    if authViewModel.userSession?.uid != user.id {
                                        ProfileView(user: user)
                                    } else {
                                        UserTabView(user: user)
                                    }
                                } label: {
                                    ProfileRowView(user: user)
                                        .foregroundColor(Color("textColor"))
                                }
                                .onAppear {
                                    // Load more when reaching the last few items
                                    if user.id == searchViewModel.users.last?.id {
                                        searchViewModel.loadMoreUsers() {}
                                    }
                                }
                            }
                            
                            // Loading indicator at bottom
                            if searchViewModel.isLoadingMore && searchViewModel.hasMoreUsers {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Loading more users...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            
                            // End of results indicator
                            if !searchViewModel.hasMoreUsers && !searchViewModel.users.isEmpty {
                                Text("No more users to load")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    self.handleSwipe(translation: gesture.translation.width)
                }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                keyboardFocused = true
            }
            recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func searchBoth() {
        isSearching = true
        if searchText == "" {
            searchText = recentSearches.first ?? ""
        }
        searchViewModel.searchPods(query: searchText) {
            searchViewModel.searchUsers(query: searchText) {
                isSearching = false
            }
        }
        saveSearch()
        keyboardFocused = false
    }
    
    private func handleSwipe(translation: CGFloat) {
        if translation > minDragTranslationForSwipe {
            withAnimation {
                selectedFilter = .pods
            }
        } else if translation < -minDragTranslationForSwipe {
            withAnimation {
                selectedFilter = .users
            }
        }
    }
    
    private func saveSearch() {
        guard !searchText.isEmpty else { return }
        if let index = recentSearches.firstIndex(of: searchText) {
            recentSearches.remove(at: index)
        }
        recentSearches.insert(searchText, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
    
    private func deleteSearch(_ search: String) {
        recentSearches.removeAll { $0 == search }
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
    
    private func clearAllSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
    
    private func getPodViewModel(for pod: Pod) -> PodViewModel {
        let podId = pod.id ?? ""
        if let cached = podViewModels[podId] {
            return cached
        } else {
            let newVM = PodViewModel(pod: pod)
            DispatchQueue.main.async {
                podViewModels[podId] = newVM
            }
            return newVM
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            SearchView(user: PreviewClass().previewUser)
                .preferredColorScheme(colorScheme)
        }
    }
}

extension SearchView {
    var SearchFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(SearchFilterViewModel.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                        self.selectedFilter = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 16, weight: selectedFilter == item ? .semibold : .medium))
                        .foregroundColor(selectedFilter == item ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            ZStack {
                // Background container
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                
                // Animated selection indicator
                HStack(spacing: 0) {
                    ForEach(SearchFilterViewModel.allCases, id: \.rawValue) { item in
                        if selectedFilter == item {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                                .matchedGeometryEffect(id: "selectedTab", in: animation)
                        } else {
                            Color.clear
                        }
                    }
                }
                .padding(4)
            }
        )
    }
}
