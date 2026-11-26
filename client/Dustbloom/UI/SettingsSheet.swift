import StoreKit
import SwiftUI
import UIKit

/// Settings: sound volume, a message to the developers with a mood, and a
/// way to rate the game. Opened by the gear in the top bar.
struct SettingsSheet: View {
    @EnvironmentObject private var store: FarmStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dustbloom.volume") private var volume: Double = 0.8
    @State private var mood = 0
    @State private var text = ""
    @State private var state: SendState = .idle
    @FocusState private var typing: Bool

    enum SendState { case idle, sending, sent, failed }

    var body: some View {
        let ru = L.ru
        NavigationStack {
            Form {
                Section(ru ? "Звук" : "Sound") {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $volume, in: 0...1)
                            .onChange(of: volume) { _, v in Sfx.master = Float(v) }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    // mood: five stars, tap again to clear
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                mood = mood == i ? 0 : i
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: i <= mood ? "star.fill" : "star")
                                    .font(.system(size: 24))
                                    .foregroundStyle(i <= mood ? Color.yellow : Color.secondary)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(i)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    TextField(ru ? "Что понравилось, что мешает, идеи…" : "What you like, what bothers you, ideas…",
                              text: $text, axis: .vertical)
                        .lineLimit(4...8)
                        .focused($typing)
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            switch state {
                            case .sending: ProgressView()
                            case .sent: Text(ru ? "Спасибо! Отправлено" : "Thank you! Sent")
                            default: Text(ru ? "Отправить" : "Send")
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state == .sending || state == .sent)
                    if state == .failed {
                        Text(ru ? "Нет связи с сервером, попробуй позже." : "No connection, try again later.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text(ru ? "Написать разработчикам" : "Message the developers")
                } footer: {
                    Text(ru ? "Каждое сообщение читаем. Отвечаем в обновлениях игры." : "We read every message and answer with game updates.")
                }

                Section {
                    Button {
                        Analytics.shared.track("review_manual")
                        requestReview()
                    } label: {
                        Label(ru ? "Оценить игру" : "Rate the game", systemImage: "star.bubble")
                            .frame(minHeight: 44)
                    }
                }

                Section {
                    LabeledContent(ru ? "Версия" : "Version", value: store.appVersion)
                    LabeledContent(ru ? "Сервер" : "Server", value: store.isOnline ? (ru ? "на связи" : "online") : (ru ? "игра без сети" : "offline play"))
                }
            }
            .navigationTitle(ru ? "Настройки" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ru ? "Готово" : "Done") { dismiss() }
                }
            }
        }
        .onAppear { Analytics.shared.track("open_settings") }
    }

    private func send() async {
        typing = false
        state = .sending
        let ok = await store.sendFeedback(text.trimmingCharacters(in: .whitespacesAndNewlines), mood: mood)
        state = ok ? .sent : .failed
        if ok { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}
