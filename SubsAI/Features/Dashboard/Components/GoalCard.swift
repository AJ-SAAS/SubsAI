import SwiftUI

struct GoalCard: View {
    let title: String
    let current: Int
    let goal: Int
    
    var progress: Double {
        min(Double(current) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(current.formatted())")
                    .bold()
                Text(" / \(goal.formatted())")
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalCard_Previews: PreviewProvider {
    static var previews: some View {
        GoalCard(title: "Subscribers", current: 1230, goal: 10000)
    }
}
