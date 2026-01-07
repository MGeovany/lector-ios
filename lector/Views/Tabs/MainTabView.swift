import SwiftUI

struct MainTabView: View {
    enum Tab: Int {
        case home = 0
        case favorites = 1
        case add = 2
        case preferences = 3
        case profile = 4
    }

    @State private var selectedTab: Tab = .home
    
    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .favorites:
                    FavoritesView()
                case .add:
                    AddView()
                case .preferences:
                    PreferencesView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedTab)
    }

    private var tabBar: some View {
        HStack(spacing: 25) {
            TabBarButton(
                icon: selectedTab == .home ? "house.fill" : "house",
                isSelected: selectedTab == .home,
                action: { selectedTab = .home }
            )

            TabBarButton(
                icon: selectedTab == .favorites ? "heart.fill" : "heart",
                isSelected: selectedTab == .favorites,
                action: { selectedTab = .favorites }
            )

            CenterTabBarButton(
                icon: selectedTab == .add ? "plus.app.fill" : "plus.app",
                isSelected: selectedTab == .add,
                action: { selectedTab = .add }
            )

            TabBarButton(
                icon: selectedTab == .preferences ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle",
                isSelected: selectedTab == .preferences,
                action: { selectedTab = .preferences }
            )

            TabBarButton(
                icon: selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle",
                isSelected: selectedTab == .profile,
                action: { selectedTab = .profile }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color.black.opacity(0.85))
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))

                Capsule(style: .continuous)
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(width: 16, height: 3)
            }
            .frame(width: 52, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CenterTabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Same vertical layout as the other tabs (icon + indicator placeholder),
            // but with a slightly larger icon.
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.white)

                Capsule(style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 16, height: 3)
            }
            .frame(width: 52, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Add")
    }
}

#Preview {
    MainTabView()
}
