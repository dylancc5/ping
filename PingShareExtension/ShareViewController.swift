import UIKit
import UniformTypeIdentifiers
import Supabase

// MARK: - ShareViewController

class ShareViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let nameField = PaddedTextField()
    private let howMetField = PaddedTextField()
    private let saveButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()

    private var prefilledURL: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadURL()
    }

    // MARK: - URL Loading

    private func loadURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first else {
            cancel()
            return
        }

        let urlType = UTType.url.identifier
        guard attachment.hasItemConformingToTypeIdentifier(urlType) else {
            cancel()
            return
        }

        attachment.loadItem(forTypeIdentifier: urlType) { [weak self] item, _ in
            DispatchQueue.main.async {
                if let url = item as? URL {
                    self?.handleURL(url)
                } else if let urlString = item as? String, let url = URL(string: urlString) {
                    self?.handleURL(url)
                } else {
                    self?.cancel()
                }
            }
        }
    }

    private func handleURL(_ url: URL) {
        prefilledURL = url.absoluteString

        if url.host?.contains("linkedin.com") == true {
            if let handle = extractLinkedInHandle(from: url) {
                nameField.placeholder = handle // best-effort from URL slug
            }
            howMetField.placeholder = "Where did you meet this person?"
        } else {
            howMetField.placeholder = "Where did you meet this person?"
        }
    }

    /// Extracts the LinkedIn profile handle from /in/<handle>/ path.
    private func extractLinkedInHandle(from url: URL) -> String? {
        let components = url.pathComponents
        guard let inIdx = components.firstIndex(of: "in"),
              components.index(after: inIdx) < components.endIndex else { return nil }
        let handle = components[components.index(after: inIdx)]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return handle.isEmpty ? nil : handle
    }

    // MARK: - Save

    @objc private func saveTapped() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let howMet = howMetField.text?.trimmingCharacters(in: .whitespaces) ?? ""

        guard !name.isEmpty else {
            shake(nameField)
            return
        }
        guard !howMet.isEmpty else {
            shake(howMetField)
            return
        }

        saveButton.isEnabled = false
        activityIndicator.startAnimating()
        statusLabel.text = "Saving..."

        Task {
            await saveContact(name: name, howMet: howMet, linkedinUrl: prefilledURL)
        }
    }

    @MainActor
    private func saveContact(name: String, howMet: String, linkedinUrl: String?) async {
        guard let client = makeSupabaseClient() else {
            showError("Ping is not configured. Please reinstall the app.")
            return
        }

        // Restore the auth session from the shared App Group UserDefaults.
        // The main Ping app writes the access + refresh tokens there on sign-in.
        // (See AppDelegate / PingApp for the write side — v2 enhancement: migrate to
        // a shared Keychain Access Group so the Supabase SDK can do this automatically.)
        let sharedDefaults = UserDefaults(suiteName: "group.com.v1.ping")
        let accessToken = sharedDefaults?.string(forKey: "supabase_access_token") ?? ""
        let refreshToken = sharedDefaults?.string(forKey: "supabase_refresh_token") ?? ""

        if !accessToken.isEmpty, !refreshToken.isEmpty {
            try? await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
        }

        guard let userId = client.auth.currentUser?.id else {
            showError("Open Ping and sign in first, then try again.")
            return
        }

        struct Payload: Encodable {
            let userId: UUID
            let name: String
            let howMet: String
            let linkedinUrl: String?
            let tags: [String]
            enum CodingKeys: String, CodingKey {
                case name, tags
                case userId      = "user_id"
                case howMet      = "how_met"
                case linkedinUrl = "linkedin_url"
            }
        }

        let payload = Payload(
            userId: userId,
            name: name,
            howMet: howMet,
            linkedinUrl: linkedinUrl,
            tags: []
        )

        do {
            try await client
                .from("contacts")
                .insert(payload)
                .execute()

            activityIndicator.stopAnimating()
            statusLabel.text = "Saved to Ping!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } catch {
            showError("Could not save: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        saveButton.isEnabled = true
        statusLabel.text = message
        statusLabel.textColor = UIColor.systemRed
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.dylan.ping.ShareExtension",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
        ))
    }

    // MARK: - Supabase Client

    /// Creates a Supabase client using keys from the extension's Info.plist.
    /// Returns nil if the URL is missing or malformed (e.g., build config not propagated).
    /// Auth session is restored separately via shared App Group UserDefaults.
    private func makeSupabaseClient() -> SupabaseClient? {
        let info = Bundle.main.infoDictionary ?? [:]
        let urlString = info["SUPABASE_URL"] as? String ?? ""
        let key = info["SUPABASE_ANON_KEY"] as? String ?? ""
        guard let url = URL(string: urlString), !urlString.isEmpty, !key.isEmpty else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1) // pingBackground

        // Navigation bar
        let navBar = UINavigationBar()
        let navItem = UINavigationItem(title: "Add to Ping")
        navItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel", style: .plain, target: self, action: #selector(cancel)
        )
        navItem.leftBarButtonItem?.tintColor = UIColor(red: 0.91, green: 0.52, blue: 0.35, alpha: 1)
        navBar.setItems([navItem], animated: false)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.barTintColor = UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        navBar.shadowImage = UIImage()
        view.addSubview(navBar)

        // Scroll + content
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Name field
        nameField.placeholder = "Name"
        nameField.font = UIFont.systemFont(ofSize: 16)
        nameField.backgroundColor = .white
        nameField.layer.cornerRadius = 10
        nameField.returnKeyType = .next
        nameField.delegate = self

        // howMet field
        howMetField.placeholder = "Where did you meet?"
        howMetField.font = UIFont.systemFont(ofSize: 16)
        howMetField.backgroundColor = .white
        howMetField.layer.cornerRadius = 10
        howMetField.returnKeyType = .done
        howMetField.delegate = self

        // Save button
        saveButton.setTitle("Save to Ping", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = UIColor(red: 0.91, green: 0.52, blue: 0.35, alpha: 1)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        // Activity indicator + status
        activityIndicator.hidesWhenStopped = true
        statusLabel.font = UIFont.systemFont(ofSize: 13)
        statusLabel.textColor = UIColor.systemGray
        statusLabel.textAlignment = .center

        let statusRow = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center

        [nameField, howMetField, saveButton, statusRow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),

            nameField.heightAnchor.constraint(equalToConstant: 48),
            howMetField.heightAnchor.constraint(equalToConstant: 48),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Helpers

    private func shake(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -4, 4, 0]
        animation.duration = 0.4
        view.layer.add(animation, forKey: "shake")
        view.layer.borderColor = UIColor.systemRed.cgColor
        view.layer.borderWidth = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            view.layer.borderWidth = 0
        }
    }
}

// MARK: - UITextFieldDelegate

extension ShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameField {
            howMetField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            saveTapped()
        }
        return true
    }
}

// MARK: - PaddedTextField

private class PaddedTextField: UITextField {
    private let inset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: inset) }
}
