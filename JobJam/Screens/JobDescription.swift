//
//  JobDescription.swift
//  JobJam
//
//  Created by Tanish Srinivas on 7/6/25.
//

import SwiftUI
import FirebaseFirestore

struct JobDescription: View {
    @State private var TextEntry: String = ""
    @State private var embedding: [Double] = []
    
    @State private var isMatching: Bool = false
    
    @State private var showCallScreen: Bool = false
    
    @State private var inQueue: Bool = false
    
    @State private var foundMatch: Bool = false
    @State private var otherUserID: String =  "other User ID"
    @State private var matchID: String =  "match ID"
    let db = Firestore.firestore()
    let userID: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mainBack.edgesIgnoringSafeArea(.all)
                
                VStack{
                    
                    JobDescriptionHeader()
                        .padding(25)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.electricy, lineWidth: 3)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        
                        TextEditor(text: $TextEntry)
                            .padding(8)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.black)
                            .font(.system(size: 23))
                    }
                    .frame(width: 370, height: 300)
                    
                    ProgressView(value: Float(TextEntry.count), total: 400) //up for debate
                        .padding(10)
                    
                    MatchButton(isMatching: $isMatching)
                        .disabled(inQueue || isMatching)
                        .padding(10)
                        .navigationDestination(isPresented: $foundMatch){
                            CallView(userID: userID, otherUserID: otherUserID, channelID: matchID)
                        }
                        .onTapGesture {
                            UIApplication.shared.hideKeyboard()
                            Task{
                                foundMatch = false
                                isMatching = true
                                embedding = await AILogic.getEmbedding(TextEntry)
                                
                                do {
                                    //update user data to have embedding
                                    try await db.collection("users").document(userID).setData([
                                        "embedding": embedding
                                    ], merge: true)
                                    
                                    //add user to queue
                                    try await db.collection("queue").document(userID).setData([
                                        "userID": userID,
                                        "embedding": embedding,
                                        "timestamp": FieldValue.serverTimestamp(),
                                    ])
                                    inQueue = true
                                    startListeningForMatch()
                                    //auto delete after 30 seconds
                                    Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { timer in
                                        Task {
                                            do {
                                                try await db.collection("queue").document(userID).delete()
                                                await MainActor.run {
                                                    inQueue = false
                                                    isMatching = false
                                                }
                                                print("Auto deleted from queue after 30 seconds.")
                                            } catch {
                                                print("Auto delete failed")
                                            }
                                        }
                                    }
                                    
                                } catch {
                                    print("cant add to queue or cant set data")
                                }
                                
                                
                                //match user with another
                                do {
                                    let snapshot = try await db.collection("queue")
                                        .whereField("userID", isNotEqualTo: userID)
                                        .getDocuments()
                                    
                                    let documents = snapshot.documents
                                    
                                    for doc in documents{
                                        
                                        let simScore = cosineSimilarity(vectorA: embedding, vectorB: doc.data()["embedding"] as! [Double])
                                        if simScore > 0.9 {
                                            //perform transaction to try to lock users, delete from queue and add the matches list
                                            let attempt = await tryTransaction(otherUserID: doc.data()["userID"] as! String)
                                            if attempt{
                                                print("match found")
                                                inQueue = false
                                                isMatching = false
                                                break
                                            }
                                            
                                            print("possible match found")
                                        }
                                        isMatching = false
                                    }
                                    
                                } catch {
                                    print("Error getting snapshot")
                                }
                                
                            }
                            
                        }
                    
                    ExitQueueButton()
                        .disabled(!inQueue)
                        .opacity(inQueue ? 1 : 0)
                        .onTapGesture {
                            Task {
                                try await db.collection("queue").document(userID).delete()
                                inQueue = false
                                isMatching = false
                            }
                        }
                    
                }
                .foregroundStyle(Color.white)
                .navigationBarBackButtonHidden(true)
                .hideKeyboardOnTap()
            }
        }
    }
    //compute cosine similarity
    func cosineSimilarity(vectorA: [Double], vectorB: [Double]) -> Double{
        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))
            
        guard magnitudeA != 0 && magnitudeB != 0 else {
            return 0.0
        }
            
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    //run transaction and add document pair to matches collection
    func tryTransaction(otherUserID: String) async -> Bool{
        let userDocRef = db.collection("queue").document(userID)
        let otherUserDocRef = db.collection("queue").document(otherUserID)
        matchID = [userID, otherUserID].sorted().joined(separator: "_")
        
        do {
            let _ = try await db.runTransaction({(transaction, errorPointer) -> Any? in
                do{ //checks if both user docs still exist
                    let mySnapshot = try transaction.getDocument(userDocRef)
                    let otherSnapshot = try transaction.getDocument(otherUserDocRef)

                    guard mySnapshot.exists, otherSnapshot.exists else {
                        throw NSError(domain: "AppError", code: 404, userInfo: [NSLocalizedDescriptionKey: "One or both documents not found"])
                    }
                    
                    transaction.deleteDocument(userDocRef)
                    transaction.deleteDocument(otherUserDocRef)
                    
                    let matchData: [String: Any] = [ // add users to matches collection in single document
                        "userA": userID,
                        "userAVideoMuted" : false,
                        "userB": otherUserID,
                        "userBVideoMuted" : false,
                        "timestamp": FieldValue.serverTimestamp()
                    ]
                    transaction.setData(matchData, forDocument: db.collection("matches").document(matchID))
                    
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return false
                }
                return true
            })
            
            print("transaction worked")
            return true
        } catch {
            print("transaction failed: \(error)")
            return false
        }
        
    }
    
    //to switch alert to switch views once matching document with users inside is created
    func startListeningForMatch() {
        db.collection("matches")
            .whereFilter(Filter.orFilter([
                Filter.whereField("userA", isEqualTo: userID),
                Filter.whereField("userB", isEqualTo: userID)
            ]))
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("No matching documents found for user \(userID)")
                    return
                }

                for doc in documents {
                    let data = doc.data()
                    let userA = data["userA"] as? String ?? ""
                    let userB = data["userB"] as? String ?? ""
                    let id = doc.documentID

                    Task {
                        await MainActor.run {
                            otherUserID = (userA == userID) ? userB : userA
                            matchID = id
                            foundMatch = true
                            print("\(userID) matched with \(otherUserID). Navigating to CallView.")
                        }
                    }
                }
            }
    }


}

