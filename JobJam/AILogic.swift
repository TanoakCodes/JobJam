import Foundation

class AILogic {
    static func getEmbedding(_ sentence: String) async -> [Double] {
        let url = URL(string: "https://api-inference.huggingface.co/models/intfloat/e5-large-v2")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer huggingFaceToken", forHTTPHeaderField: "Authorization") // wont show real api key here
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = """
        {
            "inputs": "\(sentence)"
        }
        """
        
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let embeddings = try JSONSerialization.jsonObject(with: data) as? [[Double]] {
                return embeddings.first ?? []
            }
            return []
        } catch {
            return []
        }
    }
}
