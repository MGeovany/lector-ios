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
    .padding(.vertical, 8)
    .padding(.horizontal, 18)
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
      VStack(spacing: 0) {
        TabBarIconView(icon: icon, isSelected: isSelected)
          .padding(.vertical, 6)

        Text(title)
          .font(.parkinsans(size: 12, weight: .light))
          .foregroundStyle(
            isSelected
              ? AppColors.tabSelected(for: colorScheme) : AppColors.tabUnselected(for: colorScheme))
      }
      .frame(maxWidth: .infinity)

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
  @EnvironmentObject private var subscription: SubscriptionStore
  @SceneStorage("lector_tab_profile_ring_did_animate") private var didAnimateProfileRingOnce: Bool =
    false
  @State private var profileRingRotation: Double = 0
  @State private var didTriggerAfterAvatarLoaded: Bool = false

  var body: some View {
    switch icon {
    case .system(let name):
      Image(systemName: name)
        .font(.parkinsans(size: 22, weight: .light))
        .foregroundStyle(foreground)

    case .asset(let name):
      Image(name)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 24, height: 24)
        .foregroundStyle(foreground)

    case .profileAvatar(let url):
      tabProfileAvatar(url: url, showProRing: subscription.isPro)
    }
  }

  private var foreground: Color {
    isSelected ? AppColors.tabSelected(for: colorScheme) : AppColors.tabUnselected(for: colorScheme)
  }

  private func tabProfileAvatar(url: URL?, showProRing: Bool) -> some View {
    if !showProRing {
      return AnyView(tabProfileAvatarPlain(url: url))
    }
    return AnyView(tabProfileAvatarWithProRing(url: url))
  }

  private func tabProfileAvatarPlain(url: URL?) -> some View {
    Group {
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
      } else {
        Image(systemName: "person.crop.circle")
          .font(.parkinsans(size: 20))
          .foregroundStyle(foreground)
      }
    }
    .frame(width: 24, height: 24)
    .background(Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06))
    .clipShape(Circle())
  }

  private func tabProfileAvatarWithProRing(url: URL?) -> some View {
    ZStack {
      Group {
        if let url {
          AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
              image
                .resizable()
                .scaledToFill()
                .onAppear {
                  triggerProfileRingAnimationIfNeeded()
                }
            default:
              Image(systemName: "person.crop.circle")
                .resizable()
                .scaledToFit()
                .padding(3)
            }
          }
        } else {
          Image(systemName: "person.crop.circle")
            .resizable()
            .scaledToFit()
            .padding(3)
        }
      }
      .frame(width: 24, height: 24)
      .background(Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06))
      .clipShape(Circle())

      Circle()
        .strokeBorder(
          AngularGradient(
            gradient: Gradient(colors: [
              Color(red: 0.89, green: 0.80, blue: 1.00),  // ~#E2CBFF
              Color(red: 0.22, green: 0.23, blue: 0.70),  // ~#393BB2
              Color(red: 0.89, green: 0.80, blue: 1.00),
            ]),
            center: .center,
            angle: .degrees(profileRingRotation)
          ),
          lineWidth: 2
        )
        .frame(width: 30, height: 30)
        .opacity(isSelected ? 1.0 : 0.92)
    }
    .frame(width: 30, height: 30)
  }

  private func triggerProfileRingAnimationIfNeeded() {
    // Only animate after avatar image is actually loaded (AsyncImage .success),
    // and only once per app launch/session.
    guard !didTriggerAfterAvatarLoaded else { return }
    didTriggerAfterAvatarLoaded = true

    guard !didAnimateProfileRingOnce else { return }
    didAnimateProfileRingOnce = true

    profileRingRotation = 0
    withAnimation(.linear(duration: 1.25)) {
      profileRingRotation = 360
    }
  }
}

#Preview {
  MainTabView()
    .environment(AppSession())
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}

#Preview("Pro User") {
  let proSubscription = SubscriptionStore(initialPlan: .founderLifetime, persistToDefaults: false)
  MainTabView()
    .environment(AppSession())
    .environmentObject(PreferencesViewModel())
    .environmentObject(proSubscription)
}
