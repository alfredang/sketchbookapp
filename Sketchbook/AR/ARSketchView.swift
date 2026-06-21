import SwiftUI
import RealityKit
import ARKit

/// Renders the flattened sketch as a textured plane you can place on a detected
/// surface in the real world. Tap to drop the artwork onto a horizontal surface.
struct ARSketchView: UIViewRepresentable {
    let image: UIImage
    /// Physical width of the placed artwork, in metres.
    var physicalWidth: Float = 0.4

    func makeCoordinator() -> Coordinator { Coordinator(image: image, physicalWidth: physicalWidth) }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        #if !targetEnvironment(simulator)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        #endif
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        context.coordinator.placeInFrontOfCamera() // initial preview anchor
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    final class Coordinator: NSObject {
        weak var arView: ARView?
        let image: UIImage
        let physicalWidth: Float

        init(image: UIImage, physicalWidth: Float) {
            self.image = image
            self.physicalWidth = physicalWidth
        }

        private func makeSketchEntity() -> ModelEntity? {
            guard let cg = image.cgImage,
                  let texture = try? TextureResource.generate(
                    from: cg, options: .init(semantic: .color)) else { return nil }
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: 1.0)

            let aspect = Float(image.size.height / max(image.size.width, 1))
            let mesh = MeshResource.generatePlane(width: physicalWidth,
                                                  height: physicalWidth * aspect)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            return entity
        }

        /// Shows the artwork floating ~0.5 m in front of the camera as a preview.
        func placeInFrontOfCamera() {
            guard let arView, let entity = makeSketchEntity() else { return }
            let anchor = AnchorEntity(.camera)
            entity.position = [0, 0, -0.6]
            anchor.addChild(entity)
            arView.scene.anchors.append(anchor)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, let entity = makeSketchEntity() else { return }
            let location = gesture.location(in: arView)
            #if !targetEnvironment(simulator)
            if let result = arView.raycast(from: location,
                                           allowing: .estimatedPlane,
                                           alignment: .any).first {
                let anchor = AnchorEntity(world: result.worldTransform)
                entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]) // lay flat
                anchor.addChild(entity)
                arView.scene.anchors.append(anchor)
                return
            }
            #endif
            placeInFrontOfCamera()
        }
    }
}
