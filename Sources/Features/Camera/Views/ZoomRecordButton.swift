//
//  ZoomRecordButton.swift
//  Provika
//
//  Created by bbdyno on 4/16/26.
//

import SwiftUI

// MARK: - 줌 다이얼 컨트롤 (아이폰 카메라 스타일)

struct ZoomDialControl: View {
    let zoomFactor: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onZoomChange: (CGFloat) -> Void

    @State private var isExpanded = false
    @State private var dragStartZoom: CGFloat = 1.0

    private let dialWidth: CGFloat = 280
    private let dialHeight: CGFloat = 44

    var body: some View {
        ZStack {
            if isExpanded {
                // 확장된 줌 다이얼
                expandedDial
                    .transition(.scale.combined(with: .opacity))
            } else {
                // 줌 레벨 버튼
                zoomButton
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var zoomButton: some View {
        Text(String(format: "%.1fx", zoomFactor))
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundStyle(.yellow)
            .frame(width: 52, height: 36)
            .background(.black.opacity(0.5))
            .clipShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isExpanded {
                            isExpanded = true
                            dragStartZoom = zoomFactor
                        }
                        applyDrag(value.translation.width)
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isExpanded = false
                        }
                    }
            )
    }

    private var expandedDial: some View {
        ZStack {
            // 배경 캡슐
            Capsule()
                .fill(.black.opacity(0.7))
                .frame(width: dialWidth, height: dialHeight)

            // 눈금 마크
            HStack(spacing: 0) {
                ForEach(tickMarks, id: \.self) { value in
                    VStack(spacing: 2) {
                        if isMainTick(value) {
                            Text(String(format: "%.0f", value))
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    isCurrentRange(value) ? .yellow : .white.opacity(0.6)
                                )
                        } else {
                            Rectangle()
                                .fill(isCurrentRange(value) ? .yellow : .white.opacity(0.3))
                                .frame(width: 1, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(width: dialWidth - 32)

            // 현재 위치 인디케이터
            let progress = (zoomFactor - minZoom) / max(maxZoom - minZoom, 0.01)
            let xOffset = (progress - 0.5) * (dialWidth - 48)

            Circle()
                .fill(.yellow)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(format: "%.1f", zoomFactor))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                }
                .offset(x: xOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // 다이얼 위에서 직접 드래그
                    let normalizedX = (value.location.x / dialWidth)
                    let newZoom = minZoom + normalizedX * (maxZoom - minZoom)
                    let clamped = min(max(newZoom, minZoom), maxZoom)
                    onZoomChange(clamped)
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isExpanded = false
                    }
                }
        )
    }

    private var tickMarks: [CGFloat] {
        let step: CGFloat = 0.5
        var marks: [CGFloat] = []
        var v = minZoom
        while v <= maxZoom {
            marks.append(v)
            v += step
        }
        return marks
    }

    private func isMainTick(_ value: CGFloat) -> Bool {
        value.truncatingRemainder(dividingBy: 1.0) == 0
    }

    private func isCurrentRange(_ value: CGFloat) -> Bool {
        value <= zoomFactor
    }

    private func applyDrag(_ translationX: CGFloat) {
        let sensitivity: CGFloat = 300
        let normalizedDrag = translationX / sensitivity
        let zoomRange = maxZoom - minZoom
        let newZoom = dragStartZoom + normalizedDrag * zoomRange
        let clamped = min(max(newZoom, minZoom), maxZoom)
        onZoomChange(clamped)
    }
}
