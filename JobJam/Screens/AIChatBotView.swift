import SwiftUI

struct AIChatBotView: View {
    @State private var textEntry: String = ""
    @State private var responseList: [String] = []
    @State private var isLoading: Bool = false

    var body: some View {
        ZStack {
            Color.aiBack.edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Image(.jobJamLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                    Text("JobBot")
                        .padding(10)
                        .font(.system(size: 40))
                        .bold()
                        .foregroundStyle(.white)
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack {
                            ForEach(responseList, id: \.self) { message in
                                if message.hasPrefix("USER: ") {
                                    userMessageBox(message: String(message.dropFirst(6)))
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                } else if message.hasPrefix("BOT: ") {
                                    responseMessageBox(response: String(message.dropFirst(5)))
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding(10)
                    .onChange(of: responseList) {
                        withAnimation {
                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                textBox(
                    textEntry: $textEntry,
                    isLoading: $isLoading
                ) {
                    sendMessage()
                }
            }
            .hideKeyboardOnTap()
        }
    }

    func sendMessage() {
        let trimmed = textEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let userMessage = "USER: \(trimmed)"
        withAnimation {
            responseList.append(userMessage)
            responseList.append("BOT: ...")
        }

        isLoading = true
        let index = responseList.count - 1
        let prompt = trimmed
        textEntry = ""

        Task {
            let botResponse = try await GeminiAPI().sendPrompt(prompt: prompt)
            withAnimation {
                responseList[index] = "BOT: \(botResponse)"
            }
            isLoading = false
        }
    }
}

#Preview {
    AIChatBotView()
}

struct textBox: View {
    @Binding var textEntry: String
    @Binding var isLoading: Bool
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("ask anything...", text: $textEntry, axis: .vertical)
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .background(Color.white)
                .cornerRadius(25)
                .font(.system(size: 18))
                .disabled(isLoading)
                .foregroundStyle(Color.black)

            SendTextButton(isLoading: isLoading, onSend: onSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.electricy)
        .cornerRadius(30)
        .padding(.horizontal)
    }
}


struct responseMessageBox: View {
    let response: String

    var body: some View {
        ZStack {
            HStack {
                Text(response)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.electricy)
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                    .frame(maxWidth: 250, alignment: .leading)
                Spacer()
            }
        }
    }
}

struct userMessageBox: View {
    let message: String

    var body: some View {
        HStack {
            Spacer()
            Text(message)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray)
                )
                .foregroundColor(.white)
                .font(.system(size: 18))
                .frame(maxWidth: 250, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct SendTextButton: View {
    var isLoading: Bool
    var onSend: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .frame(width: 50, height: 50)
                .foregroundStyle(Color.electricy)
                .padding(.trailing, 10)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: 30, weight: .bold))
                    .offset(x: -2, y: 0)
                    .foregroundStyle(Color.white)
            }
        }
        .onTapGesture {
            if !isLoading {
                UIApplication.shared.hideKeyboard()
                onSend()
            }
        }
    }
}
