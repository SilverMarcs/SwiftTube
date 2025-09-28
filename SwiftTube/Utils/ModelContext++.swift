//
//  ModelContext++.swift
//  SwiftTube
//
//  Created by Zabir Raihan on 27/09/2025.
//

import SwiftData
import Foundation

// Upsert helpers
extension ModelContext {
    func upsert<T: PersistentModel>(_ model: T, updateBlock: (T, T) -> Void) where T: Identifiable, T.ID == String {
        let modelId = model.id
        
        if let existing = try? fetch(FetchDescriptor<T>(predicate: #Predicate { $0.id == modelId })).first {
            updateBlock(existing, model)
        } else {
            insert(model)
        }
        try? save()
    }
    
    func upsertChannel(_ c: Channel) {
        upsert(c) { existing, new in
            existing.title = new.title
            existing.channelDescription = new.channelDescription
            existing.thumbnailURL = new.thumbnailURL
            existing.uploadsPlaylistId = new.uploadsPlaylistId
            existing.updatedAt = Date()
        }
    }
    

}

extension ModelContext {
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
    }
}
