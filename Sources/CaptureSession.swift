//
// Copyright (C) 2015 CosmicMind, Inc. <http://cosmicmind.io> 
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program located at the root of the software package
// in a file called LICENSE.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AVFoundation

private var CaptureSessionAdjustingExposureContext: UInt8 = 1

public enum CaptureSessionPreset {
	case PresetPhoto
	case PresetHigh
	case PresetMedium
	case PresetLow
	case Preset352x288
	case Preset640x480
	case Preset1280x720
	case Preset1920x1080
	case Preset3840x2160
	case PresetiFrame960x540
	case PresetiFrame1280x720
	case PresetInputPriority
}

/**
	:name:	CaptureSessionPresetToString
*/
public func CaptureSessionPresetToString(preset: CaptureSessionPreset) -> String {
	switch preset {
	case .PresetPhoto:
		return AVCaptureSessionPresetPhoto
	case .PresetHigh:
		return AVCaptureSessionPresetHigh
	case .PresetMedium:
		return AVCaptureSessionPresetMedium
	case .PresetLow:
		return AVCaptureSessionPresetLow
	case .Preset352x288:
		return AVCaptureSessionPreset352x288
	case .Preset640x480:
		return AVCaptureSessionPreset640x480
	case .Preset1280x720:
		return AVCaptureSessionPreset1280x720
	case .Preset1920x1080:
		return AVCaptureSessionPreset1920x1080
	case .Preset3840x2160:
		if #available(iOS 9.0, *) {
			return AVCaptureSessionPreset3840x2160
		} else {
			return AVCaptureSessionPresetHigh
		}
	case .PresetiFrame960x540:
		return AVCaptureSessionPresetiFrame960x540
	case .PresetiFrame1280x720:
		return AVCaptureSessionPresetiFrame1280x720
	case .PresetInputPriority:
		return AVCaptureSessionPresetInputPriority
	}
}

@objc(CaptureSessionDelegate)
public protocol CaptureSessionDelegate {
	/**
	:name:	captureSessionFailedWithError
	*/
	optional func captureSessionFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureSessionDidSwitchCameras
	*/
	optional func captureSessionDidSwitchCameras(capture: CaptureSession, position: AVCaptureDevicePosition)
	
	/**
	:name:	captureSessionWillSwitchCameras
	*/
	optional func captureSessionWillSwitchCameras(capture: CaptureSession, position: AVCaptureDevicePosition)
	
	/**
	:name:	captureStillImageAsynchronously
	*/
	optional func captureStillImageAsynchronously(capture: CaptureSession, image: UIImage)
	
	/**
	:name:	captureStillImageAsynchronouslyFailedWithError
	*/
	optional func captureStillImageAsynchronouslyFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureCreateMovieFileFailedWithError
	*/
	optional func captureCreateMovieFileFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureMovieFailedWithError
	*/
	optional func captureMovieFailedWithError(capture: CaptureSession, error: NSError)
	
	/**
	:name:	captureDidStartRecordingToOutputFileAtURL
	*/
	optional func captureDidStartRecordingToOutputFileAtURL(capture: CaptureSession, captureOutput: AVCaptureFileOutput, fileURL: NSURL, fromConnections connections: [AnyObject])
	
	/**
	:name:	captureDidFinishRecordingToOutputFileAtURL
	*/
	optional func captureDidFinishRecordingToOutputFileAtURL(capture: CaptureSession, captureOutput: AVCaptureFileOutput, outputFileURL: NSURL, fromConnections connections: [AnyObject], error: NSError!)
}

@objc(CaptureSession)
public class CaptureSession : NSObject, AVCaptureFileOutputRecordingDelegate {
	/**
	:name:	sessionQueue
	*/
	private lazy var sessionQueue: dispatch_queue_t = dispatch_queue_create("io.materialkit.CaptureSession", DISPATCH_QUEUE_SERIAL)
	
	/**
	:name:	activeVideoInput
	*/
	private var activeVideoInput: AVCaptureDeviceInput?
	
	/**
	:name:	activeAudioInput
	*/
	private var activeAudioInput: AVCaptureDeviceInput?
	
	/**
	:name:	imageOutput
	*/
	private lazy var imageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
	
	/**
	:name:	movieOutput
	*/
	private lazy var movieOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
	
	/**
	:name:	movieOutputURL
	*/
	private var movieOutputURL: NSURL?
	
	/**
	:name: session
	*/
	internal lazy var session: AVCaptureSession = AVCaptureSession()
	
	/**
	:name:	isRunning
	*/
	public private(set) lazy var isRunning: Bool = false
	
