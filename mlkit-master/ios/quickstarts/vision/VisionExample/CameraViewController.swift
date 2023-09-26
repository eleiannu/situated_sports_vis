//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AVFoundation
import CoreVideo
import MLImage
import MLKit
import UIKit
import Charts
import CoreMotion

@objc(CameraViewController)
class CameraViewController: UIViewController, ChartViewDelegate{
    //background
    @IBOutlet var upperBG : UIView!
    @IBOutlet var lowerBG : UIView!
    private var e1 : CGFloat = 13.0
    private var e2 : CGFloat = 0.0
    private var e3 : CGFloat = 818.0
    private var redArmInterval : CGFloat = 0.0
    private var redBodyInterval : CGFloat = 0.0
    
    // ellipse
    private var ellipseOverlayView : UIView!
    private var previuosWrist : PoseLandmark!
    private var previuosWrist2 : CGFloat = 0.0
    private var ellipseTimes : [CFTimeInterval] = []
    private var ellipseDistances : [CGFloat] = []
    private var averageValues : [CGFloat] = []
    private var previousTime : CFTimeInterval = CACurrentMediaTime()
    private var maxAverageValue : CGFloat = 0.0
    private var showPipeline : Bool = true
    
    // array to save last movement
    private var movement : [Pose] = []
    // index of the pose we are showing within the movement
    private var index: Int = 0
    // boolean to start recording
    private var startRecording: Bool = false
    // label that tells whether we are recording the movement
    @IBOutlet var isRecordingLabel: UILabel!
    // boolean to know if we are showing the movement
    private var showVideo: Bool = false
    // button to start recording
    @IBOutlet weak var recButton: UIBarButtonItem!
    @IBOutlet weak var playButton: UIBarButtonItem!
    @IBOutlet weak var stopButton: UIBarButtonItem!
    private var stopBlinking: Bool = false
    private var recTimer: Timer = Timer()
    
    // button to start recording
    @IBOutlet var recordButton: UIButton!
    // button to show or stop showing
    @IBOutlet var showButton: UIButton!
    // background of buttons for displaying skeleton
    @IBOutlet weak var displayingView: UIStackView!
    // if we're on same speed mode the skeleton tries to go at the same speed of the athlete
    private var sameSpeedMode: Bool = false
    // saved movement stroke rate
    private var savedStrokeRate: CGFloat = 0.0
    
    // button to show or stop showing wrist path
    @IBOutlet var ellipseButton: UIButton!
    
    // boolean to check if the rower is in the start position of the stroke
    private var isStart: Bool = false
    // boolean to check if the rower is moving forward
    private var isGrowing: Bool = false
    // stroke count
    private var strokeCount: Int = 0
    // stroke count
    private var strokeCount2: Int = 0
    // start time of the stroke
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    // end time of the stroke
    private var elapsedTime: CFTimeInterval = CACurrentMediaTime()
    // start time of the drive
    private var startDriveTime: CFTimeInterval = CACurrentMediaTime()
    // end time of the stroke
    private var elapsedDriveTime: CFTimeInterval = CACurrentMediaTime()
    // times for the last 3 strokes
    private var last3Times : [CGFloat] = []
    // average of the last 3 times
    private var strokeRate: CGFloat = 0.0
    // start position
    private var startPos: CGFloat = 0.0
    // end position so we can compute the drive length
    private var endPos: CGFloat = 0.0
    // so we can compute the drive length
    private var previousDriveLength: CGFloat = 0.0
    // legs angle
    private var legsAngle: CGFloat = 0.0
    // body angle
    private var bodyAngle: CGFloat = 0.0
    // elbow angle
    private var elbowAngle: CGFloat = 0.0
    // legs angle approximated by 5
    private var legsAngleApprox: CGFloat = 0.0
    // body angle approximated by 5
    private var bodyAngleApprox: CGFloat = 0.0
    // previous legs angle to understand if it's increasing
    private var previousLegsAngle: CGFloat = 0.0
    // previous body angle to understand if it's increasing
    private var previousBodyAngle: CGFloat = 0.0
    // previous elbow angle to understand if it's increasing
    private var previousElbowAngle: CGFloat = 370.0
    // current min body angle in this stroke
    private var currMinBodyAngle: CGFloat = 370.0
    // current max body angle in this stroke
    private var currMaxBodyAngle: CGFloat = 0.0
    // previous max body angle in this stroke
    private var prevMaxBodyAngle: CGFloat = 180.0
    // current min legs angle in this stroke
    private var currMinLegsAngle: CGFloat = 370.0
    // current max legs angle in this stroke
    private var currMaxLegsAngle: CGFloat = 0.0
    // current min elbow angle in this stroke
    private var currMinElbowAngle: CGFloat = 370.0
    // body angle at 90 degrees legs angle
    private var angleAt90: CGFloat = 0.0
    //variables needed to add vis regarding body opening
    private var fixedShoulderPoint : CGPoint = CGPoint(x: 0, y: 0)
    private var fixedHipPoint : CGPoint = CGPoint(x: 0, y: 0)
    private var fixedShoulderPointVis : Vision3DPoint!
    private var fixedHipPointVis : Vision3DPoint!
    private var flagPoint : Bool = false
    private var flagPoint3 : Bool = false
    private var showWristPath : Bool = false
    private var newShoulderPointx : CGFloat = 0.0
    private var newShoulderPointy : CGFloat = 0.0
    // legs angle when elbows bent
    private var angleAtBentElbows: CGFloat = 0.0
    // green on red based on whether the elbows bent too early
    private var colorArc: UIColor = .clear
    // green on red based on whether the body opened too early
    private var colorArc2: UIColor = .clear
    private var fixedRightHipPosition: Vision3DPoint!
    private var fixedRightShoulderPosition: Vision3DPoint!
    private var arcAngle5: CGFloat = 0.0
    private var arcAngle6: CGFloat = 0.0
    
    
    // label that one can click to get information about elbow's angle
    @IBOutlet weak var elbowLabel: UILabel!
    // label that contains info about elbow's angle
    @IBOutlet weak var elbowLabelLong: UILabel!
    // boolean that tells whether you have to display the colored arc on the elbow
    private var showElbow: Bool = false
    // button to show elbow angle in time
    @IBOutlet weak var elbowSMButton: UIButton!
    // graph with elbow angles per stroke
    @IBOutlet weak var elbowGraph: LineChartView!
    private var elbowsCount : Int = 10
    private var elbows: [ChartDataEntry] = []
    // exclamation mark picture
    @IBOutlet weak var elbowEM: UIImageView!
    // boolean that tells whether you have to display the exclamation mark or not
    private var showElbowEM: Bool = true
    
    // label that one can click to get information about body opening
    @IBOutlet weak var hipLabel: UILabel!
    // label that contains info about body opening
    @IBOutlet weak var hipLabelLong: UILabel!
    // boolean that tells whether you have to display the colored arc on the hip
    private var showHip: Bool = false
    // boolean that tells whether the body opened too early
    private var bodyOpenedEarly: Bool = false
    // button to show body opening in time
    @IBOutlet weak var hipSMButton: UIButton!
    // graph with body opening per stroke
    @IBOutlet weak var hipGraph: LineChartView!
    private var hipsCount : Int = 10
    private var hips: [ChartDataEntry] = []
    // exclamation mark picture
    @IBOutlet weak var hipEM: UIImageView!
    // boolean that tells whether you have to display the exclamation mark or not
    private var showHipEM: Bool = true
    
    
    // label that one can click to get information about max body angle
    @IBOutlet weak var maxAngleLabel: UILabel!
    // boolean that tells whether you have to display the max body angle
    private var showMaxAngle: Bool = false
    // button to show max angle in time
    @IBOutlet weak var maxAngleSMButton: UIButton!
    // graph with max body angles per stroke
    @IBOutlet weak var anglesGraph: LineChartView!
    private var maxAnglesCounts : Int = 10
    private var maxAngles: [ChartDataEntry] = []
    
    private var circleColors : [NSUIColor] = []
    private var circleColors2 : [NSUIColor] = []
    private var circleHoleColor : NSUIColor = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
    private var circleHoleColor2 : NSUIColor = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
    
    //variables needed to fill bottom graphs
    
    @IBOutlet weak var strokeCountLabel: UILabel!
    private var driveLengthText: String = ""
    @IBOutlet weak var driveLengthLabel: UILabel!
    
    private var timesCount : Int = 10 // maximum number of previous drive speeds graphed in driveSpeedGraph
    private var strokeRateCounts : Int = 10 // maximum number of previous drive speeds graphed in strokeRateGraph
    private var minAnglesCounts : Int = 10
    
    private var times: [ChartDataEntry] = []
    private var strokeRates: [ChartDataEntry] = []
    private var minAngles: [ChartDataEntry] = []
    
    @IBOutlet weak var timesLabel: UILabel!
    @IBOutlet weak var strokeRateLabel: UILabel!
    
    //@IBOutlet weak var timesStackView: UIStackView!
    //@IBOutlet weak var strokeRateStackView: UIStackView!
    
    //@IBOutlet weak var anglesGraphLabel: UILabel!
    
    @IBOutlet weak var timesGraph: LineChartView!
    @IBOutlet weak var strokeRateGraph: LineChartView!
    
    private let detectors: [Detector] = [
        .poseAccurate
    ]
    