#Preview {
    JobDescription(userID: "")
}

struct JobDescriptionHeader: View {
    @State private var height: CGFloat = 50
    @State private var opacity: Double = 0
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.electricy)
                .frame(width: 370, height: height)
            VStack {
                Text("Job Description")
                    .font(.system(size: 40, weight: .bold))
                    .padding(10)
                Text("Please enter or paste your job description below.")
                    .font(.system(size: 23))
                    .opacity(opacity)
                Spacer()
            }
            .frame(width: 370, height: height)
        }
        .onAppear {
            withAnimation(.smooth(duration: 1)){
                self.height = 150
                self.opacity = 1
            }
        }
    }
}

struct MatchButton: View {
    @State private var size: CGFloat = 1
    @Binding var isMatching: Bool
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.electricy)
                .frame(width: 250, height: 80)
            HStack {
                if isMatching {
                    ProgressView()
                        .padding(10)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                Text("Find Match")
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundColor(.white)
            }
            if isMatching {
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 250, height: 80)
            }

        }
        .animation(.easeInOut(duration: 0.2), value: isMatching)
    }
}

struct ExitQueueButton: View {
    @State private var size: CGFloat = 1
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.red)
                .frame(width: 250, height: 80)
            Text("Exit Queue")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(.white)

        }
    }
}

extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

