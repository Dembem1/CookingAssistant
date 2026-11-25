import SwiftUI
import FirebaseAuth

struct ProfileView: View {

    @EnvironmentObject var authService: AuthService
    
    @Binding var pantryItems: [PantryItem]
    @Binding var shoppingListItems: [ShoppingListItem]
    
    @State private var showLogoutConfirmation = false
    @State private var logoutError = ""

    private var userName: String {
        guard let currentUser = authService.user else {
            return "CookWise User"
        }

        return currentUser.displayName ?? "CookWise User"
    }

    private var userEmail: String {
        guard let currentUser = authService.user else {
            return "No email available"
        }

        return currentUser.email ?? "No email available"
    }

    private var userInitials: String {
        let parts = userName.split(separator: " ")

        let initials = parts.prefix(2).compactMap {
            $0.first
        }

        return initials.isEmpty
            ? "U"
            : String(initials).uppercased()
    }

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    profileHeader
                    accountSection
                    recipesSection
                    logoutSection
                }
                .padding(AppTheme.screenPadding)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) { logOut() }
            } message: {
                Text("Are you sure you want to log out of CookWise?")
            }
        }

    // MARK: Profile Header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            Text(userInitials)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.forest)
                .frame(width: 88, height: 88)
                .background(AppTheme.sage, in: Circle())
                .accessibilityHidden(true)
            Text(userName)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text(userEmail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: Account and Recipes

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Account")
            NavigationLink {
                DietaryPreferencesView()
            } label: {
                profileRow(icon: "leaf", title: "Dietary Preferences", subtitle: "Manage your diet and allergies")
                    .cookWiseCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("My Recipes")
            VStack(spacing: 12) {
                NavigationLink {
                    MyRecipesView(initialSection: .saved, pantryItems: $pantryItems, shoppingListItems: $shoppingListItems)
                } label: {
                    profileRow(icon: "bookmark", title: "Saved Recipes", subtitle: "View your favourite recipes")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    MyRecipesView(initialSection: .created, pantryItems: $pantryItems, shoppingListItems: $shoppingListItems)
                } label: {
                    profileRow(icon: "book.closed", title: "Created Recipes", subtitle: "Manage recipes you have published")
                }
                .buttonStyle(.plain)
            }
            .cookWiseCard()
        }
    }

    private var logoutSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
            }
            .buttonStyle(.plain)
            if !logoutError.isEmpty {
                Text(logoutError).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    // MARK: Shared Profile Components

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title3.bold()).foregroundStyle(AppTheme.text)
            .accessibilityAddTraits(.isHeader)
    }

    private func profileRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 42, height: 42)
                .background(AppTheme.sage, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
                Text(subtitle).font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func logOut() {
        logoutError = ""
        do { try authService.logOut() }
        catch { logoutError = error.localizedDescription }
    }
}
