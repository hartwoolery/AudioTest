
import UIKit
import AudioKit


class ViewController: UIViewController {

	private var recordUrl:URL?
	private var isRecording:Bool = false
	
	public var player:AKPlayer?
	private let format = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: 44100, channels: 2, interleaved: true)!
	
	private var amplitudeTracker:AKAmplitudeTracker?
	private var boostedMic:AKBooster?
	private var mic:AKMicrophone?
	private var micMixer:AKMixer?
	private var silence:AKBooster?
	public var recorder: AKNodeRecorder?
	
	@IBOutlet weak var recordButton: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		//self.recordUrl = Bundle.main.url(forResource: "sound", withExtension: "caf")
		//self.startAudioPlayback(url: self.recordUrl!)
		self.recordUrl = self.urlForDocument("record.caf")
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func requestMic(completion: @escaping () -> Void) {
		AVAudioSession.sharedInstance().requestRecordPermission({ (granted: Bool) in
			
			if granted { completion()}
		})
	}
	public func switchToMicrophone() {
		stopEngine()
		do {
			try AKSettings.setSession(category: .playAndRecord, with: .allowBluetoothA2DP)
		} catch {
			AKLog("Could not set session category.")
		}
		mic = AKMicrophone()
		micMixer = AKMixer(mic)
		boostedMic = AKBooster(micMixer, gain: 5)
		amplitudeTracker = AKAmplitudeTracker(boostedMic)
		silence = AKBooster(amplitudeTracker, gain: 0)
		AudioKit.output = silence
		startEngine()
	}
	
	@IBAction func startStopRecording(_ sender: Any) {
		self.isRecording = !self.isRecording
		
		if self.isRecording {
			self.startRecording()
			self.recordButton.setTitle("Stop Recording", for: .normal)
		} else {
			self.stopRecording()
			self.recordButton.setTitle("Start Recording", for: .normal)
		}
	}
	
	func startRecording() {
		self.requestMic() {
			self.switchToMicrophone()
			if let url = self.recordUrl {
				do {
				let audioFile = try AKAudioFile(forWriting: url, settings: self.format.settings, commonFormat: .pcmFormatFloat64, interleaved: true)

				self.recorder = try AKNodeRecorder(node: self.micMixer, file: audioFile)

				try self.recorder?.reset()
				try self.recorder?.record()
				} catch {
					print("error setting up recording", error)
				}
			}
		}
	}
	
	func stopRecording() {
		recorder?.stop()
		startAudioPlayback(url: self.recordUrl!)
	}
	
	@IBAction func saveToDisk(_ sender: Any) {
		if let source = self.player, let saveUrl = self.urlForDocument("pitchAudio.caf") {
			do {
				source.stop()
				
				let audioFile = try AKAudioFile(forWriting: saveUrl, settings: self.format.settings, commonFormat: .pcmFormatFloat64, interleaved: true)
				try AudioKit.renderToFile(audioFile, duration: source.duration, prerender: {
					source.play()
				})
				print("audio file rendered")
				
			} catch {
				print("error rendering", error)
			}
			
			// PROBLEM STARTS HERE //
			
			self.startAudioPlayback(url: self.recordUrl!)
			
		}
	}
	
	public func startAudioPlayback(url:URL) {
		print("loading playback audio", url)
		self.stopEngine()
		
		do {
			try AKSettings.setSession(category: .playback)
			player = AKPlayer.init()
			try player?.load(url: url)
		}
		catch {
			print("error setting up audio playback", error)
			return
		}
		
		player?.prepare()
		player?.isLooping = true
		self.setPitch(pitch: self.getPitch(), saveValue: false)
		AudioKit.output = player
		
		
		startEngine()
		startPlayer()
	}
	
	
	public func startPlayer() {
		if AudioKit.engine.isRunning { self.player?.play() }
		else { print("audio engine not running, can't play") }
	}
	
	public func startEngine() {
		if !AudioKit.engine.isRunning {
			print("starting engine")
			do { try AudioKit.start() }
			catch {
				print("error starting audio", error)
			}
		}
	}
	
	public func stopEngine(){
		
		if AudioKit.engine.isRunning {
			print("stopping engine")
			do {
				try AudioKit.stop()
				
			}
			catch {
				print("error stopping audio", error)
			}
		}
		//AudioKit.output = nil
		
		player = nil
		mic = nil
		recorder = nil
		micMixer = nil
		boostedMic = nil
		amplitudeTracker = nil
		silence = nil
		player = nil
	}
	
	@IBAction func changePitch(_ sender: UISlider) {
		self.setPitch(pitch:Double(sender.value))
	}
	
	public func getPitch() -> Double {
		return UserDefaults.standard.double(forKey: "pitchFactor")
	}
	
	public func setPitch(pitch:Double, saveValue:Bool = true) {
		player?.pitch = pitch * 1000.0
		if saveValue {
			UserDefaults.standard.set(pitch, forKey: "pitchFactor")
			UserDefaults.standard.synchronize()
		}
	}
	
	func urlForDocument(_ named:String) -> URL? {
		let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
		let url = NSURL(fileURLWithPath: path)
		if let pathComponent = url.appendingPathComponent(named) {
			return pathComponent
		}
		return nil
	}

}

