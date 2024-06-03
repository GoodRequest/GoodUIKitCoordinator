// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import UIKit
import SafariServices

// MARK: - StepAction

public enum StepAction {

    // Navigation
    case push(UIViewController)
    case pushWithCompletion(UIViewController, @MainActor () -> ())
    case pop
    case popTo(UIViewController)
    case popToRoot

    // Modal
    case present(UIViewController, UIModalPresentationStyle = .automatic, UIViewControllerTransitioningDelegate? = nil)
    case dismiss
    case dismissWithCompletion(@MainActor () -> ())

    // Automatic
    /// Pop or dismiss automatically
    case close
    case set([UIViewController])

    // Links
    case safari(URL, UIModalPresentationStyle = .automatic, tintColor: UIColor? = nil)
    case universalLink(url: URL, onlyOpenWhenTargetAppIsAvailable: Bool = false, completion: (@MainActor (Bool) -> ())? = nil)

    // Actions
    case call(String)
    case sms(messageModel: MessageComposer.MessageModel, onError: @MainActor () -> ())
    case mail(mailModel: MessageComposer.MailModel, onError: @MainActor () -> ())
    case mailInbox(selection: MailInboxRouter.SelectionKind = .automatic())

    // System apps
    case openSettings
    case openMessages
    case none

    public var isModalAction: Bool {
        switch self {
        case .present, .dismiss, .dismissWithCompletion, .safari, .universalLink, .call, .sms, .mail, .mailInbox, .openSettings, .openMessages, .close:
            return true

        default:
            return false
        }
    }

    public var isNavigationAction: Bool {
        switch self {
        case .push, .pushWithCompletion, .pop, .popTo, .set, .popToRoot, .close:
            return true

        default:
            return false
        }
    }

}

///GoodCoordinator is used for managing navigation flow and data flow between different parts of an app.
///It is a generic class that takes a Step type as its generic parameter.
@available(iOS 13.0, *)
open class GoodCoordinator<Step>: NSObject, Coordinator {

    open var cancellables: Set<AnyCancellable> = Set()

    open var children = NSPointerArray.weakObjects()

    open var parentCoordinator: Coordinator?

    @Published open var step: Step?

    open weak var rootViewController: UIViewController?

    // MARK: - Initialization

    /// Initializes a GoodCoordinator with a given root view controller and an optional parent coordinator. If a parent coordinator is provided, the current instance is automatically added to the parent’s children collection.
    /// - Parameters:
    ///   - rootViewController: The root view controller managed by this coordinator. Default value is nil.
    ///   - parentCoordinator: The parent coordinator of this coordinator. Default value is nil.
    public required init(rootViewController: UIViewController? = nil) {
        super.init()

        self.rootViewController = rootViewController
    }

    /// A convenience initializer that initializes a GoodCoordinator with a root view controller derived from the provided parent coordinator.
    /// - Parameter parentCoordinator: The parent coordinator to which this coordinator will belong.
    public required init(parentCoordinator: Coordinator?) {
        super.init()

        self.parentCoordinator = parentCoordinator
        self.rootViewController = parentCoordinator?.rootViewController
        self.parentCoordinator?.children.addObject(self)
    }

    // MARK: - Overridable

    @discardableResult
    open func navigate(to stepper: Step) -> StepAction {
        return .none
    }

    // MARK: - Navigation

    @discardableResult
    open func start() -> UIViewController? {
        startHeadless()

        return rootViewController
    }

    @discardableResult
    public final func startHeadless() -> Self {
        $step
            .compactMap { $0 }
            .sink { [weak self] in
                guard let `self` = self else { return }
                self.navigate(action: self.navigate(to: $0))
            }.store(in: &cancellables)

        return self
    }

    private func navigate(action: StepAction) {
        do {
            if action.isModalAction == true {
                try handleModalAction(action)
            } else if action.isNavigationAction == true {
                try handleFlowAction(action)
            } else {
                print("⛔️ Navigation action failed: neither isModalAction nor isNavigationAction is specified")
            }
        } catch(let error) {
            print("⛔️ Navigation action failed: \(error.localizedDescription)")
        }
    }

    public func perform(step: Step) {
        self.step = step
    }

    // MARK: - Navigation - Static

    public static func execute<S, C: GoodCoordinator<S>>(
        step: S,
        on coordinator: C.Type,
        from parent: Coordinator
    ) {
        guard Thread.isMainThread else {
            print("⚠️ Attempted to execute UI navigation from background thread! Switching to main...")
            return DispatchQueue.main.async { Self.execute(step: step, on: coordinator, from: parent) }
        }

        if let coordinator = parent.lastChildOfType(type: coordinator) {
            coordinator.perform(step: step)
        } else {
            parent.resetChildReferences()

            let coordinator = coordinator.init(parentCoordinator: parent)
            coordinator.startHeadless().perform(step: step)
        }
    }

}

