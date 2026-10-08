import SwiftUI

struct LogExplanationOverlay: View {
    @EnvironmentObject private var presenter: LogExplanationPresenter

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    presenter.dismiss()
                }

            VStack(spacing: 14) {
                if presenter.isLoading {
                    ProgressView()
                        .controlSize(.large)
                    Text(L10n.ru("Ищем ответ", en: "Looking for an answer"))
                        .font(.headline)
                } else {
                    Text(L10n.ru("Что за лог?", en: "What is this log?"))
                        .font(.title3.weight(.semibold))

                    if let error = presenter.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if let text = presenter.text {
                        ScrollView {
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: 460, height: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 28, x: 0, y: 14)
            .contentShape(Rectangle())
            .onTapGesture {}
            .onExitCommand {
                presenter.dismiss()
            }
        }
    }
}
