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
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "날짜 선택",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .tint(.red)

                Divider()

                let filteredRecordings = viewModel.recordings(for: selectedDate, from: recordings)

                if filteredRecordings.isEmpty {
                    emptyView
                } else {
                    recordingGrid(filteredRecordings)
                }
            }
            .navigationTitle(ProvikaStrings.Localizable.Gallery.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectionMode {
                        Button(ProvikaStrings.Localizable.Common.cancel) {
                            exitSelectionMode()
                        }
                    } else {
                        Button(ProvikaStrings.Localizable.Common.select) {
                            isSelectionMode = true
                        }
                    }
                }

                if isSelectionMode && !selectedIDs.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(
                                "\(ProvikaStrings.Localizable.Common.delete) (\(selectedIDs.count))",
                                systemImage: "trash"
                            )
                        }
                        .tint(.red)
                    }
                }
            }
            .alert(
                ProvikaStrings.Localizable.Common.delete,
                isPresented: $showDeleteConfirm
            ) {
                Button(ProvikaStrings.Localizable.Common.cancel, role: .cancel) {}
                Button(ProvikaStrings.Localizable.Common.delete, role: .destructive) {
                    deleteSelected()
                }
            } message: {
                Text(ProvikaStrings.Localizable.Gallery.Detail.Delete.confirm)
            }
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
                    if isSelectionMode {
                        selectableThumbnail(recording)
                    } else {
                        NavigationLink(destination: VideoDetailView(recording: recording)) {
                            VideoThumbnailView(recording: recording, viewModel: viewModel)
                        }
                    }
                }
            }
            .padding(8)
        }
        .gesture(isSelectionMode ? dragSelectGesture(items) : nil)
    }

    private func selectableThumbnail(_ recording: Recording) -> some View {
        let isSelected = selectedIDs.contains(recording.id)
        return VideoThumbnailView(recording: recording, viewModel: viewModel)
            .overlay(alignment: .topLeading) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .shadow(radius: 2)
                    .padding(8)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue, lineWidth: 3)
                }
            }
            .opacity(isSelected ? 0.8 : 1.0)
            .onTapGesture {
                toggleSelection(recording.id)
            }
    }

    private func dragSelectGesture(_ items: [Recording]) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // 드래그 중 터치 위치의 아이템 선택
                let itemWidth = (UIScreen.main.bounds.width - 24) / 2
                let itemHeight = itemWidth * 9 / 16
                let col = Int(value.location.x / (itemWidth + 8))
                let row = Int(value.location.y / (itemHeight + 8))
                let index = row * 2 + min(col, 1)

                if index >= 0 && index < items.count {
                    let id = items[index].id
                    if !selectedIDs.contains(id) {
                        selectedIDs.insert(id)
                    }
                }
            }
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func deleteSelected() {
        let toDelete = recordings.filter { selectedIDs.contains($0.id) }
        for recording in toDelete {
            viewModel.deleteRecording(recording, context: modelContext)
        }
        exitSelectionMode()
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedIDs.removeAll()
    }
}
