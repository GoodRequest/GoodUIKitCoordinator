//
//  MessageComposer.swift
//  GoodUIKitCoordinator
//
//  Created by Marek Vríčan on 18/07/2025.
//

import UIKit
import MessageUI

@MainActor public final class MessageComposer: NSObject, Sendable {

    public struct MailModel {

        public let addresses: [String]
        public let subject: String
        public let message: String
        public let isHtml: Bool

        public init(addresses: [String], subject: String, message: String, isHtml: Bool) {
            self.addresses = addresses
            self.subject = subject
            self.message = message
            self.isHtml = isHtml
        }

    }

    public struct MessageModel {

        public let numbers: [String]
        public let message: String

        public init(numbers: [String], message: String) {
            self.numbers = numbers
            self.message = message
        }

    }

    static let shared = MessageComposer()

    private override init() {}

    func createMail(model: MailModel) -> MFMailComposeViewController? {
        if MFMailComposeViewController.canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setToRecipients(model.addresses)
            mailComposer.setSubject(model.subject)
            mailComposer.setMessageBody(model.message, isHTML: model.isHtml)

            return mailComposer
        } else {
            if let addresses = model.addresses.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let subject = model.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let message = model.message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let mailtoURL = URL(string: "mailto:\(addresses)&subject=\(subject)&body=\(message)"),
               UIApplication.shared.canOpenURL(mailtoURL) {

                UIApplication.shared.open(mailtoURL)
            }
        }
        return nil
    }

    func createSMS(model: MessageModel) -> MFMessageComposeViewController? {
        if MFMessageComposeViewController.canSendText() {
            let messageComposer = MFMessageComposeViewController()
            messageComposer.messageComposeDelegate = self
            messageComposer.recipients = model.numbers
            messageComposer.body = model.message

            return messageComposer
        }
        return nil
    }

}

extension MessageComposer: MFMailComposeViewControllerDelegate {

    nonisolated public func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            controller.dismiss(animated: true)
        }
    }

}

extension MessageComposer: MFMessageComposeViewControllerDelegate {

    nonisolated public func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        MainActor.assumeIsolated {
            controller.dismiss(animated: true)
        }
    }

}
