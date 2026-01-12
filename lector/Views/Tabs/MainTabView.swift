import SwiftUI

struct MainTabView: View {
  enum Tab: Hashable {
    case home
    case favorites
    case preferences
    case profile
  }

  @State private var selectedTab: Tab = .home
  @State private var isTabBarHidden: Bool = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(AppSession.self) private var session

  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tag(Tab.home)

      FavoritesView()
        .tag(Tab.favorites)

      PreferencesView()
        .tag(Tab.preferences)

      ProfileView()
        .tag(Tab.profile)
    }
    // We render a custom tab bar; hide the system one.
    .toolbar(.hidden, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !isTabBarHidden {
        tabBar
          // Extend the bar to the absolute bottom (covers the home-indicator safe area)
          // to avoid a white gap below the bar.
          .ignoresSafeArea(.container, edges: .bottom)
      }
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedTab)
    .onPreferenceChange(TabBarHiddenPreferenceKey.self) { shouldHide in
      withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
        isTabBarHidden = shouldHide
      }
    }
  }

  private var tabBar: some View {
    HStack(spacing: 0) {
      TabBarItemButton(
        title: "Home",
        icon: selectedTab == .home ? .asset("HomeIconActive") : .asset("HomeIcon"),
        isSelected: selectedTab == .home,
        action: { selectedTab = .home }
      )

      TabBarItemButton(
        title: "Favorites",
        icon: selectedTab == .favorites ? .system("heart.fill") : .system("heart"),
        isSelected: selectedTab == .favorites,
        action: { selectedTab = .favorites }
      )

      TabBarItemButton(
        title: "Preferences",
        icon: selectedTab == .preferences
          ? .system("line.3.horizontal.decrease.circle.fill")
          : .system("line.3.horizontal.decrease.circle"),
        isSelected: selectedTab == .preferences,
        action: { selectedTab = .preferences }
      )

      TabBarItemButton(
        title: "Profile",
        icon: .profileAvatar(url: session.profile?.avatarURL),
        isSelected: selectedTab == .profile,
        action: { selectedTab = .profile }
      )
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
    .padding(.bottom, 6)
    .background(
      Rectangle()
        .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))
        .ignoresSafeArea(.container, edges: .bottom)
    )
    .overlay(
      Rectangle()
        .fill(Color(.separator).opacity(colorScheme == .dark ? 0.35 : 0.8))
        .frame(height: 1),
      alignment: .top
    )
  }
}

struct TabBarItemButton: View {
  let title: String
  let icon: TabBarIcon
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      VStack(spacing: 2) {
        TabBarIconView(icon: icon, isSelected: isSelected)

        Text(title)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(
            isSelected
              ? AppColors.tabSelected(for: colorScheme) : AppColors.tabUnselected(for: colorScheme))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
    }
    .buttonStyle(PlainButtonStyle())
    .accessibilityLabel(title)
  }
}

enum TabBarIcon: Equatable {
  case system(String)
  case asset(String)
  case profileAvatar(url: URL?)
}

struct TabBarIconView: View {
  let icon: TabBarIcon
  let isSelected: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    switch icon {
    case .system(let name):
      Image(systemName: name)
        .font(.system(size: 20, weight: .regular))
        .foregroundStyle(foreground)

    case .asset(let name):
      Image(name)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 22, height: 22)
        .foregroundStyle(foreground)

    case .profileAvatar(let url):
      if let url {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          default:
            Image(systemName: "person.crop.circle")
              .resizable()
              .scaledToFit()
              .padding(3)
          }
        }
        .frame(width: 24, height: 24)
        .background(Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06))
        .clipShape(Circle())
        .overlay(
          Circle()
            .stroke(foreground.opacity(isSelected ? 0.30 : 0.18), lineWidth: 0)
        )
      } else {
        Image(systemName: "person.crop.circle")
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(foreground)
      }
    }
  }

  private var foreground: Color {
    isSelected ? AppColors.tabSelected(for: colorScheme) : AppColors.tabUnselected(for: colorScheme)
  }
}

#Preview {
  MainTabView()
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}
