import SwiftUI

struct GigDetailView: View {
    @StateObject private var viewModel: GigDetailViewModel
    @State private var showsRequestSheet = false
    @State private var message = ""

    init(viewModel: GigDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeroView(
                    symbolName: "calendar.badge.clock",
                    imageURL: viewModel.imageDisplayURL,
                    badge: viewModel.statusText,
                    title: viewModel.gig.title,
                    subtitle: viewModel.venueDisplayName,
                    city: viewModel.gig.city
                )

                TagRow(tags: viewModel.gig.requiredGenres)

                DetailSection(title: "Descripcion") {
                    Text(viewModel.gig.description ?? "Fecha profesional abierta a perfiles que encajen con el repertorio y el formato.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DetailSection(title: "Datos clave") {
                    KeyValueRow(label: "Local", value: viewModel.venueDisplayName)
                    KeyValueRow(label: "Ciudad", value: viewModel.gig.city)
                    KeyValueRow(label: "Fecha", value: viewModel.gig.performanceDate.formatted(date: .abbreviated, time: .shortened))
                    KeyValueRow(label: "Duracion", value: viewModel.durationText)
                    KeyValueRow(label: "Presupuesto", value: viewModel.budgetText)
                    KeyValueRow(label: "Perfil buscado", value: viewModel.gig.roleNeeded.displayName)
                }

                requestSection
            }
            .padding(16)
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsRequestSheet) {
            ContactRequestSheet(
                gigTitle: viewModel.gig.title,
                venueName: viewModel.venueDisplayName,
                performanceDate: viewModel.gig.performanceDate,
                budgetText: viewModel.budgetText,
                message: $message
            ) {
                Task {
                    await viewModel.requestContact(message: message)
                }
            }
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let application = viewModel.application {
                Label("Solicitud \(application.status.displayName.lowercased())", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(application.status.tint)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(application.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Button {
                    message = "Hola, me interesa esta fecha. Puedo compartir repertorio, disponibilidad y material reciente."
                    showsRequestSheet = true
                } label: {
                    Label("Solicitar contacto", systemImage: "paperplane.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canRequestContact)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct VenueDetailView: View {
    @StateObject private var viewModel: VenueDetailViewModel

    init(viewModel: VenueDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeroView(
                    symbolName: "music.mic",
                    imageURL: viewModel.venue.imageURL,
                    badge: viewModel.verificationText,
                    title: viewModel.venue.name,
                    subtitle: viewModel.venue.address,
                    city: viewModel.venue.city
                )

                TagRow(tags: viewModel.venue.genres)

                DetailSection(title: "Descripcion") {
                    Text(viewModel.venue.description ?? "Espacio activo para programacion musical con equipo local y formatos de directo.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DetailSection(title: "Datos clave") {
                    KeyValueRow(label: "Ciudad", value: viewModel.venue.city)
                    KeyValueRow(label: "Direccion", value: viewModel.venue.address)
                    KeyValueRow(label: "Aforo", value: viewModel.capacityText)
                    KeyValueRow(label: "Estado", value: viewModel.verificationText)
                }

                ReviewSectionView(
                    summary: viewModel.reviewSummary,
                    reviews: viewModel.reviews
                )
            }
            .padding(16)
        }
        .navigationTitle("Local")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MissingDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Detalle no disponible",
            systemImage: "exclamationmark.magnifyingglass",
            description: Text("No se encontro el contenido seleccionado.")
        )
        .navigationTitle("Detalle")
    }
}

private struct ContactRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gigTitle: String
    let venueName: String
    let performanceDate: Date
    let budgetText: String
    @Binding var message: String
    let onSubmit: () -> Void
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ContactRequestSummaryCard(
                        gigTitle: gigTitle,
                        venueName: venueName,
                        performanceDate: performanceDate,
                        budgetText: budgetText
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Mensaje")
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Text("\(message.trimmingCharacters(in: .whitespacesAndNewlines).count)/240")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TextEditor(text: $message)
                            .focused($isMessageFocused)
                            .frame(height: 150)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Solicitar contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        isMessageFocused = false
                        onSubmit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedMessage.isEmpty || trimmedMessage.count > 240)
                }
            }
        }
        .presentationDetents([.height(430), .large])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ContactRequestSummaryCard: View {
    let gigTitle: String
    let venueName: String
    let performanceDate: Date
    let budgetText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(gigTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(venueName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                Label(
                    performanceDate.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                )

                Label(budgetText, systemImage: "banknote")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DetailHeroView: View {
    let symbolName: String
    let imageURL: URL?
    let badge: String
    let title: String
    let subtitle: String
    let city: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                DetailHeroImageView(imageURL: imageURL, symbolName: symbolName)

                VStack(alignment: .leading, spacing: 6) {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label(city, systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DetailHeroImageView: View {
    let imageURL: URL?
    let symbolName: String

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        placeholder(showsProgress: true)
                    case .failure:
                        placeholder(showsProgress: false)
                    @unknown default:
                        placeholder(showsProgress: false)
                    }
                }
            } else {
                placeholder(showsProgress: false)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func placeholder(showsProgress: Bool) -> some View {
        ZStack {
            Color(.tertiarySystemBackground)

            if showsProgress {
                ProgressView()
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            Text(value.isEmpty ? "Por confirmar" : value)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct TagRow: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct ReviewSectionView: View {
    let summary: ReviewSummary
    let reviews: [Review]

    var body: some View {
        DetailSection(title: "Resenas") {
            if summary.count == 0 {
                Text("Todavia no hay resenas publicadas para este perfil.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Label(summary.formattedAverage, systemImage: "star.fill")
                            .font(.headline)

                        Text("\(summary.count) valoraciones")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(reviews.prefix(3)) { review in
                        ReviewRow(review: review)
                    }
                }
            }
        }
    }
}

private struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < review.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(index < review.rating ? Color.yellow : Color.secondary.opacity(0.5))
                }

                Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(review.comment)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Gig") {
    let detailService = MockExploreDetailService()
    let gigStore = GigStore()
    let notificationStore = NotificationStore()
    let applicationStore = ApplicationStore(
        gigStore: gigStore,
        notificationStore: notificationStore
    )
    let profile = UserProfile(
        id: UUID(),
        email: "demo@setloop.local",
        displayName: "Demo SetLoop",
        role: .musician,
        city: "Madrid"
    )

    NavigationStack {
        GigDetailView(
            viewModel: GigDetailViewModel(
                gig: MockExploreData.gigs[0],
                currentProfile: profile,
                applicationStore: applicationStore,
                detailService: detailService
            )
        )
    }
}
