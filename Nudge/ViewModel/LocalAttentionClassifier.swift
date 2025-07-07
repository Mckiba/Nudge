import Foundation
import CoreML
import CreateML
import Vision

class LocalAttentionClassifier: ObservableObject {
    private var attentionModel: MLModel?
    private var isModelLoaded = false
    
    @Published var modelConfidence: Double = 0.0
    @Published var classificationResult: AttentionClassification = .unknown
    
    init() {
        loadOrCreateModel()
    }
    
    private func loadOrCreateModel() {
        // Check if we have model metadata indicating a previous training session
        if let modelURL = getModelURL(),
           FileManager.default.fileExists(atPath: modelURL.appendingPathExtension("json").path) {
            print("Found existing model metadata, creating new classifier")
        }
        
        // Always create a new model since MLModel persistence is complex
        createInitialModel()
    }
    
    private func createInitialModel() {
        // Create a basic classifier with synthetic data for initialization
        // This will be improved with real data over time
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                let initialData = self?.generateInitialTrainingData() ?? []
                let model = try self?.trainClassifier(with: initialData)
                
                DispatchQueue.main.async {
                    self?.attentionModel = model
                    self?.isModelLoaded = true
                    self?.saveModel()
                    print("Created initial attention classification model")
                }
            } catch {
                print("Failed to create initial model: \(error)")
            }
        }
    }
    
    private func generateInitialTrainingData() -> [AttentionTrainingData] {
        var trainingData: [AttentionTrainingData] = []
        
        // Generate synthetic training data based on known patterns
        // Attentive patterns
        for _ in 0..<50 {
            trainingData.append(AttentionTrainingData(
                eyeOpenness: Float.random(in: 0.4...1.0),
                blinkRate: Double.random(in: 10...25),
                gazeDirection: GazeDirection.center,
                headPose: HeadPose.frontal,
                confidence: Float.random(in: 0.7...1.0),
                isAttentive: true
            ))
        }
        
        // Inattentive patterns
        for _ in 0..<50 {
            trainingData.append(AttentionTrainingData(
                eyeOpenness: Float.random(in: 0.0...0.3),
                blinkRate: Double.random(in: 0...5),
                gazeDirection: [.left, .right, .up, .down].randomElement() ?? .left,
                headPose: [.turnedLeft, .turnedRight, .tilted].randomElement() ?? .turnedLeft,
                confidence: Float.random(in: 0.3...0.8),
                isAttentive: false
            ))
        }
        
        return trainingData
    }
    
    private func trainClassifier(with data: [AttentionTrainingData]) throws -> MLModel? {
        // Convert training data to MLDataTable format
        var eyeOpennessValues: [Float] = []
        var blinkRateValues: [Double] = []
        var gazeDirectionValues: [String] = []
        var headPoseValues: [String] = []
        var confidenceValues: [Float] = []
        var labels: [String] = []
        
        for sample in data {
            eyeOpennessValues.append(sample.eyeOpenness)
            blinkRateValues.append(sample.blinkRate)
            gazeDirectionValues.append(sample.gazeDirection.rawValue)
            headPoseValues.append(sample.headPose.rawValue)
            confidenceValues.append(sample.confidence)
            labels.append(sample.isAttentive ? "attentive" : "inattentive")
        }
        
        let dataTable = try MLDataTable(dictionary: [
            "eyeOpenness": eyeOpennessValues.map { Double($0) },
            "blinkRate": blinkRateValues,
            "gazeDirection": gazeDirectionValues,
            "headPose": headPoseValues,
            "confidence": confidenceValues.map { Double($0) },
            "isAttentive": labels
        ])
        
        let classifier = try MLClassifier(trainingData: dataTable, 
                                        targetColumn: "isAttentive")
        
        return classifier.model
    }
    
    func classifyAttention(from faceMetrics: FaceMetrics) -> AttentionClassification {
        guard isModelLoaded, let model = attentionModel else {
            return fallbackClassification(from: faceMetrics)
        }
        
        do {
            let input = try createModelInput(from: faceMetrics)
            let prediction = try model.prediction(from: input)
            
            return parseModelOutput(prediction)
        } catch {
            print("Model prediction failed: \(error)")
            return fallbackClassification(from: faceMetrics)
        }
    }
    
    private func createModelInput(from faceMetrics: FaceMetrics) throws -> MLFeatureProvider {
        let inputFeatures: [String: Any] = [
            "eyeOpenness": Double(faceMetrics.eyeOpenness),
            "blinkRate": faceMetrics.blinkRate,
            "gazeDirection": faceMetrics.gazeDirection.rawValue,
            "headPose": faceMetrics.headPose.rawValue,
            "confidence": Double(faceMetrics.confidence)
        ]
        
        return try MLDictionaryFeatureProvider(dictionary: inputFeatures)
    }
    
    private func parseModelOutput(_ prediction: MLFeatureProvider) -> AttentionClassification {
        guard let classificationResult = prediction.featureValue(for: "isAttentive")?.stringValue else {
            return .unknown
        }
        
        // Extract confidence if available
        if let confidenceDictionary = prediction.featureValue(for: "isAttentiveProb")?.dictionaryValue {
            for (_, value) in confidenceDictionary {
                let confidence = value.doubleValue
                modelConfidence = confidence
                break
            }
        }
        
        switch classificationResult {
        case "attentive":
            return .attentive
        case "inattentive":
            return .inattentive
        default:
            return .unknown
        }
    }
    
    private func fallbackClassification(from faceMetrics: FaceMetrics) -> AttentionClassification {
        // Use rule-based fallback when ML model is unavailable
        guard faceMetrics.faceDetected else { return .unknown }
        
        let eyeThreshold: Float = 0.3
        let confidenceThreshold: Float = 0.6
        let blinkRateThreshold: Double = 30.0
        
        let isEyesOpen = faceMetrics.eyeOpenness > eyeThreshold
        let isConfident = faceMetrics.confidence > confidenceThreshold
        let isGazeCenter = faceMetrics.gazeDirection == .center
        let isNormalBlinkRate = faceMetrics.blinkRate < blinkRateThreshold
        
        let attentiveScore = [isEyesOpen, isConfident, isGazeCenter, isNormalBlinkRate]
            .map { $0 ? 1 : 0 }
            .reduce(0, +)
        
        modelConfidence = Double(attentiveScore) / 4.0
        
        return attentiveScore >= 3 ? .attentive : .inattentive
    }
    
    func updateModel(with newData: [AttentionTrainingData]) {
        guard !newData.isEmpty else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                // Combine new data with existing if available
                var combinedData = newData
                
                // In a real implementation, you would load existing training data
                // For now, we'll just use the new data
                
                let updatedModel = try self?.trainClassifier(with: combinedData)
                
                DispatchQueue.main.async {
                    self?.attentionModel = updatedModel
                    self?.saveModel()
                    print("Updated attention classification model with \(newData.count) new samples")
                }
            } catch {
                print("Failed to update model: \(error)")
            }
        }
    }
    
    private func saveModel() {
        // Note: MLModel instances created from CreateML classifiers cannot be directly saved
        // In a production app, you would save the MLClassifier itself during training
        // For now, we'll just log that the model is in memory
        print("Attention classification model is loaded in memory")
        
        // Alternative: Save model metadata or training parameters
        if let modelURL = getModelURL() {
            let modelInfo = [
                "model_type": "attention_classifier",
                "created_date": ISO8601DateFormatter().string(from: Date()),
                "version": "1.0"
            ]
            
            do {
                let data = try JSONSerialization.data(withJSONObject: modelInfo)
                try data.write(to: modelURL.appendingPathExtension("json"))
                print("Saved attention classification model metadata")
            } catch {
                print("Failed to save model metadata: \(error)")
            }
        }
    }
    
    private func getModelURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                               in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent("AttentionClassifier")
    }
}

struct AttentionTrainingData {
    let eyeOpenness: Float
    let blinkRate: Double
    let gazeDirection: GazeDirection
    let headPose: HeadPose
    let confidence: Float
    let isAttentive: Bool
}

enum AttentionClassification: String, CaseIterable {
    case attentive = "attentive"
    case inattentive = "inattentive"
    case unknown = "unknown"
    
    var confidence: Double {
        switch self {
        case .attentive, .inattentive:
            return 0.8
        case .unknown:
            return 0.0
        }
    }
}