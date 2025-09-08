import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text("\(value.formatted())")
                    .bold()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#if DEBUG
struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        StatCard(title: "Views", value: 5000, icon: "eye.fill")
    }
}
#endif
