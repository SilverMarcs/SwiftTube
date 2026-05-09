// CommonTypes.swift
import Foundation

struct Thumbnails: Codable {
    let medium: Thumbnail
    let high: Thumbnail?
}

struct Thumbnail: Codable {
    let url: String
}