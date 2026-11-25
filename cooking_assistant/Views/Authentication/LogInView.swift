import SwiftUI

struct LogInView: View {

    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.35, green: 0.48, blue: 0.34))

                Text("CookWise")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Welcome back!")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {

                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: logIn) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Log In")
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
                Text("Don't have an account?")
                    .foregroundColor(.secondary)

                NavigationLink("Sign Up") {
                    SignUpView()
                }
                .foregroundColor(Color(red: 0.35, green: 0.48, blue: 0.34))
                .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(24)
        .navigationBarBackButtonHidden(true)
    }

    private func logIn() {
        errorMessage = ""

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true

        authService.logIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false

                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
