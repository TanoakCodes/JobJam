//
//  CallView.swift
//  JobJam
//
//  Created by Tanish Srinivas on 7/17/25.
//
import SwiftUIRtc
import AgoraRtcKit
import SwiftUI
import FirebaseFirestore

struct CallView: View {
    let userID: String
    let otherUserID: String
    let channelID: String
    let db = Firestore.firestore()
    @State private var isMuted: Bool = false
    @State private var isVideoMuted: Bool = false
    
    @State private var otherPersonVideoMuted: Bool = false
    var hashedOtherUserID: UInt {stableHash(otherUserID)}
    
    @ObservedObject var agoraManager = AgoraManagerSubClass(appId: "308406a419af45a492e22ecfc7d073ea", role: .broadcaster)
    @State private  var leftCall: Bool = false
    
    @State private var userAorB: String = "none"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mainBack.ignoresSafeArea()
                VStack{
                    
                    //Text("you: " + userID)
                    //Text("with: " + otherUserID + "their hashed ID: \(hashedOtherUserID)")
                    AgoraGettingStartedView(agoraManager: agoraManager, channelId: channelID, userID: userID, hashedOtherUserID: hashedOtherUserID, leftCall: $leftCall,isVideoMuted: $isVideoMuted, userAorB: $userAorB)
                        .padding(10)
                }
                .navigationBarBackButtonHidden(true)
                
                
                HStack {
                    Image(systemName: "phone.down.circle.fill")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 75, height: 75)
                        .onTapGesture {
                            Task {
                                agoraManager.agoraEngine.leaveChannel()
                                try await db.collection("matches").document(channelID).delete()
                            }
                        }
                        .padding(10)
                    
                    StopVideoButton(isVideoMuted: $isVideoMuted)
                        .onTapGesture {
                            Task {
                                if !isVideoMuted {
                                    // Turn video OFF
                                    agoraManager.agoraEngine.muteLocalVideoStream(true)
                                    if userAorB == "A" {
                                        db.collection("matches").document(channelID).updateData(["userAVideoMuted": true])
                                    } else{
                                        if userAorB == "B" {
                                            db.collection("matches").document(channelID).updateData(["userBVideoMuted": true])
                                        }
                                    }

                                } else {
                                    // Turn video ON
                                    agoraManager.agoraEngine.muteLocalVideoStream(false)
                                    if userAorB == "A" {
                                        db.collection("matches").document(channelID).updateData(["userAVideoMuted": false])
                                    } else{
                                        if userAorB == "B" {
                                            db.collection("matches").document(channelID).updateData(["userBVideoMuted": false])
                                        }
                                    }
                                }
                                isVideoMuted.toggle()
                            }
                        }
                    
                    MuteButton(isMuted: $isMuted)
                        .onTapGesture {
                            Task {
                                if !isMuted {
                                    // Turn mic ON
                                    agoraManager.agoraEngine.muteLocalAudioStream(true)
                                } else {
                                    // Turn mic OFF
                                    agoraManager.agoraEngine.muteLocalAudioStream(false)
                                }
                                isMuted.toggle()
                            }
                        }
                }
                .offset(x: 0, y: 200)
                ChatBotButton()
                    .offset(x: 0, y: 330)
            }
            .navigationDestination(isPresented: $leftCall){
                JobDescription(userID: userID)
            }
        }
        .foregroundStyle(Color.white)
    }
}


struct AgoraGettingStartedView: View {
    let agoraManager: AgoraManagerSubClass
    let channelId: String
    let userID: String
    let db = Firestore.firestore()
    
    let hashedOtherUserID: UInt
    @Binding var leftCall: Bool
    @Binding var isVideoMuted: Bool
    var hashedUserID : UInt {stableHash(userID)}
    
    @Binding var userAorB: String
    
