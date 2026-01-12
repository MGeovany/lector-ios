import SwiftUI

struct WelcomeView: View {
  @Environment(AppSession.self) private var session
  @State private var isShowingPhoneAlert: Bool = false
  @State private var isShowingAuthAlert: Bool = false

  var body: some View {
    ZStack {
      Color.white.ignoresSafeArea()

      VStack(spacing: 0) {
        header

        Spacer(minLength: 0)

        hero

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .padding(.horizontal, 24)
      .padding(.top, 18)
      .safeAreaInset(edge: .bottom) {
        footer
          .padding(.horizontal, 24)
          .padding(.bottom, 14)
      }
    }
    // Always white, regardless of the app theme.
    .preferredColorScheme(.light)
    .alert("Continue with phone", isPresented: $isShowingPhoneAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Coming soon.")
    }
    .onChange(of: session.alertMessage) { _, newValue in
      isShowingAuthAlert = (newValue != nil)
    }
    .alert("Sign in", isPresented: $isShowingAuthAlert) {
      Button("OK", role: .cancel) { session.alertMessage = nil }
    } message: {
      Text(session.alertMessage ?? "")
    }
  }

  private var header: some View {
    // Intentionally minimal: the logo/title lives in the hero to keep focus centered.
    Color.clear
      .frame(height: 8)
  }

  private var hero: some View {
    VStack(spacing: 10) {
      Text("Lector")
        .font(.custom("CinzelDecorative-Bold", size: 18))
        .foregroundStyle(.black.opacity(0.92))

      Text("Your next read awaits.")
        .font(.system(size: 30, weight: .semibold, design: .default))
        .foregroundStyle(.black.opacity(0.92))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: 420)
    .padding(.horizontal, 8)
  }

  private var footer: some View {
    VStack(spacing: 12) {
      Button {
        session.beginGoogleSignIn()
      } label: {
        HStack(spacing: 10) {
          Image("GoogleLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: 20, height: 20)

          Text("Continue with Google")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black.opacity(0.86))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(Color.white)
        .overlay(
          Capsule().stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)

      Button {
        isShowingPhoneAlert = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "phone.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(0.18)))

          Text("Continue with phone")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(AppColors.matteBlack)
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)

      Text("By continuing, you agree to our Privacy Policy and Terms & Conditions.")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.black.opacity(0.45))
        .multilineTextAlignment(.center)
        .padding(.top, 2)
    }
  }

}

#Preview {
  WelcomeView()
    .environment(AppSession())
    .environmentObject(PreferencesViewModel())
    .environmentObject(SubscriptionStore())
}
