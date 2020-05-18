//
//  ViewController.swift
//  imu
//
//  Created by Ishan Chatterjee on 5/16/20.
//  Copyright © 2020 Ishan Chatterjee. All rights reserved.
//

import UIKit
import CoreMotion
import simd

class ViewController: UIViewController {
    
    @IBOutlet weak var accelTiltLabel: UILabel!
    @IBOutlet weak var gyroTiltLabel: UILabel!
    @IBOutlet weak var fusedTiltLabel: UILabel!
    
    var xSecondTimer: Timer?
    var runCount = 0.0
    var collectionTime = 5*60.0 //seconds
    
    var sampleRate = 100.0 // Hz
    
    var accumulatedSensorData = [[Double]]()
    
    var accelTilt = [Double]()                  // contains projection of normalized tilt vector on x, y plane
    var accumulatedAccelTilt = [[Double]]()     // contains all accumlated samples of projections of normalized tilt vector on x, y plane
    var accelTiltAngle: Double?                 // contains just the angle off +g (single value) in degrees
    var accumulatedAccelTiltAngle = [Double]()  // contains all accumlated samples of  just the angle off +g (single value) in degrees
    
    var gyroTilt = [0.0, 0.0]                  // contains projection of normalized tilt vector on x, y plane
    var accumulatedGyroTilt = [[Double]]()      // contains all accumlated samples of projections of normalized tilt vector on x, y plane
    var gyroTiltAngle = 0.0                  // contains just the angle off +g (single value) in degrees
    var accumulatedGyroTiltAngle = [Double]()   // contains all accumlated samples of  just the angle off +g (single value) in degrees

    var fusedTilt = [0.0, 0.0]                 // contains projection of normalized tilt vector on x, y plane
    var accumulatedFusedTilt = [[Double]]()     // contains all accumlated samples of projections of normalized tilt vector on x, y plane
    var fusedTiltAngle = 0.0                    // contains just the angle off +g (single value) in degrees
    var accumulatedFusedTiltAngle = [Double]()  // contains all accumlated samples of  just the angle off +g (single value) in degrees
    
    var alpha = 0.1

    let motionManager = CMMotionManager()

    func startAccelerometers() {
       if self.motionManager.isAccelerometerAvailable {
          self.motionManager.accelerometerUpdateInterval = 1.0 / sampleRate
          self.motionManager.startAccelerometerUpdates()

       }
    }
    
     func startGyros() {
        if motionManager.isGyroAvailable {
           self.motionManager.gyroUpdateInterval = 1.0 / sampleRate
           self.motionManager.startGyroUpdates()
        }
     }
    
    func stopAccelerometers() {
        self.motionManager.stopAccelerometerUpdates()
     }
    
    func stopGyros() {
        self.motionManager.stopGyroUpdates()
     }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        startAccelerometers()
        startGyros()
        
        print("Sensors started")
        
        xSecondTimer = Timer.scheduledTimer(timeInterval: (1.0/sampleRate),
                           target: self,
                           selector: #selector(ViewController.collectXSecondsData),
                           userInfo: nil,
                           repeats: true)
    }
    
    func calculateAccelTilt(sample: [Double]) -> ([Double], Double) {
        let accelVector = simd_double3(x: sample[0], y: sample[1], z: sample[2])
        let accelVectorNormalized = simd_normalize(accelVector)
        let accelVectorProjected = simd_double2(x: accelVectorNormalized.x, y: accelVectorNormalized.y)
        let angle = asin(simd_length(accelVectorProjected))
        
        return ([accelVectorProjected.x, accelVectorProjected.y], angle)
    }
    
    func calculateGyroTiltDelta(sample: [Double]) -> ([Double], Double) {
        let gyroRateVector = simd_double3(x: sample[3], y: sample[4], z: sample[5])
        // -x rotation results in tilt toward +y,   +y rotation result in tilt toward +x direction
        let gyroAngleDeltaVector = (1.0/sampleRate) * simd_double2(x:gyroRateVector.y, y:-1*gyroRateVector.x)
        let angleDelta = simd_length(gyroAngleDeltaVector)
        
        return ([gyroAngleDeltaVector.x, gyroAngleDeltaVector.y], angleDelta)
    }
    
    func calculateFusedTilt(sample: [Double]) {
        let gyroRateVector = simd_double3(x: sample[3], y: sample[4], z: sample[5])
        // -x rotation results in tilt toward +y,   +y rotation result in tilt toward +x direction
        let gyroAngleDeltaVector = (1.0/sampleRate) * simd_double2(x:gyroRateVector.y, y:-1*gyroRateVector.x)
        let angleDelta = simd_length(gyroAngleDeltaVector)
        
        fusedTilt[0] =  alpha * accelTilt[0] + (1 - alpha) * (fusedTilt[0] + gyroAngleDeltaVector.x)
        fusedTilt[1] = alpha * accelTilt[1] + (1 - alpha) * (fusedTilt[1] + gyroAngleDeltaVector.y)
        let fusedTiltAngleLHS = alpha * accelTiltAngle!
        let fusedTiltAngleRHS = (1 - alpha) * (fusedTiltAngle + angleDelta)
        fusedTiltAngle = fusedTiltAngleLHS + fusedTiltAngleRHS
    }
    
    @objc func collectXSecondsData() {
        runCount += 1.0
        
        let sample = readSensors()
        
        //accumulatedSensorData.append(sample)
        if sample.count != 0 {
            (accelTilt, accelTiltAngle) = calculateAccelTilt(sample: sample)
            let (gyroTiltDelta, gyroTiltAngleDelta) = calculateAccelTilt(sample: sample)
            gyroTilt = zip(gyroTilt, gyroTiltDelta).map(+)
            gyroTiltAngle += gyroTiltAngleDelta
            
            calculateFusedTilt(sample: sample)

            // print("accel:", accelTilt, accelTiltAngle!)
            // print("gyro:", gyroTilt, gyroTiltAngle)
            
            //print(accelTiltAngle!, gyroTiltAngle, fusedTiltAngle,";")
            
            accelTiltLabel.text = String(format:"%.3f", accelTiltAngle!)
            gyroTiltLabel.text = String(format:"%.3f", gyroTiltAngle)
            fusedTiltLabel.text = String(format:"%.3f", fusedTiltAngle)
        }

        if runCount == (collectionTime/xSecondTimer!.timeInterval) {
            xSecondTimer?.invalidate()
            //print(accumulatedSensorData)
        }
    }
    
    @objc func readSensors() -> [Double] {
        
        var sample = [Double]()
        
        if let aData = self.motionManager.accelerometerData?.acceleration {
            if let gData = self.motionManager.gyroData?.rotationRate {
                sample.append(aData.x)
                sample.append(aData.y)
                sample.append(aData.z)
                sample.append(gData.x)
                sample.append(gData.y)
                sample.append(gData.z)
            }
        }
        
        return sample
    }
}

