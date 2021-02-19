//
//  AuthenticationViewController.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/1/29.
//

import os.log
import UIKit
import Combine
import MastodonSDK
import UITextField_Shake

final class AuthenticationViewController: UIViewController, NeedsDependency {
    
    var disposeBag = Set<AnyCancellable>()
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    var viewModel: AuthenticationViewModel!
    
    let domainLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = Asset.Colors.Label.primary.color
        label.text = "Domain:"
        return label
    }()
    
    let domainTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "example.com"
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.keyboardType = .URL
        return textField
    }()
    
    let signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.setBackgroundImage(UIImage.placeholder(color: Asset.Colors.Background.secondarySystemBackground.color), for: .normal)
        button.setBackgroundImage(UIImage.placeholder(color: Asset.Colors.Background.secondarySystemBackground.color.withAlphaComponent(0.8)), for: .disabled)
        button.setTitleColor(Asset.Colors.Label.primary.color, for: .normal)
        button.setTitle("Sign in", for: .normal)
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        return button
    }()
    
    let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.setTitleColor(Asset.Colors.Button.highlight.color, for: .normal)
        button.setTitleColor(.systemGray, for: .disabled)
        button.setTitle("Sign up", for: .normal)
        return button
    }()
    
    let signInActivityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.hidesWhenStopped = true
        return activityIndicatorView
    }()
    
    let signUpActivityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.hidesWhenStopped = true
        return activityIndicatorView
    }()
}

extension AuthenticationViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Authentication"
        view.backgroundColor = Asset.Colors.Background.systemBackground.color
        
        domainLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(domainLabel)
        NSLayoutConstraint.activate([
            domainLabel.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 16),
            domainLabel.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            domainLabel.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
        ])
        
        domainTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(domainTextField)
        NSLayoutConstraint.activate([
            domainTextField.topAnchor.constraint(equalTo: domainLabel.bottomAnchor, constant: 8),
            domainTextField.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            domainTextField.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
        ])
        
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signInButton)
        NSLayoutConstraint.activate([
            signInButton.topAnchor.constraint(equalTo: domainTextField.bottomAnchor, constant: 20),
            signInButton.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            signInButton.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            signInButton.heightAnchor.constraint(equalToConstant: 44).priority(.defaultHigh),
        ])
        
        signInActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signInActivityIndicatorView)
        NSLayoutConstraint.activate([
            signInActivityIndicatorView.centerXAnchor.constraint(equalTo: signInButton.centerXAnchor),
            signInActivityIndicatorView.centerYAnchor.constraint(equalTo: signInButton.centerYAnchor),
        ])
        
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signUpButton)
        NSLayoutConstraint.activate([
            signUpButton.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 8),
            signUpButton.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            signUpButton.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            signUpButton.heightAnchor.constraint(equalToConstant: 44).priority(.defaultHigh),
        ])
        
        signUpActivityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(signUpActivityIndicatorView)
        NSLayoutConstraint.activate([
            signUpActivityIndicatorView.centerXAnchor.constraint(equalTo: signUpButton.centerXAnchor),
            signUpActivityIndicatorView.centerYAnchor.constraint(equalTo: signUpButton.centerYAnchor),
        ])
        
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: domainTextField)
            .compactMap { notification in
                guard let textField = notification.object as? UITextField? else { return nil }
                return textField?.text ?? ""
            }
            .assign(to: \.value, on: viewModel.input)
            .store(in: &disposeBag)
        
        viewModel.isAuthenticating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticating in
                guard let self = self else { return }
                isAuthenticating ? self.signInActivityIndicatorView.startAnimating() : self.signInActivityIndicatorView.stopAnimating()
                self.signInButton.setTitle(isAuthenticating ? "" : "Sign in", for: .normal)
            }
            .store(in: &disposeBag)
        
        viewModel.isRegistering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRegistering in
                guard let self = self else { return }
                isRegistering ? self.signUpActivityIndicatorView.startAnimating() : self.signUpActivityIndicatorView.stopAnimating()
                self.signUpButton.setTitle(isRegistering ? "" : "Sign up", for: .normal)
            }
            .store(in: &disposeBag)
        
        viewModel.isIdle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isIdle in
                guard let self = self else { return }
                self.signInButton.isEnabled = isIdle
                self.signUpButton.isEnabled = isIdle
            }
            .store(in: &disposeBag)
        
        
        viewModel.authenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] domain, user in
                guard let self = self else { return }
                // reset view hierarchy only if needs
                if self.viewModel.viewHierarchyShouldReset {
                    self.context.authenticationService.activeMastodonUser(domain: domain, userID: user.id)
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .failure(let error):
                                assertionFailure(error.localizedDescription)
                            case .success(let isActived):
                                assert(isActived)
                                self.coordinator.setup()
                            }
                        }
                        .store(in: &self.disposeBag)
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            }
            .store(in: &disposeBag)
        
        viewModel.error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self else { return }
                let alertController = UIAlertController(error, preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.coordinator.present(
                    scene: .alertController(alertController: alertController),
                    from: nil,
                    transition: .alertController(animated: true, completion: nil)
                )
            }
            .store(in: &disposeBag)
        
        signInButton.addTarget(self, action: #selector(AuthenticationViewController.signInButtonPressed(_:)), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(AuthenticationViewController.signUpButtonPressed(_:)), for: .touchUpInside)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        domainTextField.becomeFirstResponder()
    }
    
}

