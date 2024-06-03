//
//  MailInboxRouter.swift
//  GoodUIKitCoordinator
//
//  Created by Marek Vríčan on 18/07/2025.
//

import UIKit

@MainActor public struct MailInboxRouter {

    // MARK: - Models

    struct MailClient {

        let name: String
        let url: URL

    }

    // MARK: - Enums

    public enum SelectionKind {

        case automatic(completion: (() -> Void)? = nil)
        case manual(title: String, cancel: String, completion: (() -> Void)? = nil)

        var isAutomatic: Bool {
            switch self {
            case .automatic: true
            default: false
            }
        }

        var completionHandler: (() -> Void)? {
            switch self {
            case .automatic(let completion), .manual(_, _, let completion): completion
            }
        }

    }

    // MARK: - Properties

    static let clients = [
        "Gmail": "googlegmail://",
        "Spark": "readdle-spark://",
        "Airmail": "airmail://",
        "Outlook": "ms-outlook://",
        "Yahoo": "ymail://",
        "Mail": "message://"
    ]

}

// MARK: - Private

private extension MailInboxRouter {

    static func availableMailClients(completion: (() -> Void)?) -> [MailClient] {
        clients.compactMap { client -> MailClient? in
            guard let clientURL = URL(string: client.value), UIApplication.shared.canOpenURL(clientURL)
            else { return nil }

            return MailClient(name: client.key, url: clientURL)
        }
    }

    static func openUrl(_ url: URL, completion: (() -> Void)? = nil) {
        UIApplication.shared.open(url)
        completion?()
    }

}

// MARK: - Public

extension MailInboxRouter {

    static func openMailInbox(selection: SelectionKind) -> UIAlertController? {
        let availableMailClients = availableMailClients(completion: { selection.completionHandler?() })

        guard !availableMailClients.isEmpty else {
            selection.completionHandler?()
            return .none
        }

        switch selection {
        case .automatic(let completion):
            guard let firstAvailableClient = availableMailClients.first else { return .none }

            openUrl(firstAvailableClient.url, completion: completion)

            return .none

        case .manual(let title, let cancel, let completion):
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            availableMailClients.forEach { client in
                let action = UIAlertAction(
                    title: client.name,
                    style: .default,
                    handler: { _ in openUrl(client.url, completion: completion) }
                )
                alertController.addAction(action)
            }

            let cancelAction = UIAlertAction(
                title: cancel,
                style: .destructive,
                handler: { _ in completion?() }
            )
            alertController.addAction(cancelAction)

            return alertController
        }
    }

}
