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
    // array to save last movement
    private var movement : [Pose] = []
    // index of the pose we are showing within the movement
    private var index: Int = 0
    // boolean to know if we are showing the movement
    private var showVideo: Bool = false
    // boolean to start recording
    private var startRecording: Bool = false
    // label that tells whether we are recording the movement
    @IBOutlet var isRecordingLabel: UILabel!
    

    // boolean to check if the rower is in the start position of the stroke
    private var isStart: Bool = false
    // boolean to check if the rower is moving forward
    private var isGrowing: Bool = false
    // stroke count
    private var strokeCount: Int = 0
    // start time of the stroke
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    // end time of the stroke
    private var elapsedTime: CFTimeInterval = CACurrentMediaTime()
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
    // legs angle approximated by 5
    private var legsAngleApprox: CGFloat = 0.0
    // body angle approximated by 5
    private var bodyAngleApprox: CGFloat = 0.0
    // previous legs angle to understand if it's increasing
    private var previousLegsAngle: CGFloat = 0.0
    // current min body angle in this stroke
    private var currMinBodyAngle: CGFloat = 370.0
    // current max body angle in this stroke
    private var currMaxBodyAngle: CGFloat = 0.0
    // previous max body angle in this stroke
    private var prevMaxBodyAngle: CGFloat = 0.0
    // body angle at 90 degrees legs angle
    private var angleAt90: CGFloat = 0.0
    // green on red based on whether the elbows bent too early
    private var colorArc: UIColor = .clear
    // green on red based on whether the body opened too early
    private var colorArc2: UIColor = .clear
    
    // label that one can click to get information about elbow's angle
    @IBOutlet weak var elbowLabel: UILabel!
    // label that contains info about elbow's angle
    @IBOutlet weak var elbowLabelLong: UILabel!
    // boolean that tells whether you have to display the colored arc on the elbow
    private var showElbow: Bool = false
    
    // label that one can click to get information about body opening
    @IBOutlet weak var hipLabel: UILabel!
    // label that contains info about body opening
    @IBOutlet weak var hipLabelLong: UILabel!
    // boolean that tells whether you have to display the colored arc on the hip
    private var showHip: Bool = false
    
    @IBOutlet weak var strokeCountLabel: UILabel!
    private var driveLengthText: String = ""
    @IBOutlet weak var driveLengthLabel: UILabel!
    
    //variables needed to fill bottom graphs
    private var timesCount : Int = 10 // maximum number of previous drive speeds graphed in driveSpeedGraph
    private var strokeRateCounts : Int = 10 // maximum number of previous drive speeds graphed in strokeRateGraph
    private var minAnglesCounts : Int = 10
    private var maxAnglesCounts : Int = 10
    
    private var times: [ChartDataEntry] = []
    private var strokeRates: [ChartDataEntry] = []
    private var minAngles: [ChartDataEntry] = []
    private var maxAngles: [ChartDataEntry] = []
    
    @IBOutlet weak var timesLabel: UILabel!
    @IBOutlet weak var strokeRateLabel: UILabel!
    @IBOutlet weak var anglesLabel: UILabel!
    
    @IBOutlet weak var timesStackView: UIStackView!
    @IBOutlet weak var strokeRateStackView: UIStackView!
    @IBOutlet weak var anglesStackView: UIStackView!
   
    @IBOutlet weak var timesGraphLabel: UILabel!
    @IBOutlet weak var strokeRateGraphLabel: UILabel!
    @IBOutlet weak var anglesGraphLabel: UILabel!
    
    @IBOutlet weak var timesGraph: LineChartView!
    @IBOutlet weak var strokeRateGraph: LineChartView!
    @IBOutlet weak var anglesGraph: LineChartView!
    
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
      
      // initializing elbow label
      self.elbowLabel.text = "Elbow angle +"
      self.elbowLabelLong.text = "Start rowing"
      self.elbowLabel.textColor = .black
      self.elbowLabelLong.textColor = .black
      self.elbowLabel.backgroundColor = UIColor.white.withAlphaComponent(0.8)
      self.elbowLabelLong.backgroundColor = UIColor.white.withAlphaComponent(0.8)
      self.elbowLabelLong.isHidden = true
      
      // initializing body opening label
      self.hipLabel.text = "Body opening +"
      self.hipLabelLong.text = "Start rowing"
      self.hipLabel.textColor = .black
      self.hipLabelLong.textColor = .black
      self.hipLabel.backgroundColor = UIColor.white.withAlphaComponent(0.8)
      self.hipLabelLong.backgroundColor = UIColor.white.withAlphaComponent(0.8)
      self.hipLabelLong.isHidden = true
      
      // initializing bottom graphs
      self.anglesLabel.isHidden = true
      self.strokeRateStackView.isHidden = true
      self.timesStackView.isHidden = true
      self.anglesStackView.isHidden = true
      self.timesGraphLabel.text = "Time per stroke"
      self.strokeRateGraphLabel.text = "Strokes per minute"
      self.anglesGraphLabel.text = "Min and Max body angle"
      
      // times graph
      timesGraph.chartDescription.text = "Drive Speed Over Time"
      timesGraph.xAxis.drawGridLinesEnabled = false
      timesGraph.xAxis.enabled = false
      timesGraph.legend.enabled = false
      timesGraph.minOffset = 20
      
      // angles graph
      anglesGraph.chartDescription.text = "Angles Over Time"
      anglesGraph.xAxis.drawGridLinesEnabled = false
      anglesGraph.xAxis.enabled = false
      anglesGraph.legend.enabled = false
      anglesGraph.minOffset = 20
      
      // stroke rate graph
      strokeRateGraph.chartDescription.text = "Stroke Rate Over Time"
      strokeRateGraph.xAxis.drawGridLinesEnabled = false
      strokeRateGraph.xAxis.enabled = false
      strokeRateGraph.legend.enabled = false
      strokeRateGraph.minOffset = 20
      
      timesLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      strokeRateLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      anglesLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
      timesLabel.textColor = UIColor.white
      strokeRateLabel.textColor = UIColor.white
      anglesLabel.textColor = UIColor.white
      timesGraph.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      strokeRateGraph.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      anglesGraph.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      
      self.timesGraphLabel.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      self.strokeRateGraphLabel.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      self.anglesGraphLabel.backgroundColor = UIColor.white.withAlphaComponent(0.9)
      
      // adding tap gestures to labels
      self.addGesture()
      self.addGesture2()
      self.addGesture3()
      self.addGesture4()
      self.addGesture5()
      self.addGesture6()
      self.addGestureElbow()
      self.addGestureHip()
     
      previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      setUpPreviewOverlayView()
      setUpAnnotationOverlayView()
      setUpCaptureSessionOutput()
      setUpCaptureSessionInput()
      
  }
    
    func addGesture() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped(_:)))
           tap.numberOfTapsRequired = 1
           self.timesLabel.isUserInteractionEnabled = true
           self.timesLabel.addGestureRecognizer(tap)
       }

       @objc
       func labelTapped(_ tap: UITapGestureRecognizer) {
           self.timesStackView.isHidden = !self.timesStackView.isHidden
           self.timesLabel.isHidden = !self.timesLabel.isHidden
       }
    
    func addGesture2() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.graphTapped(_:)))
           tap.numberOfTapsRequired = 1
           self.timesGraph.isUserInteractionEnabled = true
           self.timesGraph.addGestureRecognizer(tap)
       }

       @objc
       func graphTapped(_ tap: UITapGestureRecognizer) {
           self.timesStackView.isHidden = !self.timesStackView.isHidden
           self.timesLabel.isHidden = !self.timesLabel.isHidden
       }
    
    func addGesture3() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped2(_:)))
           tap.numberOfTapsRequired = 1
           self.strokeRateLabel.isUserInteractionEnabled = true
           self.strokeRateLabel.addGestureRecognizer(tap)
       }

       @objc
       func labelTapped2(_ tap: UITapGestureRecognizer) {
           self.strokeRateStackView.isHidden = !self.strokeRateStackView.isHidden
           self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
       }
    
    func addGesture4() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.graphTapped2(_:)))
           tap.numberOfTapsRequired = 1
           self.strokeRateGraph.isUserInteractionEnabled = true
           self.strokeRateGraph.addGestureRecognizer(tap)
       }

       @objc
       func graphTapped2(_ tap: UITapGestureRecognizer) {
           self.strokeRateStackView.isHidden = !self.strokeRateStackView.isHidden
           self.strokeRateLabel.isHidden = !self.strokeRateLabel.isHidden
       }
    
    func addGesture5() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped3(_:)))
           tap.numberOfTapsRequired = 1
           self.anglesLabel.isUserInteractionEnabled = true
           self.anglesLabel.addGestureRecognizer(tap)
       }

       @objc
       func labelTapped3(_ tap: UITapGestureRecognizer) {
           self.anglesStackView.isHidden = !self.anglesStackView.isHidden
           self.anglesLabel.isHidden = !self.anglesLabel.isHidden
       }
    
    func addGesture6() {

           let tap = UITapGestureRecognizer(target: self, action: #selector(self.graphTapped3(_:)))
           tap.numberOfTapsRequired = 1
           self.anglesGraph.isUserInteractionEnabled = true
           self.anglesGraph.addGestureRecognizer(tap)
       }

       @objc
       func graphTapped3(_ tap: UITapGestureRecognizer) {
           self.anglesStackView.isHidden = !self.anglesStackView.isHidden
           self.anglesLabel.isHidden = !self.anglesLabel.isHidden
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
            self.elbowLabel.text = "Elbow angle +"
            self.showElbow = false
        }
        else {
            self.elbowLabel.text = "Elbow angle -"
            self.showElbow = true
        }
        self.elbowLabelLong.isHidden = !self.elbowLabelLong.isHidden
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
          self.hipLabel.text = "Body opening +"
          self.showHip = false
      }
      else {
          self.hipLabel.text = "Body opening -"
          self.showHip = true
      }
      self.hipLabelLong.isHidden = !self.hipLabelLong.isHidden
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
  }
    
  @IBAction func recordVideo(_ sender: Any) {
      movement.removeAll()
      index = 0
      startRecording = true
  }

  // MARK: On-Device Detections

  private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat) {
      //updateStrokeRateGraph(time: 0.0, currStrokeRate: 0.0)
      //updateDriveSpeedGraph(time: 0.0, currDriveSpeed: 0.0)
     
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
      DispatchQueue.main.sync {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
          
          if(startRecording){
              self.isRecordingLabel.text = "is recording"
              poses.forEach { pose in
                  if(movement.count < 50){
                      movement.append(pose)
                  }
                  else{
                      startRecording = false
                      self.isRecordingLabel.text = "stopped recording"
                  }
              }
          }
          
          // Pose detected. Currently, only single person detection is supported.
          poses.forEach { pose in
          
          if(showVideo && movement.count > 0){
              if(index >= movement.count) {index = 0}
              let poseOverlayView2 = UIUtilities.createPoseOverlayViewOnBody(
                forPose: movement[index],
                inViewWithBounds: strongSelf.annotationOverlayView.bounds,
                lineWidth: Constant.bigLineWidth,
                dotRadius: Constant.bigDotRadius,
                positionTransformationClosure: { (position) -> CGPoint in
                  return strongSelf.normalizedPoint(
                    fromVisionPoint: position, width: width, height: height)
                },
                rightAnkle: pose.landmark(ofType: PoseLandmarkType.rightAnkle).position
              )
              index += 1
              strongSelf.removeDetectionAnnotations()
              strongSelf.annotationOverlayView.addSubview(poseOverlayView2)
          }
          
          if(!showVideo){

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
            let elbowAngle = self.angle(firstLandmark: rightWrist, midLandmark: rightElbow, lastLandmark: rightShoulder)
              
              
              
            // Displaying arc on elbow angle in red if wrong, green if right
              if self.showElbow {
              let c1 = rightElbow.position.x - rightShoulder.position.x
              let c2 = rightElbow.position.y - rightShoulder.position.y
              let arcAngle = 90 + (atan(c2/c1) * (180 / Double.pi))
              let c3 = rightElbow.position.x - rightWrist.position.x
              let c4 = rightElbow.position.y - rightWrist.position.y
              var arcAngle2 = 90 + (atan(c4/c3) * (180 / Double.pi))
              if c3 < 0{
                  arcAngle2 = 180 + arcAngle2
              }
              
              if !isGrowing && legsAngle < 120 && elbowAngle < 155 {
                  colorArc = .red
                  self.elbowLabelLong.text = "Elbows bent too early"
                  self.elbowLabelLong.textColor = .red

              }
              else if !isGrowing && legsAngle < 120 && elbowAngle >= 155 {
                  colorArc = .green
                  self.elbowLabelLong.text = "Elbows bent on time"
                  self.elbowLabelLong.textColor = UIColor(red: 0.10, green: 0.60, blue: 0.40, alpha: 1)
              }
              
              if (!isGrowing){
                  UIUtilities.addPieChart(to: poseOverlayView, startingAt: arcAngle/3.60, endingAt: arcAngle2/3.60, radius: 50, fillColor: colorArc.withAlphaComponent(0.5), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 100.0, height: 100.0), center: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: rightElbow.position, width: width, height: height).x - 10, y: strongSelf.normalizedPoint(fromVisionPoint: rightElbow.position, width: width, height: height).y - 10), bgColor: .clear, mirror: false)
              }
              }
              
              
              // Displaying arc on legs angle in red if wrong, green if right
              if self.showHip {
              if (legsAngle > 85 && legsAngle < 95 && isStart){
                  angleAt90 = bodyAngle
              }
              let c5 = rightShoulder.position.x - rightHip.position.x
              let c6 = rightShoulder.position.y - rightHip.position.y
              let arcAngle3 = 90 + (atan(c6/c5) * (180 / Double.pi))
              if angleAt90 > 40{
                  colorArc2 = .red
                  self.hipLabelLong.text = "Body opened too early"
                  self.hipLabelLong.textColor = .red
              }
              else{
                  colorArc2 = .green
                  self.hipLabelLong.text = "Body opened on time"
                  self.hipLabelLong.textColor = UIColor(red: 0.10, green: 0.60, blue: 0.40, alpha: 1)
              }
              if (!isGrowing){
                  UIUtilities.addPieChart(to: poseOverlayView, startingAt: arcAngle3/3.60, endingAt: (arcAngle3 + bodyAngle)/3.60, radius: 50, fillColor: colorArc2.withAlphaComponent(0.5), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 100.0, height: 100.0), center: CGPoint(x: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height).x - 10, y: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height).y - 10), bgColor: .clear, mirror: false)
              }
              }
              


              
              

             
            // approximating legs and body angles
            legsAngleApprox = (5 * CGFloat(Int(legsAngle/5)))
            bodyAngleApprox = (5 * CGFloat(Int(bodyAngle/5)))
            
            //UIUtilities.addLabel(atPoint: strongSelf.normalizedPoint(fromVisionPoint: rightKnee.position, width: width, height: height), to: poseOverlayView, color: UIColor.blue, text: Int(legsAngleApprox).description, width: 50)
            //UIUtilities.addLabel(atPoint: strongSelf.normalizedPoint(fromVisionPoint: rightHip.position, width: width, height: height), to: poseOverlayView, color: UIColor.blue, text: Int(bodyAngleApprox).description, width: 50)
              
             
              
              if bodyAngle > currMaxBodyAngle {
                  currMaxBodyAngle = bodyAngle
              }
              if bodyAngle < currMinBodyAngle {
                  currMinBodyAngle = bodyAngle
              }
              
              /*
              UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: 100, fillColor: UIColor(red: 0.63, green: 0.48, blue: 0.63, alpha: 1), strokeColor: .purple, strokeSize: 2.0, rect: CGRect(x: 10.0, y: 10.0, width: 220.0, height: 220.0), bgColor: UIColor.white.withAlphaComponent(0.3))
              if currMaxBodyAngle >= prevMaxBodyAngle{
                  UIUtilities.addPieChart(to: poseOverlayView, startingAt: prevMaxBodyAngle/3.60, endingAt: currMaxBodyAngle/3.60, radius: 100, fillColor: .purple, strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 220.0, height: 220.0), bgColor: .clear)
              }
              if prevMaxBodyAngle > currMaxBodyAngle{
                  UIUtilities.addPieChart(to: poseOverlayView, startingAt: currMaxBodyAngle/3.60, endingAt: prevMaxBodyAngle/3.60, radius: 100, fillColor: .gray, strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 10.0, y: 10.0, width: 220.0, height: 220.0), bgColor: .clear)
              }
              UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: 30, fillColor: .clear, strokeColor: .black.withAlphaComponent(0.5), strokeSize: 1.0, rect: CGRect(x: 10.0, y: 10.0, width: 220.0, height: 220.0), bgColor: .clear)
              
               */
              var mirror = false
              if pose.landmark(ofType: PoseLandmarkType.rightHip).position.y > pose.landmark(ofType: PoseLandmarkType.rightAnkle).position.y {
                  mirror = true
              }
              
              UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: 100, fillColor: UIColor(red: 0.63, green: 0.87, blue: 0.85, alpha: 1), strokeColor: UIColor(red: 0.0, green: 0.66, blue: 0.62, alpha: 1), strokeSize: 2.0, rect: CGRect(x: 30.0, y: 10.0, width: 220.0, height: 220.0), center: CGPoint(x: 110, y:160), bgColor: UIColor.white.withAlphaComponent(0.8), mirror: mirror)
               if currMaxBodyAngle >= prevMaxBodyAngle{
                   UIUtilities.addPieChart(to: poseOverlayView, startingAt: prevMaxBodyAngle/3.60, endingAt: currMaxBodyAngle/3.60, radius: 100, fillColor: UIColor(red: 0.0, green: 0.66, blue: 0.62, alpha: 1), strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 30.0, y: 10.0, width: 220.0, height: 220.0), center: CGPoint(x: 110, y:160), bgColor: .clear, mirror: mirror)
               }
               if prevMaxBodyAngle > currMaxBodyAngle{
                   UIUtilities.addPieChart(to: poseOverlayView, startingAt: currMaxBodyAngle/3.60, endingAt: prevMaxBodyAngle/3.60, radius: 100, fillColor: .gray, strokeColor: .clear, strokeSize: 0.0, rect: CGRect(x: 30.0, y: 10.0, width: 220.0, height: 220.0), center: CGPoint(x: 110, y:160), bgColor: .clear, mirror: mirror)
               }
               UIUtilities.addPieChart(to: poseOverlayView, startingAt: 0, endingAt: currMaxBodyAngle/3.60, radius: 30, fillColor: .clear, strokeColor: .black.withAlphaComponent(0.5), strokeSize: 1.0, rect: CGRect(x: 30.0, y: 10.0, width: 220.0, height: 220.0), center: CGPoint(x: 110, y:160), bgColor: .clear, mirror: mirror)
               
              
              UIUtilities.addLabel(atPoint: CGPoint(x: 140.0, y: 50.0), to: poseOverlayView, color: .black, text: "Max body angle:", width: 220, bgColor: .clear)
              UIUtilities.addLabel(atPoint: CGPoint(x: 140.0, y: 185.0), to: poseOverlayView, color: .black, text: Int(currMaxBodyAngle).description + "°", width: 50, bgColor: .clear)
              
              
              
            if (legsAngle > 160 && bodyAngle > 90 && bodyAngle < 150) {
                //End of stroke
                if isStart && elapsedTime > 1 && elapsedTime < 5{
                    strokeCount += 1
                    if last3Times.count == 3{
                        last3Times.removeFirst()
                    }
                    last3Times.append(elapsedTime)
                    
                    strokeRate = 60 / (last3Times.reduce(0, +) / CGFloat(last3Times.count))
                    
                    
                    updateAnglesGraph(time: Double(strokeCount), minAngle: Double(currMinBodyAngle), maxAngle: Double(currMaxBodyAngle))
                    updateDriveSpeedGraph(time: Double(strokeCount), currDriveSpeed: Double(elapsedTime))
                    updateStrokeRateGraph(time: Double(strokeCount), currStrokeRate: Double(strokeRate))
                    self.timesLabel.text = "Time per stroke: " + String(elapsedTime)
                
                    self.strokeRateLabel.text = "Strokes per minute: " + String(Double(strokeRate))
                    
                    self.anglesLabel.text = "Min Angle: " + String(Int(currMinBodyAngle)) + " Max Angle: " + String(Int(currMaxBodyAngle)) + " Angle at 90: " + String(Int(angleAt90))
                    
                    
                    currMinBodyAngle = 370.0
                    prevMaxBodyAngle = currMaxBodyAngle
                    currMaxBodyAngle = 0.0
                    
            
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
                        driveLengthLabel.textColor = UIColor.red
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
              
            
              
            if(legsAngle + 20 < previousLegsAngle && !isGrowing){
                elapsedTime = CACurrentMediaTime() - startTime;
                elapsedTime = round(elapsedTime * 100) / 100.0
                startTime = CACurrentMediaTime()
                isGrowing = true
            }
            if(legsAngle - 20 > previousLegsAngle && isGrowing){
                isGrowing = false
            }
            if(isGrowing && legsAngle < previousLegsAngle){
                startPos = pose.landmark(ofType: PoseLandmarkType.rightWrist).position.x
                previousLegsAngle = legsAngle
            }
            if(!isGrowing && legsAngle > previousLegsAngle){
                
                endPos = pose.landmark(ofType: PoseLandmarkType.rightWrist).position.x
                previousLegsAngle = legsAngle
            }
            
            
          strongSelf.removeDetectionAnnotations()
          strongSelf.annotationOverlayView.addSubview(poseOverlayView)
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
    
    

        
    
    // Adds a new drive speed measurement to the graph of drive speed
    func updateDriveSpeedGraph(time: Double, currDriveSpeed : Double) {
        // update driveSpeeds array to contain at most driveSpeedCounts data points
        if (times.count >= timesCount) {
            times.removeFirst(1)
        }
        times.append(ChartDataEntry(x: time, y: currDriveSpeed))
        
        // update graph
        let line1 = LineChartDataSet(entries: times, label: "Number")
        let data = LineChartData()
        data.append(line1)
        timesGraph.data = data
    }
    
    func updateAnglesGraph(time: Double, minAngle : Double, maxAngle : Double) {
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
        let line1 = LineChartDataSet(entries: minAngles, label: "Number")
        let line2 = LineChartDataSet(entries: maxAngles, label: "Number")
        let data = LineChartData()
        data.append(line1)
        data.append(line2)
        anglesGraph.data = data
    }

    // Adds a computed stroke rate to the graph of stroke rates
    func updateStrokeRateGraph(time: Double, currStrokeRate : Double) {
        // update strokeRate array to contain at most strokeRateCount data points
        if (strokeRates.count >= strokeRateCounts) {
            strokeRates.removeFirst(1)
        }
        strokeRates.append(ChartDataEntry(x: time, y: currStrokeRate))
        
        // update graph
        let line1 = LineChartDataSet(entries: strokeRates, label: "Number")
        let data = LineChartData()
        data.append(line1)
        strokeRateGraph.data = data
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
