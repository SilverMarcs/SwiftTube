// Channel.swift
import Foundation

struct Channel: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let uploadsPlaylistId: String
}