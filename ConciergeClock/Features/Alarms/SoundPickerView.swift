import ConciergeCore
import GGSBrand
import SwiftUI

/// Choose an alarm's sound. Tapping a sound selects it and plays a preview (tap again to stop).
struct SoundPickerView: View {
    @Binding var selection: String
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let sounds = model.sounds
        List {
            Section {
                ForEach(AlarmSound.allCases) { sound in
                    Button {
                        selection = sound.rawValue
                        sounds.togglePreview(sound)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: AlarmSound.resolve(selection) == sound ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AlarmSound.resolve(selection) == sound ? ConciergeStyle.tint : Theme.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.soundName(sound)).foregroundStyle(Theme.textPrimary)
                                Text(l10n.soundHint(sound)).font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if sound.isSynthesised {
                                Image(systemName: sounds.previewing == sound ? "stop.circle.fill" : "play.circle")
                                    .font(.title3)
                                    .foregroundStyle(ConciergeStyle.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(AlarmSound.resolve(selection) == sound ? .isSelected : [])
                }
            } footer: {
                Text(l10n["sound.footer"])
            }
        }
        .navigationTitle(l10n["sound.title"])
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { sounds.stopPreview() }
    }
}

extension Localizer {
    func soundName(_ sound: AlarmSound) -> String {
        switch sound {
        case .conciergeBell: self["sound.conciergeBell"]
        case .grandfatherClock: self["sound.grandfatherClock"]
        case .chime: self["sound.chime"]
        case .gentleRise: self["sound.gentleRise"]
        case .acousticBell: self["sound.acousticBell"]
        case .singingBowl: self["sound.singingBowl"]
        case .marimba: self["sound.marimba"]
        case .musicBox: self["sound.musicBox"]
        case .digital: self["sound.digital"]
        case .iPhoneDefault: self["sound.iPhoneDefault"]
        }
    }

    func soundHint(_ sound: AlarmSound) -> String {
        switch sound {
        case .conciergeBell: self["sound.conciergeBell.hint"]
        case .grandfatherClock: self["sound.grandfatherClock.hint"]
        case .chime: self["sound.chime.hint"]
        case .gentleRise: self["sound.gentleRise.hint"]
        case .acousticBell: self["sound.acousticBell.hint"]
        case .singingBowl: self["sound.singingBowl.hint"]
        case .marimba: self["sound.marimba.hint"]
        case .musicBox: self["sound.musicBox.hint"]
        case .digital: self["sound.digital.hint"]
        case .iPhoneDefault: self["sound.iPhoneDefault.hint"]
        }
    }
}
