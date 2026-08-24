import Foundation
import SwiftData
import Observation

@Observable
package final class UserSession {
    package var currentUser: User?

    package init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }
}
