import SceneKit

class Projectile : Entity {
    
    init(origin: SCNVector3, target: SCNVector3, colour: UIColor) {
        let projectileShape = SCNSphere(radius: 0.05)
        projectileShape.firstMaterial!.diffuse.contents = colour
        projectileShape.firstMaterial!.specular.contents = UIColor.white
        let node = SCNNode(geometry: projectileShape)
        node.position = origin
        let bitMask = Projectile.bitMask
        super.init(node, isMobile: true, mass: 0.1, isAffectedByGravity: false, isTemporary: true, physicsBody: SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: projectileShape, options: nil)), collisionBitMask: bitMask, contactBitMask: EnemyShip.bitMask)
        self.minZDist = 0.0
        self.speed = 7.5
        self.target = target
    }

    // Bit Masks
    public static let bitMask = 2
    
    // Range
    public static let start: Float = 0.5
    public static let end: Float = 30.0
    
}
