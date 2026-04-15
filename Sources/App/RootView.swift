import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.camera,
                        systemImage: "camera.fill"
                    )
                }

            GalleryView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.gallery,
                        systemImage: "photo.on.rectangle"
                    )
                }

            SettingsPlaceholderView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.settings,
                        systemImage: "gearshape.fill"
                    )
                }
        }
        .tint(.red)
    }
}

struct CameraPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(ProvikaStrings.Localizable.Tab.camera)
                    .font(.title2)
            }
            .navigationTitle(ProvikaStrings.Localizable.Tab.camera)
        }
    }
}

struct GalleryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(ProvikaStrings.Localizable.Gallery.title)
                    .font(.title2)
            }
            .navigationTitle(ProvikaStrings.Localizable.Gallery.title)
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(ProvikaStrings.Localizable.Settings.title)
                    .font(.title2)
            }
            .navigationTitle(ProvikaStrings.Localizable.Settings.title)
        }
    }
}
