// Video.swift
import Foundation

struct Video: Identifiable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: String
    let publishedAt: Date
    let channelId: String
    let channelTitle: String
    let url: String
}