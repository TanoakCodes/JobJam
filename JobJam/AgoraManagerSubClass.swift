//
//  AgoraManagerSubClass.swift
//  JobJam
//
//  Created by Tanish Srinivas on 7/23/25.
//

import Foundation
import SwiftUIRtc
import AgoraRtcKit

public class AgoraManagerSubClass: AgoraManager {
    @Published public var remoteUserVideo: [UInt: Bool] = [:]
    @Published public var remoteUserAudio: [UInt: Bool] = [:]
    
    override init(appId: String, role: AgoraClientRole) {
            super.init(appId: appId, role: role)
            agoraEngine.delegate = self
        agoraEngine.enableVideo()
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            print("Remote user \(uid) video muted: \(muted)")
            self.remoteUserVideo[uid] = muted  // Store whether video is ON
            print(self.remoteUserVideo)
        }
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        print("Remote user \(uid) audio muted: \(muted)")
        // Update your UI or state to reflect audio mute status
    }

}

