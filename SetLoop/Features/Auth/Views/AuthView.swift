import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SetLoop")
                            .font(.largeTitle.bold())
                        Text("Conecta fechas, salas, musicos y DJs profesionales.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.authMode == .mock {
                        Label("Usando modo demo local", systemImage: "bolt.horizontal.circle")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Picker("Modo", selection: $viewModel.mode) {
                        Text("Login").tag(AuthViewModel.Mode.login)
                        Text("Registro").tag(AuthViewModel.Mode.register)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 14) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                            .authFieldStyle()

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(viewModel.mode == .login ? .password : .newPassword)
                            .authFieldStyle()

                        if viewModel.mode == .register {
                            TextField("Nombre publico", text: $viewModel.displayName)
                                .textContentType(.name)
                                .authFieldStyle()

                            TextField("Ciudad", text: $viewModel.city)
                                .textContentType(.addressCity)
                                .authFieldStyle()

                            Picker("Tipo de cuenta", selection: $viewModel.selectedRole) {
                                ForEach(UserRole.allCases) { role in
                                    Text(role.displayName).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
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
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
            }
            .accessibilityIdentifier("auth.root")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canSubmit: Bool {
        let hasCredentials = !viewModel.email.isEmpty && !viewModel.password.isEmpty
        if viewModel.mode == .login {
            return hasCredentials
        }

        return hasCredentials && !viewModel.displayName.isEmpty && !viewModel.city.isEmpty
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
