//
//  LogInScreen.swift
//  JobJam
//
//  Created by Tanish Srinivas on 7/6/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LogInScreen: View {
    @State private var isActive: Bool = false
    
    @State private var buttonPressed: Bool = false
    let db = Firestore.firestore()
    
    //User Data
    @State private var userID: String = "temp"
    @State private var embedding: [Double] = []

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mainBack.edgesIgnoringSafeArea(.all)
                BootupScreen(isActive: $isActive)
                    .offset(y: isActive ? -100 : 0)
                
                VStack{
                    SignInButton(buttonPressed: $buttonPressed)
                        .offset(y: isActive ? 70 : 20)
                        .opacity(isActive ? 1 : 0)
                        .onTapGesture {
                            Auth.auth().signInAnonymously { authResult, error in
                                if let user = authResult?.user {
                                    userID = user.uid
                                    
                                    //create blank document for user
                                    db.collection("users").document(userID).setData([
                                        "userID": userID,
                                        "embedding": embedding,
                                    ]){error in
                                        if error != nil {
                                            print("error signing in")
                                        } else {print("signed in succesfully")}
                                    }
                                    
                                    buttonPressed = true
                                }
                            }
                        }
                        .disabled(buttonPressed)
                    .navigationDestination(isPresented: $buttonPressed){
                        JobDescription(userID: userID)
                    }
                }
                .onAppear{
                    deleteUserProfiles()
                }
            }
        }
    }
    
    func deleteUserProfiles()  {
        guard let user = Auth.auth().currentUser, user.isAnonymous else {
            print("nothing to clean up")
            return
        }

        let uid = user.uid
        let db = Firestore.firestore()

        // Delete Firestore user document
        db.collection("users").document(uid).delete { error in
            if error != nil {
                print("Error deleting from users")
            }
        }

        // Delete Firestore queue document
        db.collection("queue").document(uid).delete { error in
            if error != nil {
                print("Error deleting from queue")
            }
        }

        // Delete Auth account
        user.delete { error in
            if error != nil {
                print("cant delete of auth")
            }
        }

        // Sign out
        do {
            try Auth.auth().signOut()
            print("Signed out successfully.")
        } catch {
            print("Error signing out")
        }
    }

}

#Preview {
    LogInScreen()
}

struct BootupScreen: View {
    @State private var isChecked: Bool = false
    
    @Binding var isActive: Bool
    
    @State private var opacity: Double = 0
    @State private var size = 0.7
    @State private var offsetX: CGFloat = 0
    
    @State private var Firstopacity: Double = 1
    @State private var Firstsize = 0.7
    
    @State private var JobTextOpacity : Double = 0
    @State private var JobTextSize = 0.1
    @State private var JobTextOffsetX : CGFloat = 5
    
    @State private var JamTextOpacity : Double = 0
    @State private var JamTextSize = 0.1
    @State private var JamTextOffsetX : CGFloat = 110
    
    var body: some View {
        Image(.jobJamLogo)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 200)
            .foregroundStyle(.tint)
            .scaleEffect(size)
            .opacity(opacity)
            .offset(x: offsetX)
            .onAppear {
                withAnimation(.easeInOut(duration: 1)) {
                    self.size = 0.9
                    self.opacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 1)) {
                        self.offsetX = -115
                        self.size = 0.6
                    }
                }
                
            }
        
        
        Text("Job")
            .bold(true)
            .foregroundStyle(.white)
            .font(.system(size: 80))
            .scaleEffect(JobTextSize)
            .opacity(JobTextOpacity)
            .offset(x: JobTextOffsetX)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.bouncy(duration: 0.6)) {
                        self.JobTextOpacity = 1
                        self.JobTextSize = 0.7
                    }
                }
            }
        Text("Jam")
            .bold(true)
            .foregroundStyle(.white)
            .font(.system(size: 80))
            .scaleEffect(JamTextSize)
            .opacity(JamTextOpacity)
            .offset(x: JamTextOffsetX)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.bouncy(duration: 0.6)) {
                        self.JamTextOpacity = 1
                        self.JamTextSize = 0.7
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.bouncy(duration: 1)) {
                        isActive = true
                    }
                }
            }
    }
}

struct SignInButton: View {
    @State private var size: CGFloat = 1
    @Binding var buttonPressed: Bool
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 100)
                .fill(Color.electricy)
                .frame(width: 250, height: 80)
            HStack {
                if buttonPressed {
                    ProgressView()
                        .padding(10)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                
                Text("Sign in")
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundColor(.white)
            }
            
            if buttonPressed {
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 250, height: 80)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: buttonPressed)
    }
}
