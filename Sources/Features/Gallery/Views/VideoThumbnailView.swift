//
//  VideoThumbnailView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

struct VideoThumbnailView: View {
    let recording: Recording
    let viewModel: GalleryViewModel
    @State private var thumbnailData: Data?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let data = thumbnailData ?? recording.thumbnailData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay {
                        Image(systemName: "video")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }

            // 시간 배지
            Text(viewModel.formattedDuration(recording.duration))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            if recording.thumbnailData == nil {
                thumbnailData = await viewModel.generateThumbnail(for: recording)
            }
        }
    }
}
