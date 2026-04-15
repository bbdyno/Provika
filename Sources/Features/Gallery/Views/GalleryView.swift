//
//  GalleryView.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftData
import SwiftUI

struct GalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var viewModel = GalleryViewModel()
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 캘린더
                DatePicker(
                    "날짜 선택",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .tint(.red)

                Divider()

                // 녹화 목록
                let filteredRecordings = viewModel.recordings(for: selectedDate, from: recordings)

                if filteredRecordings.isEmpty {
                    emptyView
                } else {
                    recordingGrid(filteredRecordings)
                }
            }
            .navigationTitle(ProvikaStrings.Localizable.Gallery.title)
            .onAppear {
                viewModel.loadRecordingDates(recordings: recordings)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "video.slash")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text(ProvikaStrings.Localizable.Gallery.Empty.title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(ProvikaStrings.Localizable.Gallery.Empty.message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func recordingGrid(_ items: [Recording]) -> some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(items, id: \.id) { recording in
                    NavigationLink(destination: VideoDetailView(recording: recording)) {
                        VideoThumbnailView(recording: recording, viewModel: viewModel)
                    }
                }
            }
            .padding(8)
        }
    }
}
