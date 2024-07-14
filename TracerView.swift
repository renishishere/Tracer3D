//
//  CubeManager.swift
//  awqward cal
//
//  Created by Renish Poudel on 4/24/24.
//
// Make a 3d Cube for swiftui views, heavy inspiration from: https://www.hackingwithswift.com/articles/135/how-to-render-uiviews-in-3d-using-catransformlayer
// Create the main view for managing objects in the space

import SwiftUI
import UIKit

public struct TracerUIView: UIViewRepresentable {
    
    @State public var objects: [TracerObject]
    
    @Binding var size: (length: CGFloat, width: CGFloat, height: CGFloat)
    @Binding public var scale: CGFloat
    @Binding public var angles: (x: CGFloat, y: CGFloat, z: CGFloat)
    
    private let adjustedSize: CGFloat = 0.90
    private let perspective: CGFloat = 500
    
    public init(objects: [TracerObject], size: Binding<(length: CGFloat, width: CGFloat, height: CGFloat)>, scale: Binding<CGFloat>, angles: Binding<(x: CGFloat, y: CGFloat, z: CGFloat)>) {

        self.objects = objects
        self._scale = scale
        self._angles = angles
        self._size = size
    }
    
    public func makeUIView(context: Context) -> UIView {
        let manager = context.coordinator
        return manager.createUIView()
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        let manager = context.coordinator
        manager.angles = angles
        manager.scale = scale
        
        manager.updateUIView(uiView)
    }
    
    public func makeCoordinator() -> TransformableUIViewManager {
        return TransformableUIViewManager(objects: objects, size: size, adjustedSize: adjustedSize, perspective: perspective, scale: scale)
    }
}

public struct TracerView: View {
    
    @State public var objects: [TracerObject]
    
    // Angle variables, delta is the last raw unmodified translational value
    @State private var angles: (x: CGFloat, y: CGFloat, z: CGFloat)
    // Angles are swiftUI 3D angles, delta are swiftUI 2D translational values
    @State private var deltaAngles: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0)

    // Scale and spin values, for having a nice globe effect
    @State private var scale: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var spinX: CGFloat = 0
    @State private var spinY: CGFloat = 0
    @State private var timer: Timer?

    // Gesture values to ensure gestures don't overlap
    @State private var isRotating = false
    @State private var isMagnifying = false
    
    @State var size: (length: CGFloat, width: CGFloat, height: CGFloat)

    // Static values
    let friction: CGFloat = 0.9
    let adjustedSize: CGFloat = 0.90
    let perspective: CGFloat = 500
    let sensitivity: CGFloat = 1.0
    let spinSensitivity: CGFloat = 1.0
    let minScale: CGFloat = 0.75
    let maxScale: CGFloat = 2.0
    
    public init(objects: [TracerObject], angles: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0), scale: CGFloat = 1, size: (length: CGFloat, width: CGFloat, height: CGFloat)) {
        self.objects = objects
        self.angles = angles
        self.scale = scale
        self.size = size
    }

    public var body: some View  {
        let trueWidth: CGFloat = (1 + adjustedSize) * size.width * scale
        let trueHeight: CGFloat = (1 + adjustedSize) * size.height * scale

        // Rotating object across x and y axes
        let dg = DragGesture()
        .onChanged { value in
                // Cancel timer for spin if we touch object again
                self.timer?.invalidate()

                let deltaX = value.translation.width
                let deltaY = value.translation.height

                // Update the angles with angle sensitivity
                self.angles.x = Angle(degrees: -(deltaY - self.deltaAngles.y) * sensitivity/scale).radians
                self.angles.y = Angle(degrees: ((deltaX - self.deltaAngles.x) * sensitivity/scale)).radians


                self.deltaAngles.x = deltaX
                self.deltaAngles.y = deltaY
            }
            .onEnded { value in
                self.deltaAngles.x = 0
                self.deltaAngles.y = 0


                spinX = -Angle(degrees: (value.predictedEndTranslation.height)*spinSensitivity/trueWidth).radians
                spinY = Angle(degrees: (value.predictedEndTranslation.width)*spinSensitivity/trueHeight).radians

                self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    self.angles.x = self.spinX
                    self.angles.y = self.spinY

                    self.spinX *= friction
                    self.spinY *= friction

                    if abs(self.spinX) < 0.001 && abs(self.spinY) < 0.001 {
                    self.timer?.invalidate()
                    }
                }
        }

        // Rotating the object
        let rg = RotateGesture(minimumAngleDelta: Angle(degrees: 10))
        .onChanged { value in
            if(!self.isMagnifying) {
                self.isRotating = true

                self.angles.z = value.rotation.radians + self.deltaAngles.z
            }
        }
        .onEnded { value in
            if(!self.isMagnifying) {
                self.deltaAngles.z = self.angles.z

                self.isRotating = false
            }
        }

        // Scaling the object
        let mg = MagnifyGesture(minimumScaleDelta: 0.05)
        .onChanged { value in
            if(!self.isRotating) {
                self.isMagnifying = true

                let newScale = lastScaleValue * value.magnification
                if newScale < minScale {
                    self.scale = minScale
                } else if newScale > maxScale {
                    self.scale = maxScale
                } else {
                    self.scale = newScale
                }
            }
        }
        .onEnded { _ in
            if(!self.isRotating) {
                self.lastScaleValue = self.scale

                self.isMagnifying = false
            }
        }
        .simultaneously(with: rg)

        TracerUIView(objects: objects, size: $size, scale: $scale, angles: $angles)
        .frame(width: trueWidth, height: trueHeight)
        .gesture(dg)
        .gesture(mg)
        .rotationEffect(Angle(radians: angles.z))
        .background(.pink)

        }
}

#if DEBUG
struct ContentView: View {
    @State var size: (length: CGFloat, width: CGFloat, height: CGFloat) = (length: 200, width: 200, height: 200)
    @State var angles: (x: CGFloat, y: CGFloat, z: CGFloat) = (x: 0.0, y: 0.0, z: 0.0)
    @State var scale: CGFloat = 1.0
    
    var body: some View {
        
        return TracerView(
            objects: [
                TracerObject(
                    faces: [
                        .top: AnyView(Color(.blue).onTapGesture {
                            print("hey")
                        }),
                        .back: AnyView(Color(.red)),
                        .bottom: AnyView(Color(.white)),
                        .front: AnyView(Color(.orange)),
                        .left: AnyView(Color(.purple)),
                        .right: AnyView(Color(.yellow))
                    ], transformMatrix: CubeTranformation(_:)
                ),
            ],
            angles: angles,
            scale: scale,
            size: size
        )
    }
}

#endif

#Preview {
    ContentView()
}