extension AuthenticationViewController {
 
    @objc private func signInButtonPressed(_ sender: UIButton) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        guard viewModel.isDomainValid.value, let domain = viewModel.domain.value else {
            domainTextField.shake()
            return
        }
        guard viewModel.isIdle.value else { return }
        viewModel.isAuthenticating.value = true
        context.apiService.createApplication(domain: domain)
            .tryMap { response -> AuthenticationViewModel.AuthenticateInfo in
                let application = response.value
                guard let info = AuthenticationViewModel.AuthenticateInfo(domain: domain, application: application) else {
                    throw APIService.APIError.explicit(.badResponse)
                }
                return info
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                // trigger state update
                self.viewModel.isAuthenticating.value = false
                
                switch completion {
                case .failure(let error):
                    os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: sign in fail: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    self.viewModel.error.value = error
                case .finished:
                    break
                }
            } receiveValue: { [weak self] info in
                guard let self = self else { return }
                let mastodonPinBasedAuthenticationViewModel = MastodonPinBasedAuthenticationViewModel(authenticateURL: info.authorizeURL)
                self.viewModel.authenticate(
                    info: info,
                    pinCodePublisher: mastodonPinBasedAuthenticationViewModel.pinCodePublisher
                )
                self.viewModel.mastodonPinBasedAuthenticationViewController = self.coordinator.present(
                    scene: .mastodonPinBasedAuthentication(viewModel: mastodonPinBasedAuthenticationViewModel),
                    from: nil,
                    transition: .modal(animated: true, completion: nil)
                )
            }
            .store(in: &disposeBag)
    }
    
    @objc private func signUpButtonPressed(_ sender: UIButton) {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
        guard viewModel.isDomainValid.value, let domain = viewModel.domain.value else {
            domainTextField.shake()
            return
        }
        guard viewModel.isIdle.value else { return }
        viewModel.isRegistering.value = true
        context.apiService.instance(domain: domain)
            .compactMap { [weak self] response -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Application>, Error>? in
                guard let self = self else { return nil }
                guard response.value.registrations != false else {
                    return Fail(error: AuthenticationViewModel.AuthenticationError.registrationClosed).eraseToAnyPublisher()
                }
                return self.context.apiService.createApplication(domain: domain)
            }
            .switchToLatest()
            .tryMap { response -> AuthenticationViewModel.AuthenticateInfo in
                let application = response.value
                guard let authenticateInfo = AuthenticationViewModel.AuthenticateInfo(domain: domain, application: application) else {
                    throw APIService.APIError.explicit(.badResponse)
                }
                return authenticateInfo
            }
            .compactMap { [weak self] authenticateInfo -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Token>, Error>? in
                guard let self = self else { return nil }
                return self.context.apiService.applicationAccessToken(domain: domain, clientID: authenticateInfo.clientID, clientSecret: authenticateInfo.clientSecret)
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.viewModel.isRegistering.value = false
                
                switch completion {
                case .failure(let error):
                    self.viewModel.error.send(error)
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                let mastodonRegisterViewModel = MastodonRegisterViewModel(domain: domain, applicationToken: response.value)
                self.coordinator.present(scene: .mastodonRegister(viewModel: mastodonRegisterViewModel), from: self, transition: .show)
            }
            .store(in: &disposeBag)
    }
    
}

// MARK: - UIAdaptivePresentationControllerDelegate
extension AuthenticationViewController: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .fullScreen
    }
}