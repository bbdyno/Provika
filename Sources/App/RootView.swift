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
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.camera)

            GalleryView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.gallery,
                        systemImage: "photo.on.rectangle"
                    )
                }
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.gallery)

            SettingsView()
                .tabItem {
                    Label(
                        ProvikaStrings.Localizable.Tab.settings,
                        systemImage: "gearshape.fill"
                    )
                }
                .accessibilityLabel(ProvikaStrings.Localizable.Tab.settings)
        }
        .tint(.red)
    }
}
