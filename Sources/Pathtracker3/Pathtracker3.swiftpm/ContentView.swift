import SwiftUI
import CoreMotion

// MARK: - PathTrackerManager
class PathTrackerManager: NSObject, ObservableObject {
    // Motion Manager
    private let motionManager = CMMotionManager()
    
    // Sensor Data Properties
    @Published var pathData: [CGPoint] = []
    @Published var stepCount: Int = 0
    private var accelerationData: CMAcceleration?
    private var currentHeading: Double = 0.0 // In radians
    
    // State Management
    @Published var isTracking = false
    private var timer: Timer?
    
    // Step Detection Parameters
    private let stepThreshold: Double = 0.05 // Adjust as needed
    private let averageStepSize: CGFloat = 0.5 // Average step size in meters (adjust as needed)
    
    // Debug Mode Flag
    private let debugMode = true
    
    override init() {
        super.init()
    }
    
    // MARK: - Sensor Setup
    private func setupSensors() {
        // Configure Accelerometer
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                self.accelerationData = data.acceleration
            }
        } else {
            print("Accelerometer not available.")
        }
        
        // Configure Device Motion for Heading
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                self.currentHeading = data.heading * (.pi / 180) // Convert degrees to radians
            }
        } else {
            print("Device Motion not available.")
        }
    }
    
    // MARK: - Real-Time Path Updates
    private func startRealTimeUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.processSensorData()
        }
        if debugMode {
            print("Real-time updates started.")
        }
    }
    
    private func stopRealTimeUpdates() {
        timer?.invalidate()
        timer = nil
        if debugMode {
            print("Real-time updates stopped.")
        }
    }
    
    private func processSensorData() {
        guard let acceleration = accelerationData else { return }
        
        // Detect Step Based on y-axis acceleration changes
        if abs(acceleration.y) > stepThreshold {
            // Use currentHeading for direction
            let direction = currentHeading
            
            // Use the average step size for plotting
            let stepSize = averageStepSize
            
            // Update path data with the calculated step size and direction
            let lastPoint = pathData.last ?? CGPoint(x: 0, y: 0)
            let newX = lastPoint.x + cos(direction) * stepSize
            let newY = lastPoint.y + sin(direction) * stepSize
            let newPoint = CGPoint(x: newX, y: newY)
            
            // Add new data point to path
            DispatchQueue.main.async {
                self.pathData.append(newPoint)
                self.stepCount += 1
                
                if self.debugMode {
                    print("Step detected. Y-axis acceleration: \(acceleration.y)")
                    print("New point added. Total points: \(self.pathData.count)")
                }
            }
        }
    }
    
    // MARK: - Start and Stop Tracking
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        setupSensors()
        startRealTimeUpdates()
        if debugMode {
            print("Tracking started.")
        }
    }
    
    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
        stopRealTimeUpdates()
        if debugMode {
            print("Tracking stopped.")
        }
    }
    
    // MARK: - Reset Path Data
    func resetPathData() {
        pathData.removeAll()
        stepCount = 0
        if debugMode {
            print("Path data reset.")
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var pathTracker = PathTrackerManager()
    
    var body: some View {
        VStack {
            // Path Plot
            PathView(pathData: pathTracker.pathData)
                .border(Color.gray, width: 1)
                .padding()
                .frame(height: 300) // Adjust height as needed
            
            // Step Count Display
            Text("Steps: \(pathTracker.stepCount)")
                .font(.headline)
                .padding()
            
            Spacer()
            
            // Control Buttons
            HStack {
                Button(action: { pathTracker.startTracking() }) {
                    Text("Start")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background((!pathTracker.isTracking) ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(pathTracker.isTracking)
                
                Button(action: { pathTracker.stopTracking() }) {
                    Text("Stop")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(pathTracker.isTracking ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!pathTracker.isTracking)
                
                Button(action: { pathTracker.resetPathData() }) {
                    Text("Reset")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - PathView for Visual Plot
struct PathView: View {
    let pathData: [CGPoint]
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let (scaledPath, _) = self.scaledPath(in: size)
            
            Path { path in
                guard let firstPoint = scaledPath.first else { return }
                path.move(to: firstPoint)
                
                for point in scaledPath.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
    
    private func scaledPath(in size: CGSize) -> ([CGPoint], CGFloat) {
        guard !pathData.isEmpty else { return ([], 1.0) }
        
        // Calculate the bounding box of the path data
        let xs = pathData.map { $0.x }
        let ys = pathData.map { $0.y }
        
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        
        let dataWidth = maxX - minX
        let dataHeight = maxY - minY
        
        // Determine the scaling factor to fit the path within the view
        let scaleX = size.width / (dataWidth != 0 ? dataWidth : 1)
        let scaleY = size.height / (dataHeight != 0 ? dataHeight : 1)
        
        let scale = min(scaleX, scaleY) * 0.9 // Add padding by scaling down a bit
        
        // Center the path within the view
        let offsetX = (size.width - dataWidth * scale) / 2
        let offsetY = (size.height - dataHeight * scale) / 2
        
        // Scale and translate the path data
        let scaledPath = pathData.map { point -> CGPoint in
            let x = (point.x - minX) * scale + offsetX
            let y = size.height - ((point.y - minY) * scale + offsetY)
            return CGPoint(x: x, y: y)
        }
        
        return (scaledPath, scale)
    }
}
