//
//  KlokkekartWidget.swift
//  KlokkekartWidget
//
//  Created by Torgeir Thoresen on 14/06/2024.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let after = 
            Calendar.current.date(
                byAdding: .minute, value: 15, to: currentDate)!
        
        let entry =
            SimpleEntry(date: currentDate, configuration: configuration)
        
        return Timeline(entries: [entry], policy: .after(after))
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        // Create an array with all the preconfigured widgets to show.
        [AppIntentRecommendation(
            intent: .location,
            description: "Show map")]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct KlokkekartWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Image(systemName: entry.configuration.icon)
            .font(.system(size: 20.0))
            .padding()
            .labelStyle(.iconOnly)
            .foregroundColor(.red)
            .clipShape(Circle())
            .scaleEffect(1.4, anchor: .center)
        }
    }
}

@main
struct KlokkekartWidget: Widget {
    let kind: String = "KlokkekartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            KlokkekartWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var location: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.icon = "location"
        return intent
    }
    
}

#Preview(as: .accessoryInline) {
    KlokkekartWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .location)
}
