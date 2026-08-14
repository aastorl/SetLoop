import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        authHeader
                        authPanel
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 560, alignment: .leading)
                }
            }
            .accessibilityIdentifier("auth.root")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $viewModel.isPasswordResetRequestPresented) {
            PasswordResetRequestSheet(viewModel: viewModel)
                .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $viewModel.isPasswordUpdatePresented) {
            PasswordUpdateSheet(viewModel: viewModel)
                .presentationDetents([.height(330)])
                .interactiveDismissDisabled(viewModel.isUpdatingRecoveredPassword)
        }
    }

    private var authHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "music.note")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("SetLoop")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Fechas, salas, musicos y DJs en un mismo flujo profesional.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var authPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if viewModel.authMode == .mock {
                AuthStatusMessage(
                    text: "Usando modo demo local",
                    systemImage: "bolt.horizontal.circle",
                    tint: .orange
                )
            }

            Picker("Modo", selection: $viewModel.mode) {
                Text("Login").tag(AuthViewModel.Mode.login)
                Text("Registro").tag(AuthViewModel.Mode.register)
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                AuthTextField(
                    title: "Email",
                    text: $viewModel.email,
                    systemImage: "envelope",
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocapitalization: .never
                )

                AuthSecureField(
                    title: "Password",
                    text: $viewModel.password,
                    systemImage: "lock",
                    contentType: viewModel.mode == .login ? .password : .newPassword
                )

                if viewModel.mode == .login {
                    HStack {
                        Spacer()

                        Button {
                            viewModel.beginPasswordResetRequest()
                        } label: {
                            Label("Olvide mi contrasena", systemImage: "questionmark.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        .font(.footnote.weight(.medium))
                    }
                    .padding(.top, 2)
                }

                if viewModel.mode == .register {
                    AuthTextField(
                        title: "Nombre publico",
                        text: $viewModel.displayName,
                        systemImage: "person",
                        contentType: .name
                    )

                    AuthTextField(
                        title: "Ciudad",
                        text: $viewModel.city,
                        systemImage: "location",
                        contentType: .addressCity
                    )

                    Picker("Tipo de cuenta", selection: $viewModel.selectedRole) {
                        ForEach(UserRole.allCases) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            VStack(spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    AuthStatusMessage(text: errorMessage, systemImage: "exclamationmark.triangle", tint: .red)
                }

                if let passwordResetMessage = viewModel.passwordResetMessage {
                    AuthStatusMessage(text: passwordResetMessage, systemImage: "checkmark.circle", tint: .green)
                }

                if let passwordResetErrorMessage = viewModel.passwordResetErrorMessage {
                    AuthStatusMessage(text: passwordResetErrorMessage, systemImage: "exclamationmark.triangle", tint: .red)
                }
            }

            Button {
                Task {
                    await viewModel.submit()
                }
            } label: {
                HStack {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(viewModel.mode == .login ? "Entrar" : "Crear cuenta")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isSubmitting || !canSubmit)
            .accessibilityIdentifier("auth.submitButton")

            if viewModel.authMode == .mock {
                Button {
                    Task {
                        await viewModel.enterDemo()
                    }
                } label: {
                    Label("Entrar como demo", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isSubmitting)
                .accessibilityIdentifier("auth.demoButton")
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var canSubmit: Bool {
        let hasCredentials = viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && viewModel.password.isEmpty == false
        if viewModel.mode == .login {
            return hasCredentials
        }

        return hasCredentials
            && viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && viewModel.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField(title, text: $text)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .submitLabel(.next)
        }
        .authFieldStyle()
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    let contentType: UITextContentType

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            SecureField(title, text: $text)
                .textContentType(contentType)
        }
        .authFieldStyle()
    }
}

private struct AuthStatusMessage: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PasswordResetRequestSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Te enviaremos un link para crear una contrasena nueva.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Email", text: $viewModel.passwordResetEmail)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .authFieldStyle()

                if let errorMessage = viewModel.passwordResetErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        await viewModel.requestPasswordReset()
                    }
                } label: {
                    HStack {
                        if viewModel.isRequestingPasswordReset {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Enviar email")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.canRequestPasswordReset == false)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Recuperar contrasena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PasswordUpdateSheet: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("El link fue validado. Define una contrasena nueva para volver a entrar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Nueva contrasena", text: $viewModel.recoveredPassword)
                    .textContentType(.newPassword)
                    .authFieldStyle()

                SecureField("Confirmar contrasena", text: $viewModel.recoveredPasswordConfirmation)
                    .textContentType(.newPassword)
                    .authFieldStyle()

                if let errorMessage = viewModel.passwordResetErrorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        await viewModel.completeRecoveredPasswordUpdate()
                    }
                } label: {
                    HStack {
                        if viewModel.isUpdatingRecoveredPassword {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Guardar contrasena")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.canUpdateRecoveredPassword == false)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Nueva contrasena")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension View {
    func authFieldStyle() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
