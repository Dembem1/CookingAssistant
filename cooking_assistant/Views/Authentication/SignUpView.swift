import SwiftUI

struct SignUpView: View {

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 55))
                    .foregroundColor(Color(red: 0.35, green: 0.48, blue: 0.34))

                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Join CookWise and discover what to cook.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {

                TextField("Full name", text: $name)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: signUp) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.35, green: 0.48, blue: 0.34))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(.secondary)

                Button("Log In") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.35, green: 0.48, blue: 0.34))
                .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(24)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        errorMessage = ""

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your name."
            return
        }

        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must contain at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true

        authService.signUp(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email,
            password: password
        ) { result in
            DispatchQueue.main.async {
                isLoading = false

                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
