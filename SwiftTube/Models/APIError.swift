// APIError.swift
import Foundation

enum APIError: Error {
    case channelNotFound
    case invalidResponse
    case invalidAPIKey
    case videoNotFound
}