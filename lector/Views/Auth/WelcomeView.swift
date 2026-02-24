import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
  @Environment(AppSession.self) private var session
  @State private var isShowingPhoneAlert: Bool = false
  @State private var isShowingAuthAlert: Bool = false
  @State private var appleNonce: String?

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
          Capsule().stroke(Color.black.opacity(0.30), lineWidth: 1)
        )
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)

      SignInWithAppleButton(.signIn) { request in
        let rawNonce = AppleSignInNonce.random()
        appleNonce = rawNonce
        request.requestedScopes = [.email, .fullName]
        request.nonce = AppleSignInNonce.sha256(rawNonce)
      } onCompletion: { result in
        guard let rawNonce = appleNonce, !rawNonce.isEmpty else {
          session.alertMessage = "Couldn't start Apple sign-in. Missing nonce."
          PostHogAnalytics.captureError(message: "Apple sign-in: Missing nonce.", context: ["action": "sign_in_apple"])
          return
        }

        switch result {
        case .success(let auth):
          guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
            session.alertMessage = "Apple sign-in failed. Invalid credentials."
            PostHogAnalytics.captureError(message: "Apple sign-in: Invalid credentials.", context: ["action": "sign_in_apple"])
            return
          }
          guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            !idToken.isEmpty
          else {
            session.alertMessage = "Apple sign-in failed. Missing identity token."
            PostHogAnalytics.captureError(message: "Apple sign-in: Missing identity token.", context: ["action": "sign_in_apple"])
            return
          }
          session.signInWithApple(idToken: idToken, nonce: rawNonce)
        case .failure(let error):
          let errMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
          session.alertMessage = errMsg
          PostHogAnalytics.captureError(message: errMsg, context: ["action": "sign_in_apple"])
        }
      }
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .signInWithAppleButtonStyle(.black)

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