    private var currentDetector: Detector = .poseAccurate
    private var isUsingFrontCamera = false
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {
        
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    /// Initialized when one of the pose detector rows are chosen. Reset to `nil` when neither are.
    private var poseDetector: PoseDetector? = nil
    
    /// Initialized when a segmentation row is chosen. Reset to `nil` otherwise.
    private var segmenter: Segmenter? = nil
    
    /// The detector mode with which detection was most recently run. Only used on the video output
    /// queue. Useful for inferring when to reset detector instances which use a conventional
    /// lifecyle paradigm.
    private var lastDetector: Detector?
    
    // MARK: - IBOutlets
    
    @IBOutlet private weak var cameraView: UIView!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // initializing elbow metric
        self.elbowLabel.text = "Elbow angle +"
        self.elbowLabelLong.text = "Start rowing"
        //self.elbowLabel.textColor =  UIColor(red:0.0, green:122.0/255.0, blue:255.0/255.0, alpha:1.0)
        self.elbowLabel.textColor = .black
        self.elbowLabelLong.textColor = .black
        self.elbowLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.elbowLabelLong.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.elbowLabelLong.isHidden = true
        self.elbowSMButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.elbowSMButton.isHidden = true
        self.elbowLabel.layer.cornerRadius = 8.0
        self.elbowLabel.clipsToBounds = true
        self.elbowLabel.font = UIFont(name: "Avenir", size: 18)
        self.elbowLabelLong.font = UIFont(name: "Avenir", size: 18)
        self.elbowSMButton.layer.cornerRadius = 8.0
        self.elbowSMButton.clipsToBounds = true
        self.elbowSMButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
        self.elbowLabel.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.elbowLabel.layer.borderWidth = 1.0
        self.elbowLabelLong.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.elbowLabelLong.layer.borderWidth = 1.0
        self.elbowSMButton.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.elbowSMButton.layer.borderWidth = 1.0
        //self.elbowSMButton.titleLabel?.textColor = UIColor(red:120.0/255.0, green:94.0/255.0, blue:240.0/255.0, alpha:0.9)
        //UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9)
        
        // initializing body opening metric
        self.hipLabel.text = "Body opening +"
        self.hipLabelLong.text = "Start rowing"
        self.hipLabel.textColor = .black
        self.hipLabelLong.textColor = .black
        self.hipLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.hipLabelLong.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.hipLabelLong.isHidden = true
        self.hipSMButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.hipSMButton.isHidden = true
        self.hipLabel.layer.cornerRadius = 8.0
        self.hipLabel.clipsToBounds = true
        self.hipLabel.font = UIFont(name: "Avenir", size: 18)
        self.hipLabelLong.font = UIFont(name: "Avenir", size: 18)
        self.hipSMButton.layer.cornerRadius = 8.0
        self.hipSMButton.clipsToBounds = true
        self.hipSMButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
        self.hipLabel.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.hipLabel.layer.borderWidth = 1.0
        self.hipLabelLong.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.hipLabelLong.layer.borderWidth = 1.0
        self.hipSMButton.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.hipSMButton.layer.borderWidth = 1.0
        //self.hipSMButton.titleLabel?.textColor = UIColor(red: 8.0/255.0, green: 172.0/255.0, blue: 156.0/255.0, alpha: 1.0)
        
        // initializing max angle metric
        self.maxAngleLabel.text = "Max body angle +"
        self.maxAngleLabel.textColor = .black
        self.maxAngleLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.maxAngleSMButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        self.maxAngleSMButton.isHidden = true
        self.maxAngleLabel.layer.cornerRadius = 8.0
        self.maxAngleLabel.clipsToBounds = true
        self.maxAngleLabel.font = UIFont(name: "Avenir", size: 18)
        self.maxAngleSMButton.layer.cornerRadius = 8.0
        self.maxAngleSMButton.clipsToBounds = true
        self.maxAngleSMButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
        self.maxAngleLabel.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.maxAngleLabel.layer.borderWidth = 1.0
        self.maxAngleSMButton.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        self.maxAngleSMButton.layer.borderWidth = 1.0
        //self.maxAngleSMButton.titleLabel?.textColor = UIColor(red: 8.0/255.0, green: 172.0/255.0, blue: 156.0/255.0, alpha: 1.0)
        
        // angles graph
        //anglesGraph.chartDescription.text = "Angles Over Time"
        anglesGraph.xAxis.drawGridLinesEnabled = false
        anglesGraph.xAxis.enabled = false
        anglesGraph.legend.enabled = true
        anglesGraph.minOffset = 20
        anglesGraph.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        anglesGraph.layer.cornerRadius = 8.0
        anglesGraph.clipsToBounds = true
        
        // elbow graph
        //elbowGraph.chartDescription.text = "Elbows Over Time"
        elbowGraph.xAxis.drawGridLinesEnabled = false
        elbowGraph.xAxis.enabled = false
        elbowGraph.legend.enabled = true
        elbowGraph.minOffset = 20
        elbowGraph.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        elbowGraph.layer.cornerRadius = 8.0
        elbowGraph.clipsToBounds = true
        
        // hip graph
        //hipGraph.chartDescription.text = "Body opening Over Time"
        hipGraph.xAxis.drawGridLinesEnabled = false
        hipGraph.xAxis.enabled = false
        hipGraph.legend.enabled = true
        hipGraph.minOffset = 20
        hipGraph.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        hipGraph.layer.cornerRadius = 8.0
        hipGraph.clipsToBounds = true
        
        
        // initializing bottom graphs
        self.setCirclesColor()
        self.setCirclesColor2()
        self.setCirclesHoleColor()
        self.setCirclesHoleColor2()
        self.strokeRateGraph.isHidden = true
        self.timesGraph.isHidden = true
        
        // times graph
        timesGraph.xAxis.drawGridLinesEnabled = false
        timesGraph.xAxis.enabled = false
        timesGraph.legend.enabled = true
        timesGraph.minOffset = 20
        
        // stroke rate graph
        strokeRateGraph.xAxis.drawGridLinesEnabled = false
        strokeRateGraph.xAxis.enabled = false
        strokeRateGraph.legend.enabled = true
        strokeRateGraph.minOffset = 20
        
        timesLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.8)
        strokeRateLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.8)
        timesLabel.textColor = UIColor.black
        strokeRateLabel.textColor = UIColor.black
        timesLabel.font = UIFont(name: "Avenir", size: 18)
        strokeRateLabel.font = UIFont(name: "Avenir", size: 18)
        self.timesLabel.layer.cornerRadius = 8.0
        self.timesLabel.clipsToBounds = true
        self.strokeRateLabel.layer.cornerRadius = 8.0
        self.strokeRateLabel.clipsToBounds = true
        strokeRateGraph.layer.cornerRadius = 8.0
        strokeRateGraph.clipsToBounds = true
        timesGraph.layer.cornerRadius = 8.0
        timesGraph.clipsToBounds = true
        
        timesGraph.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        strokeRateGraph.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        
        
        // adding tap gestures to labels
        self.addGesture()
        self.addGesture2()
        self.addGesture3()
        self.addGesture4()
        self.addGestureElbow()
        self.addGestureHip()
        self.addGestureMaxAngle()
        
        // adding background color to displaying skeleton buttons
        /*
         displayingView.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
         recordButton.titleLabel?.text = "Record movement"
         recordButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
         recordButton.layer.cornerRadius = 8.0
         recordButton.clipsToBounds = true
         recordButton.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
         recordButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
         showButton.titleLabel?.text = "Show movement"
         showButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
         showButton.layer.cornerRadius = 8.0
         showButton.clipsToBounds = true
         showButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
         showButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
         isRecordingLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
         isRecordingLabel.font = UIFont(name: "Avenir", size: 18)
         */
        
        ellipseButton.titleLabel?.text = "Show wrist path"
        ellipseButton.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        ellipseButton.layer.cornerRadius = 8.0
        ellipseButton.clipsToBounds = true
        ellipseButton.titleLabel?.font = UIFont(name: "Avenir", size: 18)
        ellipseButton.layer.borderColor = UIColor(red:217.0/255.0, green:211.0/255.0, blue:205.0/255.0, alpha:0.9).cgColor
        ellipseButton.layer.borderWidth = 1.0
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
        
    }
    
    func recBlinkingActivate(){
        self.recButton.tintColor = self.recButton.tintColor?.withAlphaComponent(0)
        UIView.animate(withDuration: 0.8,
                       delay:0.0,
                       options:[.curveEaseInOut, .autoreverse, .repeat],
                       animations: {self.recButton.tintColor = UIColor.red.withAlphaComponent(1)},
                       completion: {_ in self.recButton.tintColor = UIColor.red.withAlphaComponent(0)})
    }
    
    func addGesture() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped(_:)))
        tap.numberOfTapsRequired = 1
        self.timesLabel.isUserInteractionEnabled = true
        self.timesLabel.addGestureRecognizer(tap)
    }
    
    @objc
    func labelTapped(_ tap: UITapGestureRecognizer) {
        self.timesGraph.isHidden = !self.timesGraph.isHidden
        self.timesLabel.isHidden = !self.timesLabel.isHidden
        self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
    }
    
    func addGesture2() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.graphTapped(_:)))
        tap.numberOfTapsRequired = 1
        self.timesGraph.isUserInteractionEnabled = true
        self.timesGraph.addGestureRecognizer(tap)
    }
    
    @objc
    func graphTapped(_ tap: UITapGestureRecognizer) {
        self.timesGraph.isHidden = !self.timesGraph.isHidden
        self.timesLabel.isHidden = !self.timesLabel.isHidden
        self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
    }
    
    func addGesture3() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped2(_:)))
        tap.numberOfTapsRequired = 1
        self.strokeRateLabel.isUserInteractionEnabled = true
        self.strokeRateLabel.addGestureRecognizer(tap)
    }
    
    @objc
    func labelTapped2(_ tap: UITapGestureRecognizer) {
        self.strokeRateGraph.isHidden = !self.strokeRateGraph.isHidden
        self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
        self.timesLabel.isHidden = !self.timesLabel.isHidden
    }
    
    func addGesture4() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.graphTapped2(_:)))
        tap.numberOfTapsRequired = 1
        self.strokeRateGraph.isUserInteractionEnabled = true
        self.strokeRateGraph.addGestureRecognizer(tap)
    }
    
    @objc
    func graphTapped2(_ tap: UITapGestureRecognizer) {
        self.strokeRateGraph.isHidden = !self.strokeRateGraph.isHidden
        self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
        self.timesLabel.isHidden = !self.timesLabel.isHidden
    }
    
    
    func addGestureElbow() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.elbowLabelTapped(_:)))
        tap.numberOfTapsRequired = 1
        self.elbowLabel.isUserInteractionEnabled = true
        self.elbowLabel.addGestureRecognizer(tap)
    }
    
    @objc
    func elbowLabelTapped(_ tap: UITapGestureRecognizer) {
        
        if self.elbowLabel.text == "Elbow angle -" {
            self.elbowLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.elbowLabel.text = "Elbow angle +"
            self.showElbow = false
            self.showElbowEM = true
            if !elbowGraph.isHidden {
                showEverything()
                elbowSMButton.setTitle("Show more", for: .normal)
            }
        }
        else {
            self.elbowLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            self.elbowSMButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.elbowLabel.text = "Elbow angle -"
            self.showElbow = true
            self.showElbowEM = false
            elbowEM.isHidden = true
        }
        self.elbowLabelLong.isHidden = !self.elbowLabelLong.isHidden
        self.elbowSMButton.isHidden = !self.elbowSMButton.isHidden
    }
    
    func addGestureHip() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.hipLabelTapped(_:)))
        tap.numberOfTapsRequired = 1
        self.hipLabel.isUserInteractionEnabled = true
        self.hipLabel.addGestureRecognizer(tap)
    }
    
    @objc
    func hipLabelTapped(_ tap: UITapGestureRecognizer) {
        
        if self.hipLabel.text == "Body opening -" {
            self.hipLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.hipLabel.text = "Body opening +"
            self.showHip = false
            self.showHipEM = true
            if !hipGraph.isHidden {
                showEverything()
                hipSMButton.setTitle("Show more", for: .normal)
            }
        }
        else {
            self.hipLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            self.hipSMButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.hipLabel.text = "Body opening -"
            self.showHip = true
            self.showHipEM = false
            hipEM.isHidden = true
        }
        self.hipLabelLong.isHidden = !self.hipLabelLong.isHidden
        self.hipSMButton.isHidden = !self.hipSMButton.isHidden
    }
    
    func addGestureMaxAngle() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.maxAngleLabelTapped(_:)))
        tap.numberOfTapsRequired = 1
        self.maxAngleLabel.isUserInteractionEnabled = true
        self.maxAngleLabel.addGestureRecognizer(tap)
    }
    
    @objc
    func maxAngleLabelTapped(_ tap: UITapGestureRecognizer) {
        
        if self.maxAngleLabel.text == "Max body angle -" {
            self.maxAngleLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.maxAngleLabel.text = "Max body angle +"
            self.showMaxAngle = false
            self.maxAngleLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
            self.removeDetectionAnnotations()
            if !anglesGraph.isHidden {
                showEverything()
                maxAngleSMButton.setTitle("Show more", for: .normal)
            }
        }
        else {
            self.maxAngleLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            self.maxAngleSMButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.maxAngleLabel.text = "Max body angle -"
            self.showMaxAngle = true
        }
        self.maxAngleSMButton.isHidden = !self.maxAngleSMButton.isHidden
    }
    
    func moveLabel(label: UILabel, x: CGFloat, y: CGFloat) {
        label.frame.origin = CGPoint(x:x,y:y)
    }
    func moveButton(button: UIButton, x: CGFloat, y: CGFloat) {
        button.frame.origin = CGPoint(x:x,y:y)
    }
    func hideEverything() {
        elbowLabel.isHidden = true
        elbowLabelLong.isHidden = true
        elbowSMButton.isHidden = true
        elbowGraph.isHidden = true
        showElbow = false
        showElbowEM = false
        elbowEM.isHidden = true
        hipLabel.isHidden = true
        hipLabelLong.isHidden = true
        hipSMButton.isHidden = true
        hipGraph.isHidden = true
        showHip = false
        showHipEM = false
        hipEM.isHidden = true
        maxAngleLabel.isHidden = true
        maxAngleSMButton.isHidden = true
        anglesGraph.isHidden = true
        showMaxAngle = false
        self.removeDetectionAnnotations()
        //recordButton.isHidden = true
        //isRecordingLabel.isHidden = true
        //showButton.isHidden = true
        showPipeline = false
        ellipseButton.isHidden = true
        strokeRateGraph.isHidden = true
        timesGraph.isHidden = true
        strokeRateLabel.isHidden = true
        timesLabel.isHidden = true
    }
    func showEverything(){
        self.elbowLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        elbowLabel.isHidden = false
        elbowLabel.text = "Elbow angle +"
        elbowGraph.isHidden = true
        showElbowEM = true
        hipLabel.isHidden = false
        self.hipLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        hipLabel.text = "Body opening +"
        hipGraph.isHidden = true
        showHipEM = true
        maxAngleLabel.isHidden = false
        self.maxAngleLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        maxAngleLabel.text = "Max body angle +"
        maxAngleLabel.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
        anglesGraph.isHidden = true
        moveLabel(label: elbowLabel, x: 226, y: 68)
        moveLabel(label: elbowLabelLong, x: 226, y: 114)
        moveButton(button: elbowSMButton, x: 226, y: 183)
        moveLabel(label: maxAngleLabel, x: 422, y: 68)
        moveButton(button: maxAngleSMButton, x: 422, y: 238)
        //recordButton.isHidden = false
        //isRecordingLabel.isHidden = false
        //showButton.isHidden = false
        showPipeline = true
        ellipseButton.isHidden = false
        strokeRateLabel.isHidden = false
        timesLabel.isHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = cameraView.frame
    }
    
    // MARK: - IBActions
    
    @IBAction func selectDetector(_ sender: Any) {
        presentDetectorsAlertController()
    }
    
    @IBAction func switchCamera(_ sender: Any) {
        isUsingFrontCamera = !isUsingFrontCamera
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }
    
    @IBAction func showVideo(_ sender: Any) {
        showVideo = !showVideo
        removeDetectionAnnotations()
        index = 0
        if showVideo {
            self.playButton.isEnabled = false
            self.stopButton.isEnabled = true
            //self.showButton.setTitle("Stop showing", for: .normal)
            self.hideEverything()
            //recordButton.isHidden = false
            //isRecordingLabel.isHidden = false
            //showButton.isHidden = false
        }
        else {
            self.playButton.isEnabled = true
            self.stopButton.isEnabled = false
            //self.showButton.setTitle("Show movement", for: .normal)
            self.showEverything()
        }
        
    }
    
    @IBAction func recordVideo(_ sender: Any) {
        startRecording = !startRecording
        movement.removeAll()
        index = 0
        if startRecording {
            //self.recordButton.setTitle("Stop recording", for: .normal)
        }
        else{
            //self.recordButton.setTitle("Record movement", for: .normal)
        }
        self.playButton.isEnabled = true
    }
    
    @IBAction func showMoreMaxAngle(_ sender: Any) {
        if anglesGraph.isHidden {
            self.hideEverything()
            maxAngleLabel.isHidden = false
            showMaxAngle = true
            maxAngleSMButton.isHidden = false
            anglesGraph.isHidden = false
            maxAngleSMButton.setTitle("Show less", for: .normal)
            moveLabel(label: maxAngleLabel, x: 30, y: 68)
            moveButton(button: maxAngleSMButton, x: 30, y: 238)
        }
        else{
            showEverything()
            self.maxAngleLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            maxAngleLabel.text = "Max body angle -"
            maxAngleSMButton.setTitle("Show more", for: .normal)
        }
    }
    @IBAction func showMoreElbow(_ sender: Any) {
        if elbowGraph.isHidden {
            self.hideEverything()
            self.showElbow = true
            elbowLabel.isHidden = false
            elbowLabelLong.isHidden = false
            elbowSMButton.isHidden = false
            elbowGraph.isHidden = false
            elbowSMButton.setTitle("Show less", for: .normal)
            moveLabel(label: elbowLabel, x: 30, y: 68)
            moveLabel(label: elbowLabelLong, x: 30, y: 114)
            moveButton(button: elbowSMButton, x: 30, y: 183)
        }
        else {
            showEverything()
            self.elbowLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            elbowLabel.text = "Elbow angle -"
            elbowSMButton.setTitle("Show more", for: .normal)
        }
    }
    @IBAction func showMoreHip(_ sender: Any) {
        if hipGraph.isHidden {
            self.hideEverything()
            self.showHip = true
            hipLabel.isHidden = false
            hipLabelLong.isHidden = false
            hipSMButton.isHidden = false
            hipGraph.isHidden = false
            hipSMButton.setTitle("Show less", for: .normal)
        }
        else {
            showEverything()
            self.hipLabel.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
            hipLabel.text = "Body opening -"
            hipSMButton.setTitle("Show more", for: .normal)
        }
    }
    @IBAction func showWristPath(_ sender: Any) {
        showWristPath = !showWristPath
        if showWristPath {
            ellipseButton.setTitle("Hide wrist path", for: .normal)
        }
        else{
            ellipseButton.setTitle("Show wrist path", for: .normal)
        }
    }
    
    
    // MARK: On-Device Detections
    
    private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat) {
        if let poseDetector = self.poseDetector {
            var poses: [Pose]
            do {
                poses = try poseDetector.results(in: image)
            } catch let error {
                print("Failed to detect poses with error: \(error.localizedDescription).")
                self.updatePreviewOverlayViewWithLastFrame()
                return
            }
            self.updatePreviewOverlayViewWithLastFrame()
            guard !poses.isEmpty else {
                print("Pose detector returned no results.")
                return
            }
            weak var weakSelf = self
            let mainQueue = DispatchQueue.main
            mainQueue.sync {
                guard let strongSelf = weakSelf else {
                    print("Self is nil!")
                    return
                }
                // recording skeleton position
                if(startRecording){
                    if !stopBlinking {
                        self.recBlinkingActivate()
                        stopBlinking = true
                    }
                    
                    displayingView.backgroundColor = UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9)
                    poses.forEach { pose in
                        if(movement.count < 150){
                            movement.append(pose)
                        }
                        else{
                            savedStrokeRate = strokeRate
                            startRecording = false
                            stopBlinking = false
                            view.layer.removeAllAnimations()
                            recButton.tintColor = recButton.tintColor?.withAlphaComponent(1)
                            //self.isRecordingLabel.text = "Stopped recording"
                            //self.recordButton.setTitle("Record", for: .normal)
                        }
                    }
                }
                
                // Pose detected. Currently, only single person detection is supported.
                poses.forEach { pose in
                    
                    
                    
                    // show overlay skeleton with its speed
                    if(showVideo && movement.count > 0){
                        if(index >= movement.count) {index = 0}
                        let ankleAthlete = movement[index].landmark(ofType: PoseLandmarkType.rightAnkle).position
                        let ankleSkeleton = pose.landmark(ofType: PoseLandmarkType.rightAnkle).position
                        let ankleDifference = UIUtilities.minus(lhs: strongSelf.normalizedPoint(
                            fromVisionPoint: ankleAthlete, width: width, height: height),
                                                                rhs: strongSelf.normalizedPoint(fromVisionPoint: ankleSkeleton, width: width, height: height))
                        let poseOverlayView2 = UIUtilities.createPoseOverlayViewOnBody(
                            forPose: movement[index],
                            inViewWithBounds: strongSelf.annotationOverlayView.bounds,
                            lineWidth: Constant.bigLineWidth,
                            dotRadius: Constant.bigDotRadius,
                            positionTransformationClosure: { (position) -> CGPoint in
                                return strongSelf.normalizedPoint(
                                    fromVisionPoint: position, width: width, height: height)
                            },
                            ankleDifference: ankleDifference
                        )
                        index += 1
                        strongSelf.removeDetectionAnnotations()
                        strongSelf.annotationOverlayView.addSubview(poseOverlayView2)
                    }
                    
                    // show overlay skeleton with same speed
                    /*
                     if(showVideo && movement.count > 0){
                     var currmin = 1000000.0
                     var bestindex = 0
                     var i = 0
                     var j = 0
                     let ankleAthlete = pose.landmark(ofType: PoseLandmarkType.rightAnkle).position
                     let shoulderAthlete = pose.landmark(ofType: PoseLandmarkType.rightShoulder).position
                     var ankleDifference = CGPoint(x: 0.0, y: 0.0)
                     
                     while(j < 50) {
                     if(index + i >= movement.count) {
                     index = 0
                     i = 0
                     }
                     print(index + i)
                     let ankleSkeleton = movement[index + i].landmark(ofType: PoseLandmarkType.rightAnkle).position
                     let tempAnkleDifference = UIUtilities.minus(lhs: strongSelf.normalizedPoint(
                     fromVisionPoint: ankleSkeleton, width: width, height: height),
                     rhs: strongSelf.normalizedPoint(fromVisionPoint: ankleAthlete, width: width, height: height))
                     
                     let shoulderSkeleton = UIUtilities.minus(lhs: strongSelf.normalizedPoint( fromVisionPoint: movement[index + i].landmark(ofType: PoseLandmarkType.rightShoulder).position, width: width, height: height), rhs: tempAnkleDifference)
                     let shoulderDistancex = abs(shoulderAthlete.x - shoulderSkeleton.x)
                     let shoulderDistancey = abs(shoulderAthlete.y - shoulderSkeleton.y)
                     let shoulderDistance = shoulderDistancex + shoulderDistancey
                     print(shoulderDistance)
                     if shoulderDistance < currmin {
                     bestindex = index + i
                     currmin = shoulderDistance
                     ankleDifference = tempAnkleDifference
                     }
                     i = i + 1
                     j = j + 1
                     }
                     index = bestindex
                     print(bestindex)
                     
                     let poseOverlayView2 = UIUtilities.createPoseOverlayViewOnBody(
                     forPose: movement[index],
                     inViewWithBounds: strongSelf.annotationOverlayView.bounds,
                     lineWidth: Constant.bigLineWidth,
                     dotRadius: Constant.bigDotRadius,
                     positionTransformationClosure: { (position) -> CGPoint in
                     return strongSelf.normalizedPoint(
                     fromVisionPoint: position, width: width, height: height)
                     },
                     ankleDifference: ankleDifference
                     )
                     //index += 1
                     strongSelf.removeDetectionAnnotations()
                     strongSelf.annotationOverlayView.addSubview(poseOverlayView2)
                     }
                     */
                    
                    if(!showVideo){
                        
                        // Checking orientation
                        var mirror = false
                        if pose.landmark(ofType: PoseLandmarkType.rightHip).position.y > pose.landmark(ofType: PoseLandmarkType.rightAnkle).position.y {
                            mirror = true
                        }
                        
                        
                        let poseOverlayView = UIUtilities.createPoseOverlayView(
                            forPose: pose,
                            inViewWithBounds: strongSelf.annotationOverlayView.bounds,
                            lineWidth: Constant.smallLineWidth,
                            dotRadius: Constant.smallDotRadius,
                            positionTransformationClosure: { (position) -> CGPoint in
                                return strongSelf.normalizedPoint(
                                    fromVisionPoint: position, width: width, height: height)
                            }
                        )
                        
                        
                        // Computing useful points
                        let rightKnee = pose.landmark(ofType: PoseLandmarkType.rightKnee)
                        let rightHip = pose.landmark(ofType: PoseLandmarkType.rightHip)
                        let rightShoulder = pose.landmark(ofType: PoseLandmarkType.rightShoulder)
                        let rightElbow = pose.landmark(ofType: PoseLandmarkType.rightElbow)
                        let rightWrist = pose.landmark(ofType: PoseLandmarkType.rightWrist)
                        
                        
                        
                        // Computing legs, body and elbow angle
                        legsAngle = self.angle(firstLandmark: rightHip, midLandmark: rightKnee, lastLandmark: pose.landmark(ofType: PoseLandmarkType.rightAnkle))
                        bodyAngle = self.angle(firstLandmark: pose.landmark(ofType: PoseLandmarkType.rightShoulder), midLandmark: rightHip, lastLandmark: rightKnee)
                        elbowAngle = self.angle(firstLandmark: rightWrist, midLandmark: rightElbow, lastLandmark: rightShoulder)
                        
                        if showPipeline {
                            
                            //pipeline graph
                            let legsPPPoints = [NSValue(cgPoint: CGPoint(x: 42 + e2, y: 200 + e3 + e1)),
                                                NSValue(cgPoint: CGPoint(x: 42 + e2, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 190 + e2, y: 150 + e3)),
                                                NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 200 + e3 + e1))]
                            let bodyPPPoints = [NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                NSValue(cgPoint: CGPoint(x: 190 + e2, y: 150 + e3)),
                                                NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 298 + e2, y: 150 + e3)),
                                                NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 200 + e3 + e1))]
                            let armsPPPoints = [NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                NSValue(cgPoint: CGPoint(x: 298 + e2, y: 150 + e3)),
                                                NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 398 + e2, y: 100 + e3 - e1)),
                                                NSValue(cgPoint: CGPoint(x: 398 + e2, y: 200 + e3 + e1))]
                            
                            UIUtilities.addPipeline(withPoints: legsPPPoints, to: poseOverlayView, color: UIColor.black)
                            UIUtilities.addPipeline(withPoints: bodyPPPoints, to: poseOverlayView, color: UIColor.black)
                            UIUtilities.addPipeline(withPoints: armsPPPoints, to: poseOverlayView, color: UIColor.black)
                            UIUtilities.addLabel(atPoint: CGPoint(x:111+e2, y:150 + e3), to: poseOverlayView, color: UIColor.black, text: "Legs", width: 50, bgColor: .clear)
                            UIUtilities.addLabel(atPoint: CGPoint(x:234+e2, y:150 + e3), to: poseOverlayView, color: UIColor.black, text: "Body", width: 50, bgColor: .clear)
                            UIUtilities.addLabel(atPoint: CGPoint(x:340+e2, y:150 + e3), to: poseOverlayView, color: UIColor.black, text: "Arms", width: 50, bgColor: .clear)
                            
                            
                            if(!isGrowing){
                                //print(legsAngle)
                                if legsAngle <= 90 {
                                    let firstleginterval = ((legsAngle - currMinLegsAngle) / (90 - currMinLegsAngle)) * (108 - 0.8*e1)
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 42 + e2, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 42 + e2, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 42 + e2 + firstleginterval, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 42 + e2 + firstleginterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0))
                                }
                                else{
                                    let leginterval = ((legsAngle - 90) / (180 - 90)) * (40 + 0.8*e1)
                                    
                                    var bodyinterval = ((bodyAngle - currMinBodyAngle) / (prevMaxBodyAngle - currMinBodyAngle)) * 148
                                    if bodyinterval > 148 {
                                        bodyinterval = 148
                                    }
                                    //oppure passi direttamente al body interval arrivato li?
                                    if (bodyinterval > leginterval){
                                        var arminterval = ((180 - elbowAngle) / (180 - currMinElbowAngle)) * (140 + 0.8*e1)
                                        if arminterval > (140 + 0.8*e1) {
                                            arminterval = (140 + 0.8*e1)
                                        }
                                        //anche qui
                                        if (arminterval + 258 + e2 - 0.8*e1 > bodyinterval + 150 + e2 - 0.8*e1) && (bodyinterval + 150 + e2 - 0.8*e1 > 258 + e2 - 0.8*e1) {
                                            UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 42 + e2, y: 200 + e3 + e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 42 + e2, y: 100 + e3 - e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + arminterval, y: 100 + e3-e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + arminterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0))
                                        }
                                        else{
                                            UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 42 + e2, y: 200 + e3 + e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 42 + e2, y: 100 + e3 - e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + bodyinterval, y: 100 + e3 - e1)),
                                                                              NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + bodyinterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0))
                                        }
                                    }
                                    else{
                                        UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 42 + e2, y: 200 + e3 + e1)),
                                                                          NSValue(cgPoint: CGPoint(x: 42 + e2, y: 100 + e3 - e1)),
                                                                          NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + leginterval, y: 100 + e3 - e1)),
                                                                          NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + leginterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0))
                                    }
                                    
                                    
                                }
                                
                                
                            }
                            
                            if redArmInterval > 0 {
                                if redArmInterval > (140 + 0.8*e1) {
                                    redArmInterval = 140 + 0.8*e1
                                }
                                if redArmInterval >= 40 + 0.8*e1 {
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 298 + e2, y: 150 + e3)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                }
                                else{
                                    let yintersection = 1.25*redArmInterval
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 200 + e3 + e1 - yintersection))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 258 + e2 - 0.8*e1 + redArmInterval, y: 100 + e3 - e1 + yintersection))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                }
                            }
                            
                            if redBodyInterval > 0 {
                                if redBodyInterval > 148 {
                                    redBodyInterval = 148
                                }
                                if redBodyInterval >= 40 + 0.8*e1 {
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 190 + e2, y: 150 + e3)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 200 + e3 + e1))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                }
                                else{
                                    let yintersection = 1.25*redBodyInterval
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 200 + e3 + e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 200 + e3 + e1 - yintersection))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                    UIUtilities.addShape(withPoints: [NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 100 + e3 - e1)),
                                                                      NSValue(cgPoint: CGPoint(x: 150 + e2 - 0.8*e1 + redBodyInterval, y: 100 + e3 - e1 + yintersection))], to: poseOverlayView, color: UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0))
                                }
                            }
                        }
                        
                        
                        if flagPoint3{
                            if ellipseDistances.count > 0 {
                                let sumDistancesArray = ellipseDistances.reduce(0, +)
                                let sumTimesArray = ellipseTimes.reduce(0, +)
                                
                                let avgDistancesValue = CGFloat(sumDistancesArray)/CGFloat(ellipseDistances.count)
                                let avgTimesValue = CGFloat(sumTimesArray)/CGFloat(ellipseTimes.count)
                                var avgArrayValue = avgDistancesValue/avgTimesValue
                                
                                if averageValues.count == 10{
                                    averageValues.removeFirst()
                                }
                                averageValues.append(avgArrayValue)
                                maxAverageValue = averageValues.max() ?? 0.0
                                
                                avgArrayValue = avgArrayValue/maxAverageValue * 10
                                let lineColor = UIColor(red:255.0/255.0, green:(255.0-avgArrayValue*25.5)/255.0, blue:(178.0-avgArrayValue*14.0)/255.0, alpha:1)
                               
                                
                                UIUtilities.addLineSegment2(fromPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: rightWrist.position, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: rightWrist.position, width: width, height: height).y), toPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: previuosWrist.position, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: previuosWrist.position, width: width, height: height).y), inView: ellipseOverlayView, color: lineColor, width: 10) }
                            
                            if ellipseDistances.count == 5{
                                ellipseDistances.removeFirst()
                                ellipseTimes.removeFirst()
                            }
                            ellipseDistances.append(sqrt((rightWrist.position.x-previuosWrist.position.x)*(rightWrist.position.x-previuosWrist.position.x) + (rightWrist.position.y-previuosWrist.position.y)*(rightWrist.position.y-previuosWrist.position.y)))
                            ellipseTimes.append(CACurrentMediaTime() - previousTime)
                            
                            previuosWrist = rightWrist
                            previousTime = CACurrentMediaTime()
                        }
                        
                        
                        // Displaying arc on elbow angle in red if wrong, green if right
                        let c1 = rightElbow.position.x - rightShoulder.position.x
                        let c2 = rightElbow.position.y - rightShoulder.position.y
                        let arcAngle = 90 + (atan(c2/c1) * (180 / Double.pi))
                        let c3 = rightElbow.position.x - rightWrist.position.x
                        let c4 = rightElbow.position.y - rightWrist.position.y
                        var arcAngle2 = 90 + (atan(c4/c3) * (180 / Double.pi))
                        if c3 < 0{
                            arcAngle2 = 180 + arcAngle2
                        }
                        
                        if !isGrowing && elbowAngle < 155 && angleAtBentElbows == 0 {
                            angleAtBentElbows = legsAngle
                        }
                        
                        if !isGrowing && legsAngle < 120 && elbowAngle < 155 {
                            colorArc = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
                            self.elbowLabelLong.text = "bent too early"
                            self.elbowLabelLong.textColor = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
                            if showElbowEM{
                                elbowEM.isHidden = false
                            }
                            redArmInterval = ((180 - elbowAngle) / (180 - currMinElbowAngle)) * (140 + 0.8*e1)
                        }
                        else if !isGrowing && legsAngle < 120 && elbowAngle >= 155 {
                            if angleAtBentElbows == 0 {
                                
                            }
                            colorArc = UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0)
                            self.elbowLabelLong.text = "bent on time"
                            self.elbowLabelLong.textColor = UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0)
                            elbowEM.isHidden = true
                        }
                        
                        if (!isGrowing && showElbow){
                            UIUtilities.addPieChart(to: poseOverlayView, startingAt: arcAngle/3.60, endingAt: arcAngle2/3.60, radius: 50, fillColor: colorArc.withAlphaComponent(0.5), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 0.0, y: 0.0, width: poseOverlayView.frame.size.width, height: poseOverlayView.frame.size.height), center: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: rightElbow.position, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: rightElbow.position, width: width, height: height).y), bgColor: .clear, mirror: false)
                        }
                        
                        /*
                         
                         if (legsAngle > 30 && legsAngle < 80) {
                         fixedShoulderPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightShoulder).position, width: width, height: height)
                         fixedHipPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightHip).position, width: width, height: height)
                         fixedShoulderPointVis = pose.landmark(ofType: PoseLandmarkType.rightShoulder).position
                         fixedHipPointVis = pose.landmark(ofType: PoseLandmarkType.rightHip).position
                         flagPoint = true
                         }
                         */
                        
                        //UIUtilities.addCircle(atPoint: fixedHipPoint, to: poseOverlayView, color: UIColor.blue, radius: 5.0)
                        //UIUtilities.addCircle(atPoint: fixedShoulderPoint, to: poseOverlayView, color: UIColor.blue, radius: 5.0)
                        //let currShoulderPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightShoulder).position, width: width, height: height)
                        
                        if(flagPoint && legsAngle < 95 && !isGrowing)
                        { if(bodyAngle - currMinBodyAngle > 15) {
                            redBodyInterval = ((bodyAngle - currMinBodyAngle) / (prevMaxBodyAngle - currMinBodyAngle)) * 148
                            //Exlamation Mark
                            
                            self.hipLabelLong.text = "opened too early"
                            self.hipLabelLong.textColor = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
                            if showHipEM{
                                hipEM.isHidden = false
                            }
                            
                            //let currHipPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightHip).position, width: width, height: height)
                            
                            //let hipDifference = UIUtilities.minus(lhs: currHipPoint, rhs: fixedHipPoint)
                            
                            //let newShoulderPoint = UIUtilities.plus(lhs: fixedShoulderPoint, rhs: hipDifference)
                            
                            newShoulderPointx = (fixedShoulderPointVis.x)/width
                            newShoulderPointy = (fixedShoulderPointVis.y + (rightHip.position.y - fixedHipPointVis.y))/height
                            
                            
                            
                            //print(fixedShoulderPoint.x)
                            //print(fixedShoulderPointVis.y)
                            
                            
                            //UIUtilities.addCircle(atPoint: CGPoint(x: previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: newShoulderPointx, y: newShoulderPointy)).x, y: previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: newShoulderPointx, y: newShoulderPointy)).y), to: poseOverlayView, color: UIColor.blue, radius: 50.0)
                            
                            
                            //UIUtilities.addLineSegment(fromPoint: currHipPoint, toPoint: newShoulderPoint, inView: poseOverlayView, color: UIColor.blue, width: 7.0)
                            
                            
                            
                            
                            
                            //entrambe vanno al contrario
                            //questa sarebbe la y
                            let c9 = rightHip.position.x - rightShoulder.position.x
                            //questa sarebbe la x
                            let c10 = rightHip.position.y - rightShoulder.position.y
                            arcAngle5 = 90 + (atan(c10/c9) * (180 / Double.pi))
                            //new shoulder point x is actually x
                            let c11 = rightHip.position.x + newShoulderPointx
                            //new shoulder point y is actually y
                            let c12 = rightHip.position.y + newShoulderPointy
                            
                            
                            arcAngle6 = 90 + (atan(c12/c11) * (180 / Double.pi))
                            
                            if arcAngle6 < arcAngle5{
                                arcAngle6 = arcAngle5
                            }
                            
                            fixedRightHipPosition = rightHip.position
                            fixedRightShoulderPosition = rightShoulder.position
                            bodyOpenedEarly = true
                            
                        }
                            else {
                                self.hipLabelLong.text = "opened on time"
                                self.hipLabelLong.textColor = UIColor(red:0.0/255.0, green:90.0/255.0, blue:181.0/255.0, alpha:1.0)
                                hipEM.isHidden = true
                            }
                        }
                        if (flagPoint && bodyOpenedEarly && !isGrowing && showHip ){
                            let fixedHip = CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y)
                            let fixedShoulder = CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedShoulderPointVis, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedShoulderPointVis, width: width, height: height).y)
                            let newFixedShoulder = CGPoint(x: previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: newShoulderPointx, y: newShoulderPointy)).x, y: previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: newShoulderPointx, y: newShoulderPointy)).y)
                            let hip = CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedRightHipPosition, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y)
                            let shoulder = CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedRightShoulderPosition, width: width, height: height).x, y: fixedShoulder.y)
                            
                            let arrayPoints = [
                                NSValue(cgPoint: hip),
                                NSValue(cgPoint: shoulder),
                                NSValue(cgPoint: newFixedShoulder)
                            ]
                            
                            /*UIUtilities.addPieChart(to: poseOverlayView, startingAt: arcAngle5/3.60, endingAt: arcAngle6/3.60, radius: 150, fillColor: UIColor.red.withAlphaComponent(0.5), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 100.0, height: 100.0), center: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedRightHipPosition, width: width, height: height).x - 10, y: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height).y - 10), bgColor: .clear, mirror: false)
                             UIUtilities.addShape(withPoints: arrayPoints,
                             to: poseOverlayView, color: UIColor.red) */
                            
                            
                            UIUtilities.addWedge(to: poseOverlayView, fixedHip: fixedHip, hip: hip, shoulder: newFixedShoulder, fixedShoulder: fixedShoulder, fillColor: UIColor.black)
                            UIUtilities.addShape(withPoints: arrayPoints, to: poseOverlayView, color: UIColor(red:216.0/255.0, green:27.0/255.0, blue:96.0/255.0, alpha:0.9))
                            UIUtilities.addArrow(to: poseOverlayView, start: shoulder, end: newFixedShoulder, pointerLineLength: 10, arrowAngle: CGFloat(Double.pi / 4), fillColor: UIColor.black)
                            UIUtilities.addLineSegment(fromPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedRightHipPosition, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y), toPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedRightHipPosition, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y + 15), inView: poseOverlayView, color: UIColor.black, width: 2)
                            UIUtilities.addLineSegment(fromPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y), toPoint: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).x, y: strongSelf.normalizedPoint(fromVisionPoint: fixedHipPointVis, width: width, height: height).y + 15), inView: poseOverlayView, color: UIColor.black, width: 2)
                        }
                        
                        // Displaying arc on legs angle in red if wrong, green if right
                        if (legsAngle > 85 && legsAngle <= 90 && isStart){
                            angleAt90 = bodyAngle
                        }
                        
                        /*
                         let c5 = rightShoulder.position.x - rightHip.position.x
                         let c6 = rightShoulder.position.y - rightHip.position.y
                         let arcAngle3 = 90 + (atan(c6/c5) * (180 / Double.pi))
                         if angleAt90 > 40{
                         colorArc2 = .red
                         self.hipLabelLong.text = "Body opened too early"
                         self.hipLabelLong.textColor = .red
                         if showHipEM{
                         hipEM.isHidden = false
                         }
                         }
                         else{
                         colorArc2 = .green
                         self.hipLabelLong.text = "Body opened on time"
                         self.hipLabelLong.textColor = UIColor(red: 0.10, green: 0.60, blue: 0.40, alpha: 1)
                         hipEM.isHidden = true
                         }
                         
                         if (!isGrowing && showHip){
                         UIUtilities.addPieChart(to: poseOverlayView, startingAt: arcAngle3/3.60, endingAt: (arcAngle3 + bodyAngle)/3.60, radius: 50, fillColor: colorArc2.withAlphaComponent(0.5), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 100.0, height: 100.0), center: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height).x - 10, y: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height).y - 10), bgColor: .clear, mirror: false)
                         }*/
                        
                        // approximating legs and body angles
                        legsAngleApprox = (5 * CGFloat(Int(legsAngle/5)))
                        bodyAngleApprox = (5 * CGFloat(Int(bodyAngle/5)))
                        
                        //UIUtilities.addLabel(atPoint: strongSelf.normalizedPoint(fromVisionPoint: rightKnee.position, width: width, height: height), to: poseOverlayView, color: UIColor.blue, text: Int(legsAngleApprox).description, width: 50)
                        //UIUtilities.addLabel(atPoint: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height), to: poseOverlayView, color: UIColor.blue, text: Int(bodyAngleApprox).description, width: 50)
                        
                        
                        
                        if bodyAngle > currMaxBodyAngle {
                            currMaxBodyAngle = bodyAngle
                        }
                        //print(currMaxBodyAngle)
                        if legsAngle > currMaxLegsAngle {
                            currMaxLegsAngle = legsAngle
                        }
                        if bodyAngle < currMinBodyAngle {
                            currMinBodyAngle = bodyAngle
                            /*
                             fixedShoulderPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightShoulder).position, width: width, height: height)
                             fixedHipPoint = strongSelf.normalizedPoint(fromVisionPoint: pose.landmark(ofType: PoseLandmarkType.rightHip).position, width: width, height: height)
                             */
                        }
                        if legsAngle < currMinLegsAngle {
                            currMinLegsAngle = legsAngle
                        }
                        if elbowAngle < currMinElbowAngle {
                            currMinElbowAngle = elbowAngle
                        }
                        
                        // showing max angle arc
                        if showMaxAngle {
                            
                            self.maxAngleLabel.backgroundColor = .clear
                            var offset = 0.0
                            if anglesGraph.isHidden{
                                offset = 392.0
                            }
                            let sizeRectx = 186.0
                            let sizeRecty = 170.0
                            let radius = 80.0
                            let xRect = 30.0 + offset
                            let yRect = 40.0
                            
                            UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: radius, fillColor: UIColor(red: 0.63, green: 0.87, blue: 0.85, alpha: 1), strokeColor: UIColor(red: 0.0, green: 0.66, blue: 0.62, alpha: 1), strokeSize: 2.0, rect: CGRect(x: xRect, y: yRect, width: sizeRectx, height: sizeRecty), center: CGPoint(x: sizeRectx/2, y: sizeRecty/2 + 53), bgColor: UIColor(red:255.0/255.0, green:255.0/255.0, blue:255.0/255.0, alpha:0.9), mirror: mirror)
                            if currMaxBodyAngle >= prevMaxBodyAngle{
                                UIUtilities.addPieChart(to: poseOverlayView, startingAt: prevMaxBodyAngle/3.60, endingAt: currMaxBodyAngle/3.60, radius: radius, fillColor: UIColor(red: 0.0, green: 0.66, blue: 0.62, alpha: 1), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: xRect, y: yRect, width: sizeRectx, height: sizeRecty), center: CGPoint(x: sizeRectx/2, y: sizeRecty/2 + 53), bgColor: .clear, mirror: mirror)
                            }
                            else{
                                UIUtilities.addPieChart(to: poseOverlayView, startingAt: currMaxBodyAngle/3.60, endingAt: prevMaxBodyAngle/3.60, radius: radius, fillColor: .gray, strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: xRect, y: yRect, width: sizeRectx, height: sizeRecty), center: CGPoint(x: sizeRectx/2 , y: sizeRecty/2 + 53), bgColor: .clear, mirror: mirror)
                            }
                            UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: 30, fillColor: .clear, strokeColor: .black.withAlphaComponent(0.5), strokeSize: 1.0, rect: CGRect(x: xRect, y: yRect, width: sizeRectx, height: sizeRecty), center: CGPoint(x: sizeRectx/2, y: sizeRecty/2 + 53), bgColor: .clear, mirror: mirror)
                            
                            
                            UIUtilities.addLabel(atPoint: CGPoint(x: 130.0 + offset, y: 195.0), to: poseOverlayView, color: .black, text: Int(currMaxBodyAngle).description + "°", width: 50, bgColor: .clear)
                        }
                        
                        
                        
                        if (legsAngle > 160 && bodyAngle > 80 && bodyAngle < 150) {
                            //End of stroke
                            isStart = false
                            if isStart && elapsedTime > 1 && elapsedTime < 5{
                                isStart = false
                                
                                
                                
                                
                                
                                //self.anglesLabel.text = "Min Angle: " + String(Int(currMinBodyAngle)) + " Max Angle: " + String(Int(currMaxBodyAngle)) + " Angle at 90: " + String(Int(angleAt90))
                                
                                
                                
                                
                                isStart = false
                                if((endPos - startPos) > previousDriveLength){
                                    driveLengthText = "Drive Length incresead"
                                    driveLengthLabel.textColor = UIColor.green
                                } else if((endPos - startPos) == previousDriveLength){
                                    driveLengthText = "Same Drive Length"
                                    driveLengthLabel.textColor = UIColor.black
                                }
                                else{
                                    driveLengthText = "Drive Length decresead"
                                    driveLengthLabel.textColor = UIColor(red:220.0/255.0, green:50.0/255.0, blue:32.0/255.0, alpha:1.0)
                                }
                                driveLengthLabel.text = driveLengthText
                                strokeCountLabel.text = "Stroke Count: " + String(strokeCount)
                                previousDriveLength = endPos - startPos
                            }
                        }
                        if (legsAngle < 80 && bodyAngle < 45) {
                            //Start of stroke
                            isStart = true
                            
                        }
                        
                        
                        //print(elbowAngle)
                        //print(previousElbowAngle)
                        if(elbowAngle - 5 > previousElbowAngle && !isGrowing ){
                            print("start")
                            isGrowing = true
                            elapsedTime = CACurrentMediaTime() - startTime;
                            elapsedTime = round(elapsedTime * 100) / 100.0
                            startTime = CACurrentMediaTime()
                            if elapsedTime < 8 {
                                strokeCount += 1
                                if last3Times.count == 3{
                                    last3Times.removeFirst()
                                }
                                last3Times.append(elapsedTime)
                                
                                strokeRate = 60 / (last3Times.reduce(0, +) / CGFloat(last3Times.count))
                                updateStrokeRateGraph(time: Double(strokeCount), currStrokeRate: Double(strokeRate))
                                self.strokeRateLabel.text = "Stroke Rate: " + String( Double(round(100 * strokeRate) / 100))
                                
                                updateHipGraph(time: Double(strokeCount), currHipAngle: angleAt90)
                                updateElbowGraph(time: Double(strokeCount), currElbowAngle: angleAtBentElbows)
                                
                                elapsedDriveTime = CACurrentMediaTime() - startDriveTime;
                                elapsedDriveTime = round(elapsedDriveTime * 100) / 100.0
                                self.timesLabel.text = "Drive time: " + String(elapsedDriveTime)
                                updateDriveSpeedGraph(time: Double(strokeCount), currDriveSpeed: Double(elapsedDriveTime))
                                
                                
                                angleAtBentElbows = 0
                                flagPoint = false
                                ellipseOverlayView = UIView(frame: strongSelf.annotationOverlayView.bounds)
                                flagPoint3 = true
                                previuosWrist = rightWrist
                                updateAnglesGraph(time: Double(strokeCount), minAngle: Double(currMinBodyAngle), maxAngle: Double(currMaxBodyAngle))
                                currMinBodyAngle = 370.0
                                currMinLegsAngle = 370.0
                                currMinElbowAngle = 370.0
                                bodyOpenedEarly = false
                                redArmInterval = 0.0
                                redBodyInterval = 0.0
                            }
                        }
    
                        if(legsAngle - 5 > previousLegsAngle && isGrowing && strongSelf.normalizedPoint(fromVisionPoint: rightWrist.position, width: width, height: height).x < previuosWrist2 && isStart){
                            print("end")
                            startDriveTime = CACurrentMediaTime()
                            isGrowing = false
                            prevMaxBodyAngle = currMaxBodyAngle
                            currMaxBodyAngle = 0.0
                            currMaxLegsAngle = 0.0
                        }
                        if(isGrowing && legsAngle < previousLegsAngle){
                            startPos = pose.landmark(ofType: PoseLandmarkType.rightWrist).position.x
                            previousLegsAngle = legsAngle
                            previousBodyAngle = bodyAngle
                            previousElbowAngle = elbowAngle
                            previuosWrist2 = strongSelf.normalizedPoint(fromVisionPoint: rightWrist.position, width: width, height: height).x
                            fixedShoulderPointVis = pose.landmark(ofType: PoseLandmarkType.rightShoulder).position
                            fixedHipPointVis = pose.landmark(ofType: PoseLandmarkType.rightHip).position
                            flagPoint = true
                        }
                        if(!isGrowing && legsAngle > previousLegsAngle){
                            endPos = pose.landmark(ofType: PoseLandmarkType.rightWrist).position.x
                            previousLegsAngle = legsAngle
                            previousBodyAngle = bodyAngle
                            previousElbowAngle = elbowAngle
                            previuosWrist2 = strongSelf.normalizedPoint(fromVisionPoint: rightWrist.position, width: width, height: height).x
                        }
                        /*
                         if(!isGrowing && legsAngle < previousLegsAngle){
                         ellipseOverlayView = UIView(frame: strongSelf.annotationOverlayView.bounds)
                         flagPoint3 = true
                         print("INIOzio")
                         }
                         */
                        
                        
                        strongSelf.removeDetectionAnnotations()
                        strongSelf.annotationOverlayView.addSubview(poseOverlayView)
                        if showWristPath&&flagPoint3 {strongSelf.annotationOverlayView.addSubview(ellipseOverlayView)}
                        
                    }
                }
            }
        }
    }
    
    
    
    public func angle(
        firstLandmark: PoseLandmark,
        midLandmark: PoseLandmark,
        lastLandmark: PoseLandmark
    ) -> CGFloat {
        let x_1 : CGFloat = firstLandmark.position.x - midLandmark.position.x
        let y_1 : CGFloat = firstLandmark.position.y - midLandmark.position.y
        let z_1 : CGFloat = firstLandmark.position.z - midLandmark.position.z
        let x_2 : CGFloat = lastLandmark.position.x - midLandmark.position.x
        let y_2 : CGFloat = lastLandmark.position.y - midLandmark.position.y
        let z_2 : CGFloat = lastLandmark.position.z - midLandmark.position.z
        let dotProduct : CGFloat = x_1 * x_2 + y_1 * y_2 + z_1 * z_2;
        let mag1 : CGFloat = sqrt(x_1*x_1 + y_1*y_1 + z_1*z_1)
        let mag2 : CGFloat = sqrt(x_2*x_2 + y_2*y_2 + z_2*z_2)
        //return acos(dotProduct/(mag1*mag2))*180/Double.pi;
        
        let radians: CGFloat =
        atan2(lastLandmark.position.y - midLandmark.position.y,
              lastLandmark.position.x - midLandmark.position.x) -
        atan2(firstLandmark.position.y - midLandmark.position.y,
              firstLandmark.position.x - midLandmark.position.x)
        var degrees = radians * 180.0 / .pi
        degrees = abs(degrees) // Angle should never be negative
        if degrees > 180.0 {
            degrees = 360.0 - degrees // Always get the acute representation of the angle
        }
        return degrees
    }
    
    func setCirclesColor() {
        
        for _ in 0..<maxAnglesCounts {
            self.circleColors.append(NSUIColor(red: 8.0/255.0, green: 172.0/255.0, blue: 156.0/255.0, alpha: 1.0))
        }
    }
    func setCirclesColor2() {
        
        for _ in 0..<maxAnglesCounts {
            self.circleColors2.append(NSUIColor(red: 128.0/255.0, green: 43.0/255.0, blue: 226.0/255.0, alpha: 1.0))
        }
    }
    
    func setCirclesHoleColor() {
        self.circleHoleColor = NSUIColor(red: 160.0/255.0, green: 222.0/255.0, blue: 218.0/255.0, alpha: 1.0)
    }
    
    func setCirclesHoleColor2() {
        self.circleHoleColor2 = NSUIColor(red: 230.0/255.0, green: 230.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    }
    
    func updateAnglesGraph(time: Double, minAngle : Double, maxAngle : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (maxAngles.count >= maxAnglesCounts) {
            maxAngles.removeFirst(1)
        }
        maxAngles.append(ChartDataEntry(x: time, y: maxAngle))
        
        // update graph
        let line2 = LineChartDataSet(entries: maxAngles, label: "Max body angle per stroke")
        line2.circleColors = circleColors
        line2.circleHoleColor = circleHoleColor
        line2.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line2)
        anglesGraph.data = data
        anglesGraph.setVisibleXRangeMaximum(5)
        anglesGraph.moveViewToX(5)
        anglesGraph.dragEnabled = true
        anglesGraph.doubleTapToZoomEnabled = false
    }
    
    func updateAnglesGraph2(time: Double, minAngle : Double, maxAngle : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (minAngles.count >= minAnglesCounts) {
            minAngles.removeFirst(1)
        }
        minAngles.append(ChartDataEntry(x: time, y: minAngle))
        if (maxAngles.count >= maxAnglesCounts) {
            maxAngles.removeFirst(1)
        }
        maxAngles.append(ChartDataEntry(x: time, y: maxAngle))
        
        // update graph
        let line1 = LineChartDataSet(entries: minAngles, label: "Min body angle per stroke")
        line1.circleColors = circleColors2
        line1.circleHoleColor = circleHoleColor2
        line1.colors = [circleColors2[0]]
        let line2 = LineChartDataSet(entries: maxAngles, label: "Max body angle per stroke")
        line2.circleColors = circleColors
        line2.circleHoleColor = circleHoleColor
        line2.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line1)
        data.append(line2)
        anglesGraph.data = data
        anglesGraph.setVisibleXRangeMaximum(5)
        anglesGraph.moveViewToX(5)
        anglesGraph.dragEnabled = true
        anglesGraph.doubleTapToZoomEnabled = false
    }
    
    // Adds a new drive speed measurement to the graph of drive speed
    func updateElbowGraph(time: Double, currElbowAngle : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (elbows.count >= elbowsCount) {
            elbows.removeFirst(1)
        }
        elbows.append(ChartDataEntry(x: time, y: currElbowAngle))
        
        // update graph
        let line1 = LineChartDataSet(entries: elbows, label: "Legs angle at which your elbows started bending")
        line1.circleColors = circleColors
        line1.circleHoleColor = circleHoleColor
        line1.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line1)
        elbowGraph.data = data
        elbowGraph.setVisibleXRangeMaximum(5)
        elbowGraph.moveViewToX(5)
        elbowGraph.dragEnabled = true
        elbowGraph.doubleTapToZoomEnabled = false
    }
    
    // Adds a new drive speed measurement to the graph of drive speed
    func updateHipGraph(time: Double, currHipAngle : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (hips.count >= hipsCount) {
            hips.removeFirst(1)
        }
        hips.append(ChartDataEntry(x: time, y: currHipAngle))
        
        // update graph
        let line1 = LineChartDataSet(entries: hips, label: "Body angle when legs at 90°")
        line1.circleColors = circleColors
        line1.circleHoleColor = circleHoleColor
        line1.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line1)
        hipGraph.data = data
        hipGraph.setVisibleXRangeMaximum(5)
        hipGraph.moveViewToX(5)
        hipGraph.dragEnabled = true
        hipGraph.doubleTapToZoomEnabled = false
    }
    
    // Adds a new drive speed measurement to the graph of drive speed
    func updateDriveSpeedGraph(time: Double, currDriveSpeed : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (times.count >= timesCount) {
            times.removeFirst(1)
        }
        times.append(ChartDataEntry(x: time, y: currDriveSpeed))
        
        // update graph
        let line1 = LineChartDataSet(entries: times, label: "Times per stroke")
        line1.circleColors = circleColors
        line1.circleHoleColor = circleHoleColor
        line1.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line1)
        timesGraph.data = data
        timesGraph.setVisibleXRangeMaximum(2)
        timesGraph.moveViewToX(2)
        timesGraph.dragEnabled = true
        timesGraph.doubleTapToZoomEnabled = false
    }
    
    // Adds a computed stroke rate to the graph of stroke rates
    func updateStrokeRateGraph(time: Double, currStrokeRate : Double) {
        // update strokeRate array to contain at most strokeRateCount data points
        if (strokeRates.count >= strokeRateCounts) {
            strokeRates.removeFirst(1)
        }
        strokeRates.append(ChartDataEntry(x: time, y: currStrokeRate))
        
        // update graph
        let line1 = LineChartDataSet(entries: strokeRates, label: "Stroke Rates")
        line1.circleColors = circleColors
        line1.circleHoleColor = circleHoleColor
        line1.colors = [circleColors[0]]
        let data = LineChartData()
        data.append(line1)
        strokeRateGraph.data = data
        strokeRateGraph.setVisibleXRangeMaximum(2)
        strokeRateGraph.moveViewToX(2)
        strokeRateGraph.dragEnabled = true
        strokeRateGraph.doubleTapToZoomEnabled = false
    }
    
    // MARK: - Private
    
    private func setUpCaptureSessionOutput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.beginConfiguration()
            // When performing latency tests to determine ideal capture settings,
            // run the app in 'release' mode to get accurate performance metrics
            strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
            guard strongSelf.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            strongSelf.captureSession.addOutput(output)
            strongSelf.captureSession.commitConfiguration()
        }
    }
    
    private func setUpCaptureSessionInput() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
            guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                strongSelf.captureSession.beginConfiguration()
                let currentInputs = strongSelf.captureSession.inputs
                for input in currentInputs {
                    strongSelf.captureSession.removeInput(input)
                }
                
                let input = try AVCaptureDeviceInput(device: device)
                guard strongSelf.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                strongSelf.captureSession.addInput(input)
                strongSelf.captureSession.commitConfiguration()
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func startSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        weak var weakSelf = self
        sessionQueue.async {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            strongSelf.captureSession.stopRunning()
        }
    }
    
    private func setUpPreviewOverlayView() {
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            
        ])
    }
    
    private func setUpAnnotationOverlayView() {
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            return discoverySession.devices.first { $0.position == position }
        }
        return nil
    }
    
    private func presentDetectorsAlertController() {
        let alertController = UIAlertController(
            title: Constant.alertControllerTitle,
            message: Constant.alertControllerMessage,
            preferredStyle: .alert
        )
        weak var weakSelf = self
        detectors.forEach { detectorType in
            let action = UIAlertAction(title: detectorType.rawValue, style: .default) {
                [unowned self] (action) in
                guard let value = action.title else { return }
                guard let detector = Detector(rawValue: value) else { return }
                guard let strongSelf = weakSelf else {
                    print("Self is nil!")
                    return
                }
                strongSelf.currentDetector = detector
                strongSelf.removeDetectionAnnotations()
            }
            if detectorType.rawValue == self.currentDetector.rawValue { action.isEnabled = false }
            alertController.addAction(action)
        }
        alertController.addAction(UIAlertAction(title: Constant.cancelActionTitleText, style: .cancel))
        present(alertController, animated: true)
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        weak var weakSelf = self
        DispatchQueue.main.sync {
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            
            guard let lastFrame = lastFrame,
                  let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
            else {
                return
            }
            strongSelf.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
            //strongSelf.removeDetectionAnnotations()
        }
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
            return
        }
        let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
    }
    
    private func convertedPoints(
        from points: [NSValue]?,
        width: CGFloat,
        height: CGFloat
    ) -> [NSValue]? {
        return points?.map {
            let cgPointValue = $0.cgPointValue
            let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
            let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
            let value = NSValue(cgPoint: cgPoint)
            return value
        }
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
    
    /// Resets any detector instances which use a conventional lifecycle paradigm. This method is
    /// expected to be invoked on the AVCaptureOutput queue - the same queue on which detection is
    /// run.
    private func resetManagedLifecycleDetectors(activeDetector: Detector) {
        if activeDetector == self.lastDetector {
            // Same row as before, no need to reset any detectors.
            return
        }
        // Clear the old detector, if applicable.
        switch self.lastDetector {
        case .poseAccurate:
            self.poseDetector = nil
            break
        default:
            break
        }
        // Initialize the new detector, if applicable.
        switch activeDetector {
        case .poseAccurate:
            // The `options.detectorMode` defaults to `.stream`
            let options = AccuratePoseDetectorOptions()
            self.poseDetector = PoseDetector.poseDetector(options: options)
            break
        default:
            break
        }
        self.lastDetector = activeDetector
    }
    
    private func rotate(_ view: UIView, orientation: UIImage.Orientation) {
        var degree: CGFloat = 0.0
        switch orientation {
        case .up, .upMirrored:
            degree = 90.0
        case .rightMirrored, .left:
            degree = 180.0
        case .down, .downMirrored:
            degree = 270.0
        case .leftMirrored, .right:
            degree = 0.0
        }
        view.transform = CGAffineTransform.init(rotationAngle: degree * 3.141592654 / 180)
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        // Evaluate `self.currentDetector` once to ensure consistency throughout this method since it
        // can be concurrently modified from the main thread.
        let activeDetector = self.currentDetector
        resetManagedLifecycleDetectors(activeDetector: activeDetector)
        
        lastFrame = sampleBuffer
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: isUsingFrontCamera ? .front : .back
        )
        visionImage.orientation = orientation
        
        guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
            print("Failed to create MLImage from sample buffer.")
            return
        }
        inputImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        var shouldEnableClassification = false
        var shouldEnableMultipleObjects = false
        switch activeDetector {
            
        default:
            break
        }
        switch activeDetector {
            
        default:
            break
        }
        
        switch activeDetector {
            
        case .poseAccurate:
            detectPose(in: inputImage, width: imageWidth, height: imageHeight)
        }
    }
}

// MARK: - Constants

public enum Detector: String {
    case poseAccurate = "Pose Detection, accurate"
}

private enum Constant {
    static let alertControllerTitle = "Vision Detectors"
    static let alertControllerMessage = "Select a detector"
    static let cancelActionTitleText = "Cancel"
    static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
    static let noResultsMessage = "No Results"
    static let localModelFile = (name: "bird", type: "tflite")
    static let labelConfidenceThreshold = 0.75
    static let smallDotRadius: CGFloat = 4.0
    static let bigDotRadius: CGFloat = 8.0
    static let smallLineWidth: CGFloat = 3.0
    static let bigLineWidth: CGFloat = 6.0
    static let originalScale: CGFloat = 1.0
    static let padding: CGFloat = 10.0
    static let resultsLabelHeight: CGFloat = 200.0
    static let resultsLabelLines = 5
    static let imageLabelResultFrameX = 0.4
    static let imageLabelResultFrameY = 0.1
    static let imageLabelResultFrameWidth = 0.5
    static let imageLabelResultFrameHeight = 0.8
    static let segmentationMaskAlpha: CGFloat = 0.5
}
