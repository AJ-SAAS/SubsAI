import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let iconName: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .bold()
                    .foregroundColor(color)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        StatCard(title: "Subscribers", value: "1.2K", iconName: "person.fill", color: .blue)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