// MARK: - Action Handling

private extension GoodCoordinator {

    // MARK: - Modal actions

    func handleModalAction(_ action: StepAction) throws {
        guard let viewController = rootViewController else {
            throw CoordinatorError.missingRoot(description: "Coordinator without root view controller")
        }

        switch action {
        case .close:
            do {
                try handleFlowAction(.pop)
            } catch {
                fallthrough
            }

        case .dismiss:
            var topController = viewController
            while let newTopController = topController.presentedViewController {
                topController = newTopController
            }

            topController.dismiss(animated: true)

        case .dismissWithCompletion(let completion):
            var topController = viewController
            while let newTopController = topController.presentedViewController {
                topController = newTopController
            }

            topController.dismiss(animated: true, completion: completion)

        case .present(let controller, let style, let transitionDelegate):
            present(
                transitionDelegate: transitionDelegate,
                controller: controller,
                style: style,
                viewController: viewController
            )

        case .safari(let url, let style, let tintColor):
            let safariViewController = SFSafariViewController(url: url)
            safariViewController.preferredControlTintColor = tintColor
            safariViewController.modalPresentationStyle = style

            present(
                transitionDelegate: nil,
                controller: safariViewController,
                style: style,
                viewController: viewController
            )

        case .universalLink(let url, let universalOnly, let completion):
            UIApplication.shared.open(url, options: [.universalLinksOnly : universalOnly], completionHandler: completion)

        case .call(let number):
            if let telprompt = URL(string: "telprompt://\(number.components(separatedBy: .whitespacesAndNewlines).joined())") {
                UIApplication.shared.open(telprompt)
            }

        case .sms(let model, let onError):
            sms(model: model, viewController: viewController, onError: onError)

        case .mail(let model, let onError):
            mail(model: model, viewController: viewController, onError: onError)

        case .mailInbox(let selection):
            mailInbox(selection: selection)

        case .openSettings:
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }

        case .openMessages:
            if let messagesUrl = URL(string: "sms://open?message-guid=0") {
                UIApplication.shared.open(messagesUrl)
            }

        default:
            break
        }
    }

    func present(
        transitionDelegate: UIViewControllerTransitioningDelegate?,
        controller: UIViewController,
        style: UIModalPresentationStyle,
        viewController: UIViewController
    ) {
        if let transitionDelegate = transitionDelegate {
            controller.transitioningDelegate = transitionDelegate
        }
        controller.modalPresentationStyle = style

        var topController = viewController
        while let newTopController = topController.presentedViewController {
            topController = newTopController
        }

        topController.present(controller, animated: true, completion: nil)
    }

    func sms(model: MessageComposer.MessageModel, viewController: UIViewController, onError: () -> Void) {
        if let messageComposeViewController = MessageComposer.shared.createSMS(model: model) {
            viewController.present(messageComposeViewController, animated: true, completion: nil)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            onError()
        }
    }

    func mail(model: MessageComposer.MailModel, viewController: UIViewController, onError: () -> Void) {
        if let mailComposeViewController = MessageComposer.shared.createMail(model: model) {
            viewController.present(mailComposeViewController, animated: true, completion: nil)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            onError()
        }
    }

    func mailInbox(selection: MailInboxRouter.SelectionKind) {
        guard let alertController = MailInboxRouter.openMailInbox(selection: selection) else { return }

        rootViewController?.present(alertController, animated: true)
    }

}

private extension Coordinator {

    // MARK: - Flow actions

    func handleFlowAction(_ action: StepAction) throws {
        guard let navigationController = rootNavigationController else {
            throw CoordinatorError.missingRoot(description: "Coordinator without navigation view controller")
        }

        switch action {
        case .push(let controller):
            navigationController.pushViewController(controller, animated: true)

        case .pushWithCompletion(let controller, let completion):
            navigationController.pushViewController(controller, animated: true)

            guard let coordinator = navigationController.transitionCoordinator else {
                completion()
                return
            }

            coordinator.animate(alongsideTransition: nil) { _ in completion() }

        case .pop:
            navigationController.popViewController(animated: true)

        case .popTo(let controller):
            navigationController.popToViewController(controller, animated: true)

        case .popToRoot:
            navigationController.popToRootViewController(animated: true)

        case .set(let controllers):
            navigationController.setViewControllers(controllers, animated: true)

        default:
            break
        }
    }

}

// MARK: - CoordinatorError

enum CoordinatorError: Error {

    case missingRoot(description: String)

}