    @State private var token: String = ""
    @State private var userAVideoMuted : Bool = false
    @State private var userBVideoMuted : Bool = false
    var body: some View {
        
        ScrollView {
            VStack {
                ForEach(Array(agoraManager.allUsers), id: \.self) { uid in
                    ZStack {
                        AgoraVideoCanvasView(manager: agoraManager, canvasId: .userId(uid))
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(10)
                        
                        if shouldShowNoVideoScreen(for: uid) {
                            noVideoScreen()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.aiBack)
                        }
                    }
                }

            }.padding(20)
        }.onAppear {
            leftCall = false
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" { //to be able to use in xcode preview wihtout switching screens
                Task {
                    do {
                        
                        Task { // check role
                            if let role = await getUserRole(inMatch: channelId, userID: userID) {
                                userAorB = role
                            } else {
                                userAorB = "none"
                            }
                            print(userAorB)
                        }

                        token = try await fetchToken(tokenType: "rtc", channel: channelId, role: "publisher", uid: "\(hashedUserID)", expire: 3600)
                        print(channelId)
                        agoraManager.agoraEngine.joinChannel(
                            byToken: token, channelId: channelId, info: nil, uid: hashedUserID
                        )
                        
                        db.collection("matches").document(channelId).addSnapshotListener { docSnapshot, error in
                            guard let doc = docSnapshot else { return }
                            if !doc.exists {
                                leftCall = true
                            } else {leftCall = false}
                            
                            userAVideoMuted = doc.data()?["userAVideoMuted"] as? Bool ?? false
                            userBVideoMuted = doc.data()?["userBVideoMuted"] as? Bool ?? false
                        }
                        
                    } catch {print("error fetching token: \(error)")}
                }
            }
            
        }.onDisappear {
            agoraManager.agoraEngine.leaveChannel()
        }

    }
    
    
    func shouldShowNoVideoScreen(for uid: UInt) -> Bool {
        if uid == hashedUserID {
            // Local user
            return userAorB == "A" ? userAVideoMuted : userBVideoMuted
        } else if uid == hashedOtherUserID {
            // Remote user
            return userAorB == "A" ? userBVideoMuted : userAVideoMuted
        } else {
            return false
        }
    }

    func getUserRole(inMatch matchID: String, userID: String) async -> String? {
        let docRef = Firestore.firestore().collection("matches").document(matchID)

        do {
            let snapshot = try await docRef.getDocument()
            guard let data = snapshot.data() else { return nil }

            let userA = data["userA"] as? String
            let userB = data["userB"] as? String

            if userID == userA {
                return "A"
            } else if userID == userB {
                return "B"
            } else {
                return nil
            }
        } catch {
            print("Error fetching match document: \(error)")
            return nil
        }
    }

}


#Preview {
    CallView(userID: "userID", otherUserID: "otherID", channelID: "channel ID")
}

struct requestBody: Encodable {
    let tokenType: String
    let channel: String
    let role: String
    let uid: String
    let expire: Int
}

func fetchToken (tokenType: String, channel: String, role: String, uid: String, expire: Int) async throws -> String {
    guard let url = URL(string: "https://agora-token-server-5u45.onrender.com/getToken") else{
        throw URLError(.badURL)
    }
    
    let requestBody = requestBody(tokenType: tokenType, channel: channel, role: role, uid: uid, expire: expire)
    let bodyData = try JSONEncoder().encode(requestBody)
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = bodyData// Attach JSON body
    
    let (data, _) = try await URLSession.shared.data(for: request) //send request
    
    let decoded = try JSONDecoder().decode(generatedTokenResult.self, from: data)
    
    return decoded.token
}


func stableHash(_ input: String) -> UInt { // String Hasher
    let hash = input.unicodeScalars.map { UInt($0.value) }.reduce(5381 as UInt) {
        ($0 << 5) &+ $0 &+ $1
    }
    return hash % 1_000_000
}



struct generatedTokenResult: Decodable {
    let token: String
}


struct MuteButton: View {
    @Binding var isMuted: Bool

    var body: some View {
        ZStack {
            Circle()
                .frame(width: 75, height: 75)
                .foregroundStyle(isMuted ? .green : .red)
                .animation(.easeInOut(duration: 0.3), value: isMuted)
            
            Image(systemName: isMuted ? "mic.fill" : "mic.slash.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
                .scaleEffect(isMuted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMuted)
        }
        .padding(10)
    }
}

struct StopVideoButton: View {
    @Binding var isVideoMuted: Bool

    var body: some View {
        ZStack {
            Circle()
                .frame(width: 75, height: 75)
                .foregroundStyle(isVideoMuted ? .green : Color.electricy)
                .animation(.easeInOut(duration: 0.3), value: isVideoMuted)
            
            Image(systemName: isVideoMuted ? "video.fill" : "video.slash.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundStyle(.white)
                .scaleEffect(isVideoMuted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVideoMuted)
        }
        .padding(10)
    }
}


struct noVideoScreen: View {
    var body: some View {
        Image(systemName: "video.slash.fill")
            .scaleEffect(3)
    }
}

struct ChatBotButton: View {
    @State private var isPressed : Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 75, height: 75)
                .foregroundColor(.blue)
            Image(.robotIconSymbols)
                .scaleEffect(3)
                .foregroundColor(.white.opacity(0.8))
        }
        .onTapGesture {
            isPressed.toggle()
        }
        .sheet(isPresented: $isPressed) {
            AIChatBotView()
        }
    }
}