	/**
	:name:	isRecording
	*/
	public private(set) lazy var isRecording: Bool = false
	
	/**
	:name:	recordedDuration
	*/
	public var recordedDuration: CMTime {
		return movieOutput.recordedDuration
	}
	
	/**
	:name:	activeCamera
	*/
	public var activeCamera: AVCaptureDevice? {
		return activeVideoInput?.device
	}
	
	/**
	:name:	inactiveCamera
	*/
	public var inactiveCamera: AVCaptureDevice? {
		var device: AVCaptureDevice?
		if 1 < cameraCount {
			if activeCamera?.position == .Back {
				device = cameraWithPosition(.Front)
			} else {
				device = cameraWithPosition(.Back)
			}
		}
		return device
	}
	
	/**
	:name:	cameraCount
	*/
	public var cameraCount: Int {
		return AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
	}
	
	/**
	:name:	canSwitchCameras
	*/
	public var canSwitchCameras: Bool {
		return 1 < cameraCount
	}
	
	/**
	:name:	caneraSupportsTapToFocus
	*/
	public var cameraSupportsTapToFocus: Bool {
		return nil == activeCamera ? false : activeCamera!.focusPointOfInterestSupported
	}
	
	/**
	:name:	cameraSupportsTapToExpose
	*/
	public var cameraSupportsTapToExpose: Bool {
		return nil == activeCamera ? false : activeCamera!.exposurePointOfInterestSupported
	}
	
	/**
	:name:	cameraHasFlash
	*/
	public var cameraHasFlash: Bool {
		return nil == activeCamera ? false : activeCamera!.hasFlash
	}
	
	/**
	:name:	cameraHasTorch
	*/
	public var cameraHasTorch: Bool {
		return nil == activeCamera ? false : activeCamera!.hasTorch
	}
	
	/**
	:name:	cameraPosition
	*/
	public var cameraPosition: AVCaptureDevicePosition? {
		return activeCamera?.position
	}
	
