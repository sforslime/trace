import SwiftUI

struct FollowGuidancePill: View {
    let guidance: FollowGuidance

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 32, height: 32)
                .background(Circle().fill(.tint))
            VStack(alignment: .leading, spacing: 0) {
                Text(guidance.instruction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(distanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var icon: some View {
        let systemName: String
        let rotation: Angle
        switch guidance.direction {
        case .arrived:
            systemName = "flag.checkered"
            rotation = .zero
        case .straightAhead:
            systemName = "arrow.up"
            rotation = .zero
        case .bearLeft:
            systemName = "arrow.up"
            rotation = .degrees(-30)
        case .bearRight:
            systemName = "arrow.up"
            rotation = .degrees(30)
        case .turnLeft:
            systemName = "arrow.up"
            rotation = .degrees(-80)
        case .turnRight:
            systemName = "arrow.up"
            rotation = .degrees(80)
        case .turnAround:
            systemName = "arrow.uturn.down"
            rotation = .zero
        case .headTo:
            systemName = "location.north.fill"
            rotation = .degrees(guidance.absoluteBearingDegrees)
        }
        return Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .rotationEffect(rotation)
    }

    private var distanceText: String {
        if guidance.direction == .arrived { return "Trail complete" }
        let d = guidance.distanceMeters
        if d < 1000 {
            return String(format: "%.0f m to next turn", d)
        }
        return String(format: "%.2f km to next turn", d / 1000)
    }
}
