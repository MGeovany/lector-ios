import SwiftUI

struct MainTabView: View {
  enum Tab: Hashable {
    case home
    case favorites
    case add
    case preferences
    case profile
  }

  @State private var selectedTab: Tab = .home
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tag(Tab.home)

      FavoritesView()
        .tag(Tab.favorites)

      AddView()
        .tag(Tab.add)

      PreferencesView()
        .tag(Tab.preferences)

      ProfileView()
        .tag(Tab.profile)
    }
    // We render a custom tab bar; hide the system one.
    .toolbar(.hidden, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      tabBar
        // Extend the bar to the absolute bottom (covers the home-indicator safe area)
        // to avoid a white gap below the bar.
        .ignoresSafeArea(.container, edges: .bottom)
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedTab)
  }

  private var tabBar: some View {
    HStack(spacing: 0) {
      TabBarItemButton(
        title: "Home",
        icon: selectedTab == .home ? "house.fill" : "house",
        isSelected: selectedTab == .home,
        action: { selectedTab = .home }
      )

      TabBarItemButton(
        title: "Favorites",
        icon: selectedTab == .favorites ? "heart.fill" : "heart",
        isSelected: selectedTab == .favorites,
        action: { selectedTab = .favorites }
      )

      TabBarItemButton(
        title: "Add",
        icon: selectedTab == .add ? "plus.app.fill" : "plus.app",
        isSelected: selectedTab == .add,
        action: { selectedTab = .add }
      )

      TabBarItemButton(
        title: "Preferences",
        icon: selectedTab == .preferences
          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle",
        isSelected: selectedTab == .preferences,
        action: { selectedTab = .preferences }
      )

      TabBarItemButton(
        title: "Profile",
        icon: selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle",
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
  let icon: String
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Image(systemName: icon)
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(
            isSelected
              ? AppColors.tabSelected(for: colorScheme) : AppColors.tabUnselected(for: colorScheme))

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

#Preview {
  MainTabView()
    .environmentObject(SubscriptionStore())
}
