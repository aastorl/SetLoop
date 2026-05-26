import SwiftUI

extension ApplicationStatus {
    var tint: Color {
        switch self {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .withdrawn:
            return .secondary
        }
    }
}
