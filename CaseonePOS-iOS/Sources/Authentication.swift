import SwiftUI
import LocalAuthentication

@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signIn(login: String, password: String) async {
        guard !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Введите логин и пароль"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Демонстрационная авторизация. На этапе подключения API
        // здесь будет POST /api/auth/login и сохранение токена в Keychain.
        try? await Task.sleep(for: .milliseconds(650))
        isAuthenticated = true
    }

    func signInWithFaceID() async {
        let context = LAContext()
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            errorMessage = "Face ID недоступен на этом устройстве"
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Войдите в CaseonePOS Manager"
            )
            if success { isAuthenticated = true }
        } catch {
            errorMessage = "Не удалось выполнить вход через Face ID"
        }
    }

    func signOut() {
        isAuthenticated = false
    }
}

struct AppEntryView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        Group {
            if session.isAuthenticated {
                RootTabView()
                    .environmentObject(session)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
                    .environmentObject(session)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isAuthenticated)
    }
}

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var login = ""
    @State private var password = ""
    @State private var rememberMe = true
    @FocusState private var focusedField: Field?

    private enum Field { case login, password }

    var body: some View {
        ZStack {
            CaseoneTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 42)
                    brandHeader
                    credentialsCard
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(CaseoneTheme.gradient)
                    .frame(width: 104, height: 104)
                    .shadow(color: CaseoneTheme.deepTeal.opacity(0.24), radius: 20, y: 12)

                Image(systemName: "display.2")
                    .font(.system(size: 43, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("CaseonePOS")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(CaseoneTheme.deepTeal)

            Text("MANAGER")
                .font(.caption.weight(.semibold))
                .tracking(5)
                .foregroundStyle(CaseoneTheme.emerald)

            Text("Управляйте бизнесом из любого места")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var credentialsCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Добро пожаловать!")
                    .font(.title2.bold())
                Text("Войдите в свой аккаунт")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            inputField(title: "Телефон или e-mail", icon: "person.fill", text: $login, field: .login)

            SecureField("Пароль", text: $password)
                .focused($focusedField, equals: .password)
                .textContentType(.password)
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.08)))

            HStack {
                Toggle("Запомнить меня", isOn: $rememberMe)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button("Забыли пароль?") { }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CaseoneTheme.emerald)
            }

            if let error = session.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await session.signIn(login: login, password: password) }
            } label: {
                HStack {
                    if session.isLoading { ProgressView().tint(.white) }
                    Text(session.isLoading ? "Вход..." : "Войти")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrandButtonStyle())
            .disabled(session.isLoading)

            HStack {
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                Text("или").font(.caption).foregroundStyle(.secondary)
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            }

            Button {
                Task { await session.signInWithFaceID() }
            } label: {
                Label("Войти с Face ID", systemImage: "faceid")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(CaseoneTheme.deepTeal)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(CaseoneTheme.deepTeal.opacity(0.22)))
        }
        .padding(20)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: CaseoneTheme.deepTeal.opacity(0.08), radius: 24, y: 12)
    }

    private func inputField(title: String, icon: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(CaseoneTheme.emerald)
            TextField(title, text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.08)))
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? CaseoneTheme.emerald : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == CheckboxToggleStyle {
    static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