	/**
	:name:	focusMode
	*/
	public var focusMode: AVCaptureFocusMode {
		get {
			return activeCamera!.focusMode
		}
		set(value) {
			var error: NSError?
			if isFocusModeSupported(focusMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.focusMode = value
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported focusMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	flashMode
	*/
	public var flashMode: AVCaptureFlashMode {
		get {
			return activeCamera!.flashMode
		}
		set(value) {
			var error: NSError?
			if isFlashModeSupported(flashMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.flashMode = value
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported flashMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	torchMode
	*/
	public var torchMode: AVCaptureTorchMode {
		get {
			return activeCamera!.torchMode
		}
		set(value) {
			var error: NSError?
			if isTorchModeSupported(torchMode) {
				do {
					let device: AVCaptureDevice = activeCamera!
					try device.lockForConfiguration()
					device.torchMode = value
					device.unlockForConfiguration()
				} catch let e as NSError {
					error = e
				}
			} else {
				error = NSError(domain: "[MaterialKit Error: Unsupported torchMode.]", code: 0, userInfo: nil)
			}
			if let e: NSError = error {
				delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	sessionPreset
	*/
	public var sessionPreset: CaptureSessionPreset {
		didSet {
			session.sessionPreset = CaptureSessionPresetToString(sessionPreset)
		}
	}
	
	/**
	:name:	sessionPreset
	*/
	public var currentVideoOrientation: AVCaptureVideoOrientation {
		var orientation: AVCaptureVideoOrientation
		switch UIDevice.currentDevice().orientation {
		case .Portrait:
			orientation = .Portrait
		case .LandscapeRight:
			orientation = .LandscapeLeft
		case .PortraitUpsideDown:
			orientation = .PortraitUpsideDown
		default:
			orientation = .LandscapeRight
		}
		return orientation
	}
	
	/**
	:name:	delegate
	*/
	public weak var delegate: CaptureSessionDelegate?
	
	/**
	:name:	init
	*/
	public override init() {
		sessionPreset = .PresetHigh
		super.init()
		prepareSession()
	}
	
	/**
	:name:	startSession
	*/
	public func startSession() {
		if !isRunning {
			dispatch_async(sessionQueue) {
				self.session.startRunning()
			}
		}
	}
	
	/**
	:name:	startSession
	*/
	public func stopSession() {
		if isRunning {
			dispatch_async(sessionQueue) {
				self.session.stopRunning()
			}
		}
	}
	
	/**
	:name:	switchCameras
	*/
	public func switchCameras() {
		if canSwitchCameras {
			do {
				if let v: AVCaptureDevicePosition = self.cameraPosition {
					self.delegate?.captureSessionWillSwitchCameras?(self, position: v)
					let videoInput: AVCaptureDeviceInput? = try AVCaptureDeviceInput(device: self.inactiveCamera!)
					self.session.beginConfiguration()
					self.session.removeInput(self.activeVideoInput)
					
					if self.session.canAddInput(videoInput) {
						self.session.addInput(videoInput)
						self.activeVideoInput = videoInput
					} else {
						self.session.addInput(self.activeVideoInput)
					}
					self.session.commitConfiguration()
					self.delegate?.captureSessionDidSwitchCameras?(self, position: self.cameraPosition!)
				}
			} catch let e as NSError {
				self.delegate?.captureSessionFailedWithError?(self, error: e)
			}
		}
	}
	
	/**
	:name:	isFocusModeSupported
	*/
	public func isFocusModeSupported(focusMode: AVCaptureFocusMode) -> Bool {
		return activeCamera!.isFocusModeSupported(focusMode)
	}
	
	/**
	:name:	isExposureModeSupported
	*/
	public func isExposureModeSupported(exposureMode: AVCaptureExposureMode) -> Bool {
		return activeCamera!.isExposureModeSupported(exposureMode)
	}
	
	/**
	:name:	isFlashModeSupported
	*/
	public func isFlashModeSupported(flashMode: AVCaptureFlashMode) -> Bool {
		return activeCamera!.isFlashModeSupported(flashMode)
	}
	
	/**
	:name:	isTorchModeSupported
	*/
	public func isTorchModeSupported(torchMode: AVCaptureTorchMode) -> Bool {
		return activeCamera!.isTorchModeSupported(torchMode)
	}
	
	/**
	:name:	focusAtPoint
	*/
	public func focusAtPoint(point: CGPoint) {
		var error: NSError?
		if cameraSupportsTapToFocus && isFocusModeSupported(.AutoFocus) {
			do {
				let device: AVCaptureDevice = activeCamera!
				try device.lockForConfiguration()
				device.focusPointOfInterest = point
				device.focusMode = .AutoFocus
				device.unlockForConfiguration()
			} catch let e as NSError {
				error = e
			}
		} else {
			error = NSError(domain: "[MaterialKit Error: Unsupported focusAtPoint.]", code: 0, userInfo: nil)
		}
		if let e: NSError = error {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	exposeAtPoint
	*/
	public func exposeAtPoint(point: CGPoint) {
		var error: NSError?
		if cameraSupportsTapToExpose && isExposureModeSupported(.ContinuousAutoExposure) {
			do {
				let device: AVCaptureDevice = activeCamera!
				try device.lockForConfiguration()
				device.exposurePointOfInterest = point
				device.exposureMode = .ContinuousAutoExposure
				if device.isExposureModeSupported(.Locked) {
					device.addObserver(self, forKeyPath: "adjustingExposure", options: .New, context: &CaptureSessionAdjustingExposureContext)
				}
				device.unlockForConfiguration()
			} catch let e as NSError {
				error = e
			}
		} else {
			error = NSError(domain: "[MaterialKit Error: Unsupported exposeAtPoint.]", code: 0, userInfo: nil)
		}
		if let e: NSError = error {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	observeValueForKeyPath
	*/
	public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == &CaptureSessionAdjustingExposureContext {
			let device: AVCaptureDevice = object as! AVCaptureDevice
			if !device.adjustingExposure && device.isExposureModeSupported(.Locked) {
				object!.removeObserver(self, forKeyPath: "adjustingExposure", context: &CaptureSessionAdjustingExposureContext)
				dispatch_async(dispatch_get_main_queue()) {
					do {
						try device.lockForConfiguration()
						device.exposureMode = .Locked
						device.unlockForConfiguration()
					} catch let e as NSError {
						self.delegate?.captureSessionFailedWithError?(self, error: e)
					}
				}
			}
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
	
	/**
	:name:	resetFocusAndExposureModes
	*/
	public func resetFocusAndExposureModes() {
		let device: AVCaptureDevice = activeCamera!
		let canResetFocus: Bool = device.focusPointOfInterestSupported && device.isFocusModeSupported(.ContinuousAutoFocus)
		let canResetExposure: Bool = device.exposurePointOfInterestSupported && device.isExposureModeSupported(.ContinuousAutoExposure)
		let centerPoint: CGPoint = CGPointMake(0.5, 0.5)
		do {
			try device.lockForConfiguration()
			if canResetFocus {
				device.focusMode = .ContinuousAutoFocus
				device.focusPointOfInterest = centerPoint
			}
			if canResetExposure {
				device.exposureMode = .ContinuousAutoExposure
				device.exposurePointOfInterest = centerPoint
			}
			device.unlockForConfiguration()
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	captureStillImage
	*/
	public func captureStillImage() {
		dispatch_async(sessionQueue) {
			if let v: AVCaptureConnection = self.imageOutput.connectionWithMediaType(AVMediaTypeVideo) {
				v.videoOrientation = self.currentVideoOrientation
				self.imageOutput.captureStillImageAsynchronouslyFromConnection(v) { (sampleBuffer: CMSampleBuffer!, error: NSError!) -> Void in
					if nil == error {
						let data: NSData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
						self.delegate?.captureStillImageAsynchronously?(self, image: UIImage(data: data)!)
					} else {
						self.delegate?.captureStillImageAsynchronouslyFailedWithError?(self, error: error!)
					}
				}
			}
		}
	}
	
	/**
	:name:	startRecording
	*/
	public func startRecording() {
		if !isRecording {
			dispatch_async(sessionQueue) {
				if let v: AVCaptureConnection = self.movieOutput.connectionWithMediaType(AVMediaTypeVideo) {
					v.videoOrientation = self.currentVideoOrientation
					v.preferredVideoStabilizationMode = .Auto
				}
				if let v: AVCaptureDevice = self.activeCamera {
					if v.smoothAutoFocusSupported {
						do {
							try v.lockForConfiguration()
							v.smoothAutoFocusEnabled = true
							v.unlockForConfiguration()
						} catch let e as NSError {
							self.delegate?.captureSessionFailedWithError?(self, error: e)
						}
					}
					
					self.movieOutputURL = self.uniqueURL()
					if let v: NSURL = self.movieOutputURL {
						self.movieOutput.startRecordingToOutputFileURL(v, recordingDelegate: self)
					}
				}
			}
		}
	}
	
	/**
	:name:	stopRecording
	*/
	public func stopRecording() {
		if isRecording {
			movieOutput.stopRecording()
		}
	}
	
	/**
	:name:	captureOutput
	*/
	public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
		isRecording = true
		delegate?.captureDidStartRecordingToOutputFileAtURL?(self, captureOutput: captureOutput, fileURL: fileURL, fromConnections: connections)
	}
	
	/**
	:name:	captureOutput
	*/
	public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
		isRecording = false
		delegate?.captureDidFinishRecordingToOutputFileAtURL?(self, captureOutput: captureOutput, outputFileURL: outputFileURL, fromConnections: connections, error: error)
	}
	
	/**
	:name:	prepareSession
	*/
	private func prepareSession() {
		prepareVideoInput()
		prepareAudioInput()
		prepareImageOutput()
		prepareMovieOutput()
	}
	
	/**
	:name:	prepareVideoInput
	*/
	private func prepareVideoInput() {
		do {
			activeVideoInput = try AVCaptureDeviceInput(device: AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo))
			if session.canAddInput(activeVideoInput) {
				session.addInput(activeVideoInput)
			}
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	prepareAudioInput
	*/
	private func prepareAudioInput() {
		do {
			activeAudioInput = try AVCaptureDeviceInput(device: AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio))
			if session.canAddInput(activeAudioInput) {
				session.addInput(activeAudioInput)
			}
		} catch let e as NSError {
			delegate?.captureSessionFailedWithError?(self, error: e)
		}
	}
	
	/**
	:name:	prepareImageOutput
	*/
	private func prepareImageOutput() {
		if session.canAddOutput(imageOutput) {
			imageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
			session.addOutput(imageOutput)
		}
	}
	
	/**
	:name:	prepareMovieOutput
	*/
	private func prepareMovieOutput() {
		if session.canAddOutput(movieOutput) {
			session.addOutput(movieOutput)
		}
	}
	
	/**
	:name:	cameraWithPosition
	*/
	private func cameraWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
		let devices: Array<AVCaptureDevice> = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! Array<AVCaptureDevice>
		for device in devices {
			if device.position == position {
				return device
			}
		}
		return nil
	}
	
	/**
	:name:	uniqueURL
	*/
	private func uniqueURL() -> NSURL? {
		do {
			let directory: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
			let dateFormatter = NSDateFormatter()
			dateFormatter.dateStyle = .FullStyle
			dateFormatter.timeStyle = .FullStyle
			return directory.URLByAppendingPathComponent(dateFormatter.stringFromDate(NSDate()) + ".mov")
		} catch let e as NSError {
			delegate?.captureCreateMovieFileFailedWithError?(self, error: e)
		}
		return nil
	}
}
