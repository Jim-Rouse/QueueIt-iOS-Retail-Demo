// QueueItView.swift
import SwiftUI
import QueueItKit

// MARK: - Root view

public struct ShopItRootView: View {
    @StateObject private var viewModel = QueueItViewModel()

    public var body: some View {
        Group {
            if viewModel.loginComplete {
                ShopItProductListView(viewModel: viewModel)
            } else {
                LoginView(viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showWebView) {
            queueWebViewContent
        }
    }

    @ViewBuilder
    private var queueWebViewContent: some View {
        if viewModel.hybridManager.showWebView,
           let manager = viewModel.hybridManager.viewManager {
            QueueWebViewContainer(
                viewManager: manager,
                progressBackgroundColor: Color(.systemBackground),
                progressColor: Color.accentColor
            )
        } else if let manager = viewModel.simpleViewManager {
            QueueWebViewContainer(
                viewManager: manager,
                progressBackgroundColor: Color(.systemBackground),
                progressColor: Color.accentColor
            )
        }
    }
}

// MARK: - Login screen (Simple integration)

struct LoginView: View {
    @ObservedObject var viewModel: QueueItViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                        Text("Shop-it")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Sign in to your account")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                        Text("Protected by Queue-it (Simple Integration)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())

                    VStack(spacing: 16) {
                        FloatingTextField(title: "Email", text: $email, isSecure: false)
                        FloatingTextField(title: "Password", text: $password, isSecure: true)
                    }
                    .padding(.horizontal, 24)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        viewModel.runLoginQueue()
                    } label: {
                        HStack {
                            if viewModel.isLoading { ProgressView().tint(.white) }
                            Text("Sign In").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "00C853"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Product list (Hybrid integration)

struct ShopItProductListView: View {
    @ObservedObject var viewModel: QueueItViewModel
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                Group {
                    if viewModel.isLoading && viewModel.products.isEmpty {
                        ProgressView("Loading products…")
                    } else if let error = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Unable to load products",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                        .overlay(alignment: .bottom) {
                            Button("Retry") { viewModel.loadProducts() }
                                .buttonStyle(.borderedProminent)
                                .padding()
                        }
                    } else {
                        productGrid
                    }
                }
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { queueStateBadge }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") { viewModel.logout() }
                }
            }
            .task { viewModel.loadProducts() }
        }
    }

    private var productGrid: some View {
        ScrollView {
            HStack(spacing: 6) {
                Image(systemName: "server.rack").foregroundStyle(.blue)
                Text("API protected by Queue-it (Hybrid Integration)").font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.products) { product in
                    ProductCardView(product: product) {
                        // add to cart — wire up as needed
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var queueStateBadge: some View {
        switch viewModel.queueState {
        case .queuing:   Label("In Queue",  systemImage: "clock.fill").foregroundStyle(.orange)
        case .checking:  Label("Checking",  systemImage: "network").foregroundStyle(.blue)
        case .passed:    Label("Passed",    systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        default:         EmptyView()
        }
    }
}

// MARK: - Floating text field helper

struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}
