import UIKit
import SceneKit
import SpriteKit
import ARKit
import AVFoundation
import FirebaseDatabase
import FBSDKCoreKit
import FBSDKLoginKit

var score = 0
var userID = ""
var userName = ""
var userHighScore = 0
var arr = [NSDictionary]()

class ViewController: UIViewController, SCNPhysicsContactDelegate, ARSCNViewDelegate {
    
    @IBOutlet weak var logoutBtn: UIButton!
    @IBOutlet weak var loginBtn: UIButton!
    @IBAction func ClickLogout(_ sender: Any) {
        userID = ""
        userName = ""
        score = 0
        userHighScore = 0
        
        UserDefaults.standard.set("", forKey: "userID")
        
        UserDefaults.standard.set("", forKey: "userName")
        AlertLoginBtn.isHidden  = false
        LabelName.text          = ""
        loginBtn.isHidden       = false
        logoutBtn.isHidden      = true
    }
    @IBOutlet weak var AlertLoginBtn: UIButton!
    @IBOutlet weak var LabelName: UILabel!
    var ref: DatabaseReference!
    var spriteScene: OverlayScene!
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBAction func swipeUpGesture(_ sender: UISwipeGestureRecognizer) {
        let (direction, position) = getCameraVector()
        let start = Projectile.start
        let end = Projectile.end
        let origin = SCNVector3(position.x + direction.x * start, position.y + direction.y * start, position.z + direction.z * start)
        let target = SCNVector3(position.x + direction.x * end, position.y + direction.y * end, position.z + direction.z * end)
        addEntity(Projectile(origin: origin, target: target, colour: UIColor.red))
    }
//    @IBAction func loginWithFacebook(_ sender: UIButton) {
//        let loginManager = LoginManager()
//        loginManager.logIn(readPermissions: [.publicProfile,.email,.userFriends], viewController: self) { (loginResult) in
//            switch loginResult{
//            case .failed(let error):
//                print(error)
//            //失敗的時候回傳
//            case .cancelled:
//                print("the user cancels login")
//            //取消時回傳內容
//            case .success(grantedPermissions: _, declinedPermissions: _, token: _):
//                self.getDetails()
//                print("user log in")
//                //成功時print("user log in")
//            }
//        }
//    }
    
