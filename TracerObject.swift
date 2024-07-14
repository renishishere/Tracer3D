//
//  TracerObject.swift
//  awqward cal
//
//  Created by Renish Poudel on 5/12/24.
//

import SwiftUI
import UIKit

public protocol TracerFace: Hashable, CaseIterable {}

public enum CubeFace: TracerFace {
    case top, bottom, left, right, front, back
}

// Default matrix transformation for cube
public func CubeTranformation(_ size: (length: CGFloat, width: CGFloat, height: CGFloat)) -> [CubeFace: CATransform3D] {
    return [
        .front:  CATransform3DMakeTranslation(0, 0, size.width/2),
        .right: CATransform3DRotate(CATransform3DMakeTranslation(size.length/2, 0, 0), CGFloat.pi / 2, 0, 1, 0),
        .top: CATransform3DRotate(CATransform3DMakeTranslation(0, -size.height/2, 0), CGFloat.pi / 2, 1, 0, 0),
        .bottom: CATransform3DRotate(CATransform3DMakeTranslation(0, size.height/2, 0), -CGFloat.pi / 2, 1, 0, 0),
        .left: CATransform3DRotate(CATransform3DMakeTranslation(-size.length/2, 0, 0), -CGFloat.pi / 2, 0, 1, 0),
        .back: CATransform3DRotate(CATransform3DMakeTranslation(0, 0, -size.width/2), CGFloat.pi, 0, 1, 0)
    ]
}

public struct TransformableData {
    let position: CATransform3D
    let angle: CATransform3D
}

// Class to manage the UIView
public class TransformableUIViewManager: NSObject {
    
    struct faceOrderKeeper {
        var face: AnyHashable
        var parent: Int
    }
    
    // Each of the faces for this view
    var faces: [[AnyHashable: AnyView]]
    // The order of the faces, because the elements are accessed in order
    var faceOrders: [faceOrderKeeper]
    var data: [TransformableData]
    
    // 3D transformation variables
    var angles: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0)
    var size: (length: CGFloat, width: CGFloat, height: CGFloat)
    var scale: CGFloat = 1.0
    let adjustedSize: CGFloat
    let perspective: CGFloat
    
    // Initial tranformation variables
    var transforms: [[AnyHashable: CATransform3D]]
    var cumulativeTransform = CATransform3DIdentity
    
    init(objects: [TracerObject], size: (length: CGFloat, width: CGFloat, height: CGFloat), adjustedSize: CGFloat, perspective: CGFloat, scale: CGFloat) {
        self.size = size
        self.adjustedSize = adjustedSize
        self.perspective = perspective
        self.scale = scale
        
        self.faces = []
        self.faceOrders = []
        self.transforms = []
        self.data = []
        
        for (index, object) in objects.enumerated() {
            self.faces.append(object.faces)
            // Memorize the order of faces because faces is dictionary that does not keep order, but the created views are accessed in order of creation
            self.faceOrders.append(contentsOf: object.faces.map { faceOrderKeeper(face: $0.key, parent: index) })
            self.transforms.append(object.transforms(size))
            self.data.append(object.data)
        }
                        
        super.init()
    }
    
    func createUIView() -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        
        // Create perspective view
        var perspectiveTransform = CATransform3DIdentity
        perspectiveTransform.m34 = -1.0 / self.perspective
        container.layer.sublayerTransform = perspectiveTransform
                
        for object in self.faceOrders {
            
            // Width and height of the faces are adjusted to given values
            self.faces[object.parent][object.face] = AnyView(self.faces[object.parent][object.face].frame(width: self.size.width, height: self.size.height))
            let hostingController = UIHostingController(rootView: self.faces[object.parent][object.face])
                hostingController.view.frame = CGRect(
                    x: (self.size.width * self.adjustedSize) / 2,
                    y: (self.size.height * self.adjustedSize) / 2,
                    width: self.size.width,
                    height: self.size.height
                )
                hostingController.view.backgroundColor = .clear
                
                // There should be a value for every face in transform
            guard let transform = self.transforms[object.parent][object.face] else {
                print(index, object)
                print(faceOrders)
                fatalError("Tranformations matrix should be exhaustive for all faces, transformation not found for faces \(object.face)")
                }
                
                hostingController.view.layer.transform = transform
                container.addSubview(hostingController.view)
            }
        
        
        return container
    }
    
    
    // TODO: update size when size value is updated
    
    func updateUIView(_ uiView: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true) // Disable implicit animations
        
        let rotationX = CATransform3DMakeRotation(angles.x, 1, 0, 0)
        let rotationY = CATransform3DMakeRotation(angles.y, 0, 1, 0)
        
        let scaleTransform = CATransform3DMakeScale(scale, scale, scale)
        
        cumulativeTransform = CATransform3DConcat(cumulativeTransform, CATransform3DConcat(rotationX, rotationY))
        
        uiView.layer.sublayers?.enumerated().forEach({ index, layer in
            let object = self.faceOrders[index]
            let data = self.data[object.parent]
            
            // There should be a value for every face in transform
            guard let transform = self.transforms[object.parent][object.face] else {
                fatalError("Tranformations matrix should be exhaustive for all faces, transformation not found for faces \(object.face)")
            }
            
            layer.transform = CATransform3DConcat(transform, CATransform3DConcat( data.angle, cumulativeTransform))
            layer.transform = CATransform3DConcat(layer.transform, data.position)
            layer.transform = CATransform3DConcat(layer.transform, scaleTransform)
            
            // Adjust frame only if necessary or in a more controlled manner
            layer.frame = CGRect(x: size.width/2*(scale*(adjustedSize+1)-1), y: size.height/2*(scale*(adjustedSize+1)-1), width: size.width, height: size.height)
        })
        
        CATransaction.commit()
    }
}

// TracerObject structure keeps track of variables local to a 3D object
public struct TracerObject {
    public var faces: [AnyHashable: AnyView]
    
    /*
     Scale and Angle variables have been remove, because implmentation of 3D roation of singular object is not yet supported
     
    @Binding public var scale: CGFloat
    @Binding public var angles: (x: CGFloat, y: CGFloat, z: CGFloat)
     */
    public let data: TransformableData
    public let transforms: (_ size: (length: CGFloat, width: CGFloat, height: CGFloat)) -> [AnyHashable: CATransform3D]
    
    public init<Face: TracerFace>(faces: [Face: AnyView], transformMatrix transforms: @escaping (_ size: (length: CGFloat, width: CGFloat, height: CGFloat)) -> [Face: CATransform3D], position: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0), angle: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 0, 0)
                                  /*,scale: Binding<CGFloat>, angles: Binding<(x: CGFloat, y: CGFloat, z: CGFloat)>*/
    ) {
        self.faces = faces
        self.transforms = transforms
        self.data = TransformableData(
            position: CATransform3DMakeTranslation(position.x, position.y, position.z),
            angle: CATransform3DConcat(CATransform3DConcat(CATransform3DMakeRotation(Angle(degrees: angle.x).radians, 1.0, 0.0, 0.0), CATransform3DMakeRotation(Angle(degrees: angle.y).radians, 0.0, 1.0, 0.0)), CATransform3DMakeRotation(Angle(degrees: angle.z).radians, 0.0, 0.0, 1.0))
        )
        
        /*
        self._scale = scale
        self._angles = angles
        */
    }
}
