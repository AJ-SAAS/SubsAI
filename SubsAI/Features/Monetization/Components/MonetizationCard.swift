import SwiftUI

struct MonetizationCard: View {
    let title: String
    let subtitle: String
    let current: Int
    let required: Int
    let unit: String
    
    var progress: Double {
        min(Double(current) / Double(required), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(current.formatted()) / \(required.formatted()) \(unit)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 30, height: 100)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(progress >= 1.0 ? .green : .blue)
                    .frame(width: 30, height: CGFloat(100 * progress))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonetizationCard_Previews: PreviewProvider {
    static var previews: some View {
        MonetizationCard(title: "Subscribers", subtitle: "All Time", current: 1230, required: 1000, unit: "subs")
    }
}
