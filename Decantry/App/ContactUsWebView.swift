import SwiftUI
@preconcurrency import Alamofire

struct ContactUsWebView: View {
    @Environment(\.dismiss) private var dismiss

    private var contactURL: String {
        AppConfiguration.registrationEndpoint.replacingOccurrences(
            of: "/api/v1/users/register",
            with: "/contact-us"
        )
    }

    var body: some View {
        Alamofire.WebContentView(url: contactURL)
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }
}
