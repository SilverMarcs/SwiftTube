//
//  YTService+Comment.swift
//  Cathode
//
//  InnerTube-backed top-level comment fetch. ITComment is flat (no replies);
//  reply expansion is not yet wired through and will need a future addition
//  to InnerTubeAPI. Returned comments are all `isTopLevel == true`.
//

import Foundation

extension YTService {
    static func fetchComments(for video: Video) async throws -> [Comment] {
        let it = try await InnerTubeAPI.shared.fetchComments(videoId: video.id)
        return it.map(Comment.init)
    }
}