    public func addEntity(_ entity: Entity) {
        entity.setID(entityCounter)
        pendingEntities.append(entity)
        entityCounter = entityCounter &+ 1
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    public func getCameraVector() -> (SCNVector3, SCNVector3) {
        if let frame = sceneView.session.currentFrame {
            let transform = SCNMatrix4(frame.camera.transform)
            let direction = SCNVector3(-1 * transform.m31, -1 * transform.m32, -1 * transform.m33) // Orientation of camera in world space.
            let position = SCNVector3(transform.m41, transform.m42, transform.m43) // Location of camera in world space.
            return (direction, position)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        var nodeA, nodeB: SCNNode?
        if contact.nodeA.physicsBody?.categoryBitMask == Projectile.bitMask {
            nodeA = contact.nodeA
            nodeB = contact.nodeB
        }
        else {
            nodeA = contact.nodeB
            nodeB = contact.nodeA
        }
        if let nodeA = nodeA, let nodeB = nodeB {
            if nodeA.physicsBody?.categoryBitMask == Projectile.bitMask && nodeB.physicsBody?.categoryBitMask == EnemyShip.bitMask {
                if let particleSystem = SCNParticleSystem(named: "explosion", inDirectory: "art.scnassets") {
                    playSound(sound: .explosion)
                    let explosionNode = SCNNode()
                    explosionNode.addParticleSystem(particleSystem)
                    explosionNode.position = nodeA.position
                    sceneView.scene.rootNode.addChildNode(explosionNode)
                }
                if let nameA = nodeA.name, let nameB = nodeB.name {
                    var newEntities: [Entity] = []
                    for entity in entities {
                        if entity.getID() == nameA || entity.getID() == nameB {
                            entity.die()
                            score=score + 5
                            if(score>userHighScore){
                                userHighScore = score
                            }
//                            self.ref.child("history").setValue(["score": score])
                            let scores = self.ref.child("scores");
                            scores.child(userID).setValue([
                                "name"      : userName  ,
                                "score"     : score     ,
                                "highScore" : userHighScore
                                ])
                            self.spriteScene.score = score
                            
                            
                            deadEntities.append(entity)
                        }
                        else {
                            newEntities.append(entity)
                        }
                    }
                    entities = newEntities
                }
            }
        }
    }
    
    private func playSound(sound: Sound) {
        DispatchQueue.main.async {
            do
            {
                if let soundPath = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3", subdirectory: "Sounds") {
                    self.soundPlayer = try AVAudioPlayer(contentsOf: soundPath)
                    self.soundPlayer?.play()
                }
            }
            catch let error as NSError {
                print(error.description)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if worldIsSetUp {
            for entity in pendingEntities {
                sceneView.scene.rootNode.addChildNode(entity.getNode())
            }
            var newEntities: [Entity] = pendingEntities
            pendingEntities = []
            for entity in entities {
                if entity.dead() {
                    deadEntities.append(entity)
                }
                else {
                    entity.update(self)
                    newEntities.append(entity)
                }
            }
            entities = newEntities
            for entity in deadEntities {
                entity.remove()
            }
        }
        else {
            setUpWorld()
        }
    }
    
    /*func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        if worldIsSetUp {
            var newEntities: [Entity] = pendingEntities
            pendingEntities = []
            for entity in entities {
                if entity.dead() {
                    deadEntities.append(entity)
                }
                else {
                    entity.update(self)
                    newEntities.append(entity)
                }
            }
            entities = newEntities
            for entity in deadEntities {
                entity.remove()
            }
        }
        else {
            setUpWorld()
        }
    }*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    private func setUpWorld() {
        if let currentFrame = sceneView.session.currentFrame {
            if EnemyShip.scene != nil {
                for _ in 1...10 {
                    addEntity(EnemyShip(currentFrame))
                }
                worldIsSetUp = true
            }
        }
    }
//    override func viewWillAppear() {
//        super.viewWillAppear(animated)
//        self.navigationController?.navigationBarHidden = true
//    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        
//        let defaults = UserDefaults.standard
//        if let DKuserID = defaults.string(forKey: defaultsKeys.userID) {
//            print("userID")
//            print(DKuserID) // Some String Value
//        }
//        if let DKuserName = defaults.string(forKey: defaultsKeys.userName) {
//            print("userName")
//            print(DKuserName) // Another String Value
//        }
        let UDUserID = UserDefaults.standard.string(forKey: "userID") ?? ""
        let UDUserName = UserDefaults.standard.string(forKey: "userName") ?? ""
//        print(UDUserID)
//        print(UDUserName)
        userID = UDUserID
        userName = UDUserName
        
        if(userID != ""){
            AlertLoginBtn.isHidden  = true
            LabelName.text          = userName
            loginBtn.isHidden       = true
            logoutBtn.isHidden      = false
        }else{
            LabelName.isHidden  = true
            loginBtn.isHidden   = false
            logoutBtn.isHidden  = true
        }
        
        
        
        ref = Database.database().reference()
        
        // Set the scene to the view
        sceneView.scene = SCNScene()

        
        

        //FBSDK
//        let loginButton = FBSDKLoginButton(readPermissions: [ .publicProfile ])
//        loginButton.center = sceneView.center
//
//        sceneView.addSubview(loginButton)
        if(userID == ""){
            
            
            if (FBSDKAccessToken.current() != nil)
            {
                // User is already logged in, do work such as go to next view controller.
                
                let graphRequest:FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields":"first_name,email, picture.type(large)"])
                
                graphRequest.start(completionHandler: { (connection, result, error) -> Void in
                    
                    if ((error) != nil)
                    {
                        // Process error
                        print("Error: \(error)")
                    }
                    else
                    {
                        let tmp = result as! [String: AnyObject]
    //                    print("###################")
    //                    print(tmp["first_name"]!)
                        print("###################")
                        userName    = tmp["first_name"] as! String
                        userID      = tmp["id"]         as! String
                        print(userID)
                        let scores = self.ref.child("scores");
                        scores.child(userID).updateChildValues([
                            "score"     : 0
                        ])
                        print("###################")
                    }
                })
            }
            else //not using facebook login
            {
    //            AlertLoginBtn.isHidden = false
            }
            
            
            
                let loginView : FBSDKLoginButton = FBSDKLoginButton()
                self.view.addSubview(loginView)
    //            loginView.center = self.view.center
                loginView.frame.origin.y = self.view.frame.height - loginView.frame.height - 70
                loginView.frame.origin.x = 10
                loginView.readPermissions = ["public_profile", "email", "user_friends"]
    //            loginView.delegate = self
    //        }
        }
        
        //Firebase make score to zero
//        print(userID)
//        let scores = self.ref.child("scores");
//        scores.child(userID).setValue([
////            "name"      : userName  ,
//            "score"     : 0     ,
////            "highScore" : userHighScore
//        ])
        
        
        
        //Firebase  get data
        ref.child("scores").queryOrdered(byChild: "score").observe(.value, with: { (snapshot) in
            //                                (scores).queryOrdered(byChild: "score")
            //                            print(scoreQuery)
            //                            scoreQuery.observeSingleEvent(of: .value, with: { (snapshot) in
            // Get user value
            //                                print(snapshot.value?)
            //                                let value = snapshot.value as? NSDictionary
            //                                print(value!)
            //                                let username = value?["score"] as? Int ?? 0
            //                                let user = User(username: username)
            //                                print(username)
            arr = [NSDictionary]()
            let dic = snapshot.value as? NSDictionary
//            print(dic!)
            
            for (key,value) in dic! {
//                print("\(key) : \(value)")
                
                
                
                
                var childDic = value as? NSDictionary
                var keyString = key as! String
                
                if(keyString == userID){
//                    print(childDic!["highScore"]!)
                    userHighScore = childDic!["highScore"]  as! Int
                    score         = childDic!["score"]      as! Int
                }
                
                //                                                childDic["name"]!
                //                                                childDic!["name"]    = childDic!["name"] as! String
                //                                                print(name)
                //                                                childDic["score"] = childDic["score"] as Int
                var appendIndex = -1
                for (index, element) in arr.enumerated(){
//                    print(index)
//                    print(element["score"]!)
                    
                    let e = element["highScore"] as! Int
                    let c = childDic!["highScore"] as! Int
                    if(e<c){
                        appendIndex = index
                    }
                }
                if(appendIndex>=0){
                    arr.insert(childDic!, at: appendIndex)
                }else{
                    arr.append(childDic!)
                }
            }
            //                                            arr = arr.sort(by: {$0.score > $1.score})
            //            arr = arr.sort(by: {$0["score"] as! Int > $1["score"] as! Int})
//            print(arr)
            
            // ...
        }) { (error) in
            print(error.localizedDescription)
        }
        
        
        
        
        
        
        // Set the view's delegates
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true

        //shipHud = HUD(size: self.view.bounds.size)
        //sceneView.overlaySKScene = SKScene(size: self.view.bounds.size)
        //sceneView.overlaySKScene?.addChild(SKSpriteNode(imageNamed: "art.scnassets/crosshairs.png"))
        
        
        //scoreBoard
        self.spriteScene = OverlayScene(size: sceneView.bounds.size)
        sceneView.overlaySKScene = self.spriteScene
        
        
        // Toggle debugging options
        //sceneView.debugOptions = //.showPhysicsShapes // ARSCNDebugOptions.showWorldOrigin
        
        // Set EnemyShip's scene
        EnemyShip.scene = SCNScene(named: "art.scnassets/enemy_ship.scn")!
    }
   
    
    //function is fetching the user data
//    func getFBUserData(){
//        if((FBSDKAccessToken.current()) != nil){
//            FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "id, name, picture.type(large), email"]).start(completionHandler: { (connection, result, error) -> Void in
//                if (error == nil){
//                    self.dict = result as! [String : AnyObject]
//                    print(result!)
//                    print(self.dict)
//                }
//            })
//        }
//    }
    
    //fb user detail
//    func getDetails(){
//        guard let _ = AccessToken.current else{return}
//        let param = ["fields":"name, email , gender , picture.width(640).height(480)"]
//        let graphRequest = FBSDKGraphRequest(graphPath: "me",parameters: param)
//        graphRequest.start { (urlResponse, requestResult) in
//            switch requestResult{
//            case .failed(let error):
//                print(error)
//            case .success(response: let graphResponse):
//                if let responseDictionary = graphResponse.dictionaryValue{
//                    let name = responseDictionary["name"] as! String
//                    print(name)
////                    let gender = responseDictionary["gender"] as! String
////                    if let photo = responseDictionary["picture"] as? NSDictionary{
////                        let data = photo["data"] as! NSDictionary
////                        let picURL = data["url"] as! String
////                        print(name , gender , picURL)
////
////                        DispatchQueue.global().async {
////                            let imgData = NSData(contentsOf: URL(string: picURL)!)
////
////                            DispatchQueue.main.async {
////                                self.nameLabel.text = name
////                                self.genderLabel.text = gender
////                                let userImage = UIImage(data: imgData! as Data)
////                                self.photoImgView.image = userImage
////                            }
////                        }
////                    }
//
//                }
//            }
//        }
//    }
    
//    @objc func loginButtonClicked() {
//        let loginManager = FBSDKLoginManager()
//        loginManager.logIn([ .publicProfile ], viewController: self) { loginResult in
//            switch loginResult {
//            case .failed(let error):
//                print(error)
//            case .cancelled:
//                print("User cancelled login.")
//            case .success(let grantedPermissions, let declinedPermissions, let accessToken):
//                self.getFBUserData()
//            }
//        }
//    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        let UDUserID = UserDefaults.standard.string(forKey: "userID") ?? ""
        let UDUserName = UserDefaults.standard.string(forKey: "userName") ?? ""
        //        print(UDUserID)
        //        print(UDUserName)
        userID = UDUserID
        userName = UDUserName
        
        if(userID != ""){
            AlertLoginBtn.isHidden  = true
            LabelName.text          = userName
            loginBtn.isHidden       = true
            logoutBtn.isHidden      = false
        }else{
            LabelName.isHidden  = true
            loginBtn.isHidden   = false
            logoutBtn.isHidden  = true
        
            if (FBSDKAccessToken.current() != nil){
                AlertLoginBtn.isHidden = true
            }else{
                AlertLoginBtn.isHidden = false
            }
        }
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    
    private var entities: [Entity] = []
    private var entityCounter: Int = 0
    private var pendingEntities: [Entity] = []
    private var deadEntities: [Entity] = []
    private var soundPlayer: AVAudioPlayer?
    private var worldIsSetUp: Bool = false

    private enum Sound: String {
        case explosion = "explosion"
    }
    
}
