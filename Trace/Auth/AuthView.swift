import SwiftUI

struct AuthView: View {
    enum Mode: String, Hashable {
        case signIn = "Sign in"
        case signUp = "Sign up"
    }

    @Environment(AuthManager.self) private var auth

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    @FocusState private var focused: Field?
    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                    .padding(.top, 48)

                Picker("", selection: $mode) {
                    Text(Mode.signIn.rawValue).tag(Mode.signIn)
                    Text(Mode.signUp.rawValue).tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in
                    errorMessage = nil
                    infoMessage = nil
                }

                form

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                submitButton

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.tint)
            Text("Trace")
                .font(.largeTitle.bold())
            Text("Record your trails. Find new ones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await submit() } }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isWorking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(mode == .signIn ? "Sign in" : "Create account")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isValid || isWorking)
    }

    private var isValid: Bool {
        email.contains("@") && email.contains(".") && password.count >= 6
    }

    private func submit() async {
        errorMessage = nil
        infoMessage = nil
        focused = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
            case .signUp:
                let sessionCreated = try await auth.signUp(email: email, password: password)
                if !sessionCreated {
                    infoMessage = "Check your email to confirm your account, then sign in."
                    mode = .signIn
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
