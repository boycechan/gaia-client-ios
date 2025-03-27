//
//  © 2020 - 2022 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation

/*
 Generics based notifications that allow strict typing of reason and payloads.
 The notifications are sent by boxing up into (NS)Notifications userInfo.
 */

public protocol GaiaNotificationSender {

}

public protocol GaiaNotification {
    // associatedtype is generics magic. The actual type is determined
    // in concrete classes that implement this protocol.
    associatedtype ReasonType
    associatedtype PayloadType

    var sender: GaiaNotificationSender {get}
    var payload: PayloadType {get}
    var reason: ReasonType {get}

    // Implemented by concrete classes.
    static var name: Notification.Name {get}
}

extension GaiaNotification {
    static var packedKey: String {
        return "BoxedValue"
    }

    static func unpack(notification: Notification) -> Self? {
        return notification.userInfo?[Self.packedKey] as? Self
    }

    func packedNotification() -> Notification {
        let userInfo = [Self.packedKey: self]
        return Notification(name: Self.name, object: sender, userInfo: userInfo)
    }
}

/*
 Extension to Notification Center providing support for generic notifications.
 API signatures closely follow those defined in Foundation APIs
 */
public extension NotificationCenter {
    func post<NotificationType: GaiaNotification> (_ notification: NotificationType) {
        post(notification.packedNotification())
    }

    func addObserver<NotificationType: GaiaNotification>(forType: NotificationType.Type,
                                                         object: GaiaNotificationSender?,
                                                         queue: OperationQueue?,
                                                         using block: @escaping (NotificationType) -> Void) -> ObserverToken {

        return ObserverToken(notificationCenter: self,
                             token: addObserver(forName: NotificationType.name,
                                                object: object,
                                                queue: queue,
                                                using: { notification in
                                                    if let typed = NotificationType.unpack(notification: notification) {
                                                        block(typed)
                                                    }
                             }))
    }

    func removeObserver(_ observer: ObserverToken) {
        removeObserver(observer.token)
    }
}

/*
 Although target-selector based notification observers no longer need to be manually removed. It is not clear
 if that is also the case for block based observers. This class is used to manage those observers through its
 deinit method
 */
public class ObserverToken {
    let token: NSObjectProtocol
    let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter, token: NSObjectProtocol) {
        self.token = token
        self.notificationCenter = notificationCenter
    }

    deinit {
        notificationCenter.removeObserver(self)
    }
}
