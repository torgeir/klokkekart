//
//  Arrow.swift
//  mtbmap Watch App
//
//  Created by Torgeir Thoresen on 09/06/2024.
//

import Foundation
import SwiftUI

struct Arrow : Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        // bottom left
        path.move(to:    CGPoint(x: w/7,     y: h))
        // top middle
        path.addLine(to: CGPoint(x: w/2,     y: h - h/3.5))
        // bottom right
        path.addLine(to: CGPoint(x: w - w/7, y: h))
        // inset center
        path.addLine(to: CGPoint(x: w/2,     y: 0))
        // and back to the start
        path.closeSubpath()
        return path
    }
}

/// Using a DragGesture to move a view horizontally
/// see https://stackoverflow.com/questions/57020557/why-doesnt-this-swiftui-view-animate
struct DragGestureView: View {

    @GestureState var dragOffset = CGSize.zero
    @State var offset: CGFloat = 0

    var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { gesture in
                // keep the offset already moved without animation
                self.offset += gesture.translation.height
                withAnimation(Animation.easeOut(duration: 0.2)) {
                    self.offset += gesture.predictedEndTranslation.height - gesture.translation.height
                }
            }
    }

    var body: some View {
        VStack {
            ForEach(1 ..< 5) { _ in
                Color.red
                    .frame(minHeight: 20, maxHeight: 100)
            }
        }
        .offset(x: 0, y: offset + dragOffset.height)
        .gesture(dragGesture)
    }

}

struct DragGestureView_Previews: PreviewProvider {
    static var previews: some View {
        DragGestureView()
    }
}
