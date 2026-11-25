import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isCheckingAuth = true
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener {
            [weak self] _, user in

            self?.user = user
            self?.isCheckingAuth = false
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: Sign Up
    func signUp(
        name: String,
        email: String,
        password: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Auth.auth().createUser(
            withEmail: email,
            password: password
        ) { result, error in

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user else {
                completion(.failure(NSError(
                    domain: "AuthService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not create account."
                    ]
                )))
                return
            }

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name

            changeRequest.commitChanges { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: Log In
    func logIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Auth.auth().signIn(
            withEmail: email,
            password: password
        ) { _, error in

            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: Log Out
    func logOut() throws {
        try Auth.auth().signOut()
    }
}
