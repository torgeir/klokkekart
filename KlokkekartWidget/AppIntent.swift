//
//  AppIntent.swift
//  KlokkekartWidget
//
//  Created by Torgeir Thoresen on 14/06/2024.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Open the Klokkekart app")

    // An example configurable parameter.
    @Parameter(title: "icon", default: "location")
    var icon: String
}
