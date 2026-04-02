import SwiftUI

struct AcceptConnectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    let inviteToken: String?

    @State private var trackerName: String = ""
    @State private var isValidating = false
    @State private var validationError: String?

    private let inviteLinkService = InviteLinkService()

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            titleSection
            connectionContent
            Spacer()
            acceptButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
    }

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 3, currentStep: 1)
            StepPill(label: "Step 2 of 3", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connect with\nyour partner")
                .font(.cadenceTitleMedium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text("You'll only see what they choose to share.")
                .font(.cadenceBody)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xxl)
    }

    @ViewBuilder
    private var connectionContent: some View {
        if inviteToken != nil {
            tokenPresentContent
        } else {
            noTokenFallback
        }
    }

    private var tokenPresentContent: some View {
        VStack(spacing: CadenceSpacing.lg) {
            if !trackerName.isEmpty {
                connectionCard
            } else if isValidating {
                ProgressView()
                    .tint(Color.cadencePrimary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let error = validationError {
                Text(error)
                    .font(.cadenceCaption)
                    .foregroundStyle(Color.cadenceError)
                    .padding(CadenceSpacing.md)
            }
        }
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xl)
        .task(id: inviteToken) {
            guard let token = inviteToken else { return }
            await validateToken(token)
        }
    }

    private var connectionCard: some View {
        HStack(spacing: CadenceSpacing.md) {
            CadenceAvatarCircle(
                initials: String(trackerName.prefix(2)).uppercased(),
                diameter: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(trackerName)
                    .font(.cadenceBodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cadenceTextPrimary)
                Text("Invited you to connect on Cadence")
                    .font(.cadenceCaptionSmall)
                    .foregroundStyle(Color.cadenceTextSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.cadenceSuccess)
                .font(.system(size: 18))
        }
        .padding(CadenceSpacing.md)
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.lg)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
    }

    private var noTokenFallback: some View {
        VStack(alignment: .leading, spacing: CadenceSpacing.sm) {
            Text("No invite link found")
                .font(.cadenceCaption)
                .fontWeight(.medium)
                .foregroundStyle(Color.cadenceTextPrimary)
            Text("Ask your partner to open Cadence and send you an invite link.")
                .font(.cadenceCaptionSmall)
                .foregroundStyle(Color.cadenceTextSecondary)
        }
        .padding(CadenceSpacing.md)
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.lg)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.xl)
    }

    private var acceptButton: some View {
        Button("Accept & connect") {
            viewModel.resolvedInviteToken = inviteToken
            viewModel.path.append(OnboardingRoute.partnerNotifications)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
        .disabled(inviteToken != nil && trackerName.isEmpty)
    }

    private func validateToken(_ token: String) async {
        isValidating = true
        validationError = nil
        do {
            let result = try await inviteLinkService.validateInviteToken(token)
            trackerName = result.name
            viewModel.resolvedTrackerId = result.trackerId
        } catch {
            validationError = "This invite link has expired or is no longer valid."
        }
        isValidating = false
    }
}
