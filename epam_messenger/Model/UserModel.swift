//
//  UserModel.swift
//  epam_messenger
//
//  Created by Maxim on 13.03.2020.
//

import Foundation
import Firebase
import CodableFirebase

public struct UserModel: AutoCodable, AutoEquatable {
    
    var documentId: String?
    let name: String
    let surname: String
    let online: Bool
    let typing: String?
    
    static let defaultOnline: Bool = false
    
    static func fromSnapshot(_ snapshot: DocumentSnapshot) -> UserModel? {
        var data = snapshot.data() ?? [:]
        data["documentId"] = snapshot.documentID
        
        do {
            return try FirestoreDecoder()
                .decode(
                    UserModel.self,
                    from: data
            )
        } catch let err {
            debugPrint("error while parse test model: \(err)")
            return nil
        }
    }
    
    static func avatarRef(byId userId: String) -> StorageReference {
        Storage.storage().reference(withPath: "chats/\(userId)/avatar.jpg")
    }
}

extension UserModel: UserProtocol {
    
    var fullName: String {
        return "\(name) \(surname)"
    }
    
    var onlineText: String {
        return online
            ? "Online"
            : "Offline"
    }
    
    var avatarRef: StorageReference {
        UserModel.avatarRef(byId: documentId!)
    }
    
}
