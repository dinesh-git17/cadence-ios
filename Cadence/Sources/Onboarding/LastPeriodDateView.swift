import SwiftUI

struct LastPeriodDateView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var displayedMonth: Date = .now

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            titleSection
            dateDisplayCard
            miniCalendar
            Spacer()
            continueButton
        }
        .background(Color.cadenceBgBase)
        .navigationBarHidden(true)
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: CadenceSpacing.md) {
            CadenceProgressDots(totalSteps: 6, currentStep: 1)
            StepPill(label: "Step 2 of 6", variant: .required)
        }
        .padding(.top, CadenceSpacing.lg)
    }

    // MARK: - Title

    private var titleSection: some View {
        Text("When did your last\nperiod start?")
            .font(.cadenceTitleMedium)
            .foregroundStyle(Color.cadenceTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadenceSpacing.lg)
            .padding(.top, CadenceSpacing.xxl)
    }

    // MARK: - Date display

    private var dateDisplayCard: some View {
        HStack {
            Text("LAST PERIOD")
                .font(.cadenceLabel)
                .foregroundStyle(Color.cadenceTextTertiary)
            Spacer()
            Text(viewModel.lastPeriodDate, style: .date)
                .font(.cadenceTitleSmall)
                .foregroundStyle(Color.cadenceTextPrimary)
        }
        .padding(CadenceSpacing.md)
        .background(Color.cadenceBgTinted)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.md)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.lg)
    }

    // MARK: - Calendar grid

    private var miniCalendar: some View {
        VStack(spacing: CadenceSpacing.sm) {
            monthNavigation
            dayOfWeekHeaders
            dateGrid
        }
        .padding(10)
        .background(Color.cadenceBgWarm)
        .clipShape(RoundedRectangle(cornerRadius: CadenceRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CadenceRadius.md)
                .stroke(Color.cadenceBorderDefault, lineWidth: 0.5)
        )
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.top, CadenceSpacing.sm)
    }

    private var monthNavigation: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.cadenceTextTertiary)
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.month().year())
                .font(.cadenceLabel)
                .foregroundStyle(Color.cadenceTextSecondary)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.cadenceTextTertiary)
            }
        }
    }

    private var dayOfWeekHeaders: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.cadenceMicro)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cadenceTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dateGrid: some View {
        LazyVGrid(columns: columns, spacing: CadenceSpacing.xs) {
            ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                if let date {
                    dateCell(for: date)
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            }
        }
    }

    private func dateCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: viewModel.lastPeriodDate)
        let isFuture = date > .now
        return Text("\(calendar.component(.day, from: date))")
            .font(.cadenceCaption)
            .foregroundStyle(
                isFuture
                    ? Color.cadenceTextTertiary
                    : isSelected ? .white : Color.cadenceTextSecondary
            )
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(isSelected ? Color.cadencePrimary : .clear)
            )
            .contentShape(Circle())
            .onTapGesture {
                guard !isFuture else { return }
                viewModel.lastPeriodDate = date
            }
            .accessibilityLabel(date.formatted(.dateTime.month().day().year()))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - CTA

    private var continueButton: some View {
        Button("Continue") {
            viewModel.path.append(OnboardingRoute.cycleLengths)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, CadenceSpacing.lg)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func shiftMonth(_ delta: Int) {
        displayedMonth = calendar.date(
            byAdding: .month, value: delta, to: displayedMonth
        ) ?? displayedMonth
    }

    private func daysInMonth() -> [Date?] {
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ),
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let weekdayOffset = calendar.component(.weekday, from: monthStart) - 1
        let padding: [Date?] = Array(repeating: nil, count: weekdayOffset)
        let dates: [Date?] = range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
        return padding + dates
    }
}
