import Foundation
import Combine

@MainActor
final class LogExplanationPresenter: ObservableObject {
    @Published var isPresented = false
    @Published var isLoading = false
    @Published var text: String?
    @Published var error: String?

    func show(logText: String, apiKey: String) {
        text = nil
        error = nil
        isLoading = true
        isPresented = true

        Task {
            do {
                let answer = try await DeepSeekRecommendationService.explainLog(
                    logText: logText,
                    apiKey: apiKey
                )
                text = answer
            } catch let caughtError {
                error = caughtError.localizedDescription
            }
            isLoading = false
        }
    }

    func dismiss() {
        isPresented = false
        isLoading = false
        text = nil
        error = nil
    }

    func showError(_ message: String) {
        isPresented = true
        isLoading = false
        text = nil
        error = message
    }
}
