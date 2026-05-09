// APIError.swift
import Foundation

enum APIError: Error {
    case channelNotFound
    case invalidResponse
    case videoNotFound
    case commentsDisabled
    case networkError
}
