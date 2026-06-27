import SwiftUI

struct MediaCardView: View {
    let item: MediaItem
    let serverURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImageView(
                url: primaryImageURL,
                contentMode: .fill,
                cornerRadius: 18
            )
            .frame(width: 320, height: 460)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let year = item.productionYear {
                        Text(String(year))
                    }
                    if let duration = item.durationFormatted {
                        Text(duration)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 320, alignment: .leading)
    }

    private var primaryImageURL: URL? {
        guard let serverURL, item.primaryImageTag != nil else {
            return nil
        }

        return serverURL
            .appendingPathComponent(Endpoints.primaryImage(itemID: item.id))
            .appending(queryItems: [
                URLQueryItem(name: "tag", value: item.primaryImageTag),
                URLQueryItem(name: "quality", value: "90"),
                URLQueryItem(name: "maxWidth", value: "640")
            ])
    }
}
