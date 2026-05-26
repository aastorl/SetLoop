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
                message: $message
            ) {
                viewModel.requestContact(message: message)
            }
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let application = viewModel.application {
                Label("Solicitud \(application.status.displayName.lowercased())", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(application.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

struct MusicianDetailView: View {
    @StateObject private var viewModel: MusicianDetailViewModel
    @State private var showsInviteSheet = false
    @State private var inviteMessage = ""

    init(viewModel: MusicianDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeroView(
                    symbolName: "person.crop.square",
                    badge: viewModel.premiumText,
                    title: viewModel.musician.displayName,
                    subtitle: viewModel.profileTypeText,
                    city: viewModel.musician.city
                )

                TagRow(tags: viewModel.tags)

                DetailSection(title: "Bio") {
                    Text(viewModel.musician.bio ?? "Perfil profesional disponible para fechas, colaboraciones y programacion.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DetailSection(title: "Datos clave") {
                    KeyValueRow(label: "Ciudad", value: viewModel.musician.city)
                    KeyValueRow(label: "Perfil", value: viewModel.profileTypeText)
                    if viewModel.musician.role == .musician {
                        KeyValueRow(label: "Formacion", value: viewModel.formationsText)
                    }
                    KeyValueRow(label: viewModel.detailsLabel, value: viewModel.detailsText)
                    KeyValueRow(label: "Cuenta", value: viewModel.premiumText)
                }

                if viewModel.shouldShowInviteSection {
                    inviteSection
                }

                ReviewSectionView(
                    summary: viewModel.reviewSummary,
                    reviews: viewModel.reviews
                )
            }
            .padding(16)
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsInviteSheet) {
            InviteTalentSheet(
                talentName: viewModel.musician.displayName,
                gigs: viewModel.availableGigs,
                message: $inviteMessage
            ) { gigID in
                viewModel.sendInvite(gigID: gigID, message: inviteMessage)
            }
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitaciones")
                .font(.headline)

            Text(viewModel.inviteHelperText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.inviteSummaries.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.inviteSummaries) { summary in
                        HStack(spacing: 8) {
                            Text(summary.gigTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 8)

                            Text(summary.status.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(summary.status.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(summary.status.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if viewModel.canInviteTalent {
                Button {
                    inviteMessage = viewModel.defaultInviteMessage(for: viewModel.availableGigs.first)
                    showsInviteSheet = true
                } label: {
                    Label(viewModel.inviteButtonTitle, systemImage: "paperplane.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MissingDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Detalle no disponible",
            systemImage: "exclamationmark.magnifyingglass",
            description: Text("No se encontro el contenido seleccionado en los datos demo.")
        )
        .navigationTitle("Detalle")
    }
}

private struct ContactRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gigTitle: String
    @Binding var message: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(gigTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mensaje")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(16)
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
                        onSubmit()
                        dismiss()
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct InviteTalentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let talentName: String
    let gigs: [Gig]
    @Binding var message: String
    let onSubmit: (UUID) -> Void
    @State private var selectedGigID: UUID

    init(
        talentName: String,
        gigs: [Gig],
        message: Binding<String>,
        onSubmit: @escaping (UUID) -> Void
    ) {
        self.talentName = talentName
        self.gigs = gigs
        self._message = message
        self.onSubmit = onSubmit
        self._selectedGigID = State(initialValue: gigs.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(talentName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fecha")
                        .font(.subheadline.weight(.semibold))

                    Picker("Fecha", selection: $selectedGigID) {
                        ForEach(gigs) { gig in
                            Text(gig.title).tag(gig.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let selectedGig = gigs.first(where: { $0.id == selectedGigID }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(selectedGig.city, systemImage: "mappin.and.ellipse")
                        Label(selectedGig.performanceDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mensaje")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Invitar a fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        onSubmit(selectedGigID)
                        dismiss()
                    }
                    .disabled(gigs.isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct DetailHeroView: View {
    let symbolName: String
    let badge: String
    let title: String
    let subtitle: String
    let city: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(width: 72, height: 72)

                    Image(systemName: symbolName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

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
