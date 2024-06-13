//
//  SettingsTermsOfUse.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 12/06/2024.
//

import Foundation
import SwiftUI

struct P: View {
    var text: String
    init(_ text: String) {
        self.text = text
    }
    var body: some View {
        Text(.init(text))
            .lineLimit(nil)
            .font(.caption2)
            .fixedSize(horizontal: false, vertical: true)
        
    }
}

struct SettingTermsOfUse : View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    P("🇳🇴")
                        .padding(.horizontal)
                    P("Bruk applikasjonen på eget ansvar. Det kan forekomme feil og mangler, og posisjonen som blir vist kan være unøyaktig sammenlignet med virkeligheten. Gjør egne vurderinger for hvor, når og hvordan du ferdes i fjellet, og vær oppmerksom på at kart ikke alltid stemmer med terrenget.")
                        .padding(.trailing)
                        .padding(.horizontal)
                    
                    P("Kartene er levert slik de er, uten modifikasjoner, fra © Kartverket sine WMTS-tjenester (www.kartverket.no/api-og-data/vilkar-for-bruk). Det gis ingen garantier for at kartet til en hver tid reflekterer virkeligheten. Hverken Kartverket, denne applikasjonen, eller applikasjonens utvikler kan gi garantier for at informasjonen som blir presentert er korrekt, og kan ikke ta ansvar for at data kan være feil eller villedende.")
                        .padding(.all)
                    
                    P("Les mer om kartgrunnlaget på www.kartverket.no")
                        .padding(.all)

                    P("God tur! Og husk fjellvettreglene.no!")
                        .padding(.all)

                    Spacer()
                    
                    P("🇬🇧🇺🇸")
                        .padding(.horizontal)
                    P("Use the application at your own risk. Errors and omissions may occur, and the position displayed may be inaccurate compared to reality. Make your own assessments of where, when, and how you travel in the mountains, and be aware that maps do not always match the terrain.")
                        .padding(.trailing)
                        .padding(.horizontal)

                    P("The maps are provided as they are, without modifications, from © Kartverket WMTS services (www.kartverket.no/api-og-data/vilkar-for-bruk). There are no guarantees that the map will always reflect reality. Neither Kartverket, this application, nor the application's developer can guarantee that the information presented is correct, and cannot be held responsible for data that may be incorrect or misleading.")
                        .padding(.all)
                    
                    P("Read more about the map data at www.kartverket.no")
                        .padding(.all)
                    
                    P("Have a good trip! And remember fjellvettreglene.no!")
                        .padding(.all)
                }
            }
        }.navigationTitle("Terms of Use")
    }
}


#Preview {
    SettingTermsOfUse()
}
