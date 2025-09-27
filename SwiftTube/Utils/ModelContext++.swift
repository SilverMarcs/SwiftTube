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
    
    func upsertVideo(_ v: Video) {
        upsert(v) { existing, new in
            existing.title = new.title
            existing.videoDescription = new.videoDescription
            existing.thumbnailURL = new.thumbnailURL
            existing.publishedAt = new.publishedAt
            existing.channelTitle = new.channelTitle
            existing.url = new.url
        }
    }
}
