import WidgetKit
import SwiftUI

struct FlowEntry: TimelineEntry { let date: Date }
struct FlowTimeline: TimelineProvider {
    func placeholder(in context: Context) -> FlowEntry { FlowEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (FlowEntry) -> Void) { completion(FlowEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowEntry>) -> Void) {
        completion(Timeline(entries: [FlowEntry(date: Date())], policy: .never))
    }
}
struct FlowWidgetView: View {
    let entry: FlowEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flow").font(.title2.bold())
            Text("What can I help with?").font(.headline)
            HStack {
                Link(destination: URL(string: "flow://widget/ask")!) { Label("Ask Flow", systemImage: "bubble.left") }
                Spacer()
                Link(destination: URL(string: "flow://widget/voice")!) { Label("Voice", systemImage: "mic") }
            }.font(.subheadline)
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { LinearGradient(colors: [Color(red: 0.02, green: 0.23, blue: 0.32), Color(red: 0.03, green: 0.43, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    }
}
@main
struct FlowWidget: Widget {
    let kind = "FlowWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowTimeline()) { entry in FlowWidgetView(entry: entry) }
            .configurationDisplayName("Flow")
            .description("Access Flow faster directly from your Home Screen.")
            .supportedFamilies([.systemMedium])
    }
}
