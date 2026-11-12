import BellCore
import Foundation

enum Copy: CaseIterable {
    case tagline, settings, quit, nextBell, quietUntil, quietAllWeek, pausedUntil, switchedOff
    case active, quiet, paused, off, enableBell, pause, pause30, pause60, resume
    case preview, stopSound, sound, volume, volumeNote, interval, minutes, intervalNote
    case quietHours, quietNote, addPeriod, noPeriods, everyDay, weekdays, weekend
    case editPeriod, newPeriod, start, end, days, overnightNote, equalTimesError, noDaysError
    case save, cancel, delete, enabled, general, language, appearance, system, light, dark
    case launchAtLogin, loginNote, loginApproval, openSystemSettings, loginFailed
    case soundFailed, settingsRecovered, settingsSaveFailed, dismiss
    case about, version, close, previewNote, pauseNote, resetInterval, nextDay, allDayWarning
    case daily, soundMissing, intervalRange, automaticBell, deletePeriod, edit, custom, done
    case firstRunTitle, startListening, silentVolume, enable, disable
    case undo, redo, cut, copy, paste, selectAll

    var translations: (String, String) {
        switch self {
        case .tagline: ("A little space in your day.", "Ein ruhiger Moment im Alltag.")
        case .settings: ("Settings…", "Einstellungen …")
        case .quit: ("Quit Bell of Mindfulness", "Bell of Mindfulness beenden")
        case .nextBell: ("Next bell", "Nächster Klang")
        case .quietUntil: ("Quiet until", "Ruhezeit bis")
        case .quietAllWeek: ("Quiet hours cover the whole week", "Die Ruhezeiten decken die ganze Woche ab")
        case .pausedUntil: ("Paused until", "Pausiert bis")
        case .switchedOff: ("Turn on to begin a fresh interval.", "Einschalten, um ein neues Intervall zu starten.")
        case .active: ("On", "Aktiv")
        case .quiet: ("Quiet hours", "Ruhezeit")
        case .paused: ("Paused", "Pausiert")
        case .off: ("Off", "Aus")
        case .enableBell: ("Automatic bell", "Automatischer Klang")
        case .pause: ("Pause", "Pausieren")
        case .pause30: ("For 30 minutes", "Für 30 Minuten")
        case .pause60: ("For 1 hour", "Für 1 Stunde")
        case .resume: ("Resume", "Fortsetzen")
        case .preview: ("Preview sound", "Klang testen")
        case .stopSound: ("Stop sound", "Klang stoppen")
        case .sound: ("Sound & rhythm", "Klang & Rhythmus")
        case .volume: ("Playback volume", "Wiedergabelautstärke")
        case .volumeNote: ("Relative to your Mac’s volume. Your system volume stays unchanged.", "Relativ zur Mac-Lautstärke. Die Systemlautstärke bleibt unverändert.")
        case .interval: ("Ring every", "Klang alle")
        case .minutes: ("min", "Min.")
        case .intervalNote: ("A fresh interval starts when enabled, after waking, and after quiet hours. Missed bells are skipped.", "Ein neues Intervall beginnt beim Einschalten, nach dem Aufwachen und nach Ruhezeiten. Verpasste Klänge werden übersprungen.")
        case .quietHours: ("Quiet hours", "Ruhezeiten")
        case .quietNote: ("No automatic sound during these periods. Overlapping periods are combined.", "In diesen Zeiträumen erklingt kein automatischer Klang. Überschneidungen werden zusammengefasst.")
        case .addPeriod: ("Add quiet period", "Ruhezeit hinzufügen")
        case .noPeriods: ("No quiet periods. The bell can ring at any time.", "Keine Ruhezeiten. Der Klang kann jederzeit erklingen.")
        case .everyDay: ("Every day", "Jeden Tag")
        case .weekdays: ("Weekdays", "Werktags")
        case .weekend: ("Weekend", "Wochenende")
        case .editPeriod: ("Edit quiet period", "Ruhezeit bearbeiten")
        case .newPeriod: ("New quiet period", "Neue Ruhezeit")
        case .start: ("From", "Von")
        case .end: ("Until", "Bis")
        case .days: ("Starting days", "Starttage")
        case .overnightNote: ("Ends the following morning. Days refer to when the period starts.", "Endet am nächsten Morgen. Die Tage beziehen sich auf den Beginn der Ruhezeit.")
        case .equalTimesError: ("Choose different start and end times.", "Beginn und Ende müssen unterschiedlich sein.")
        case .noDaysError: ("Choose at least one day.", "Bitte mindestens einen Tag auswählen.")
        case .save: ("Save", "Sichern")
        case .cancel: ("Cancel", "Abbrechen")
        case .delete: ("Delete", "Löschen")
        case .enabled: ("Enabled", "Aktiviert")
        case .general: ("Preferences", "Allgemein")
        case .language: ("Language", "Sprache")
        case .appearance: ("Appearance", "Darstellung")
        case .system: ("System", "System")
        case .light: ("Light", "Hell")
        case .dark: ("Dark", "Dunkel")
        case .launchAtLogin: ("Launch at login", "Beim Anmelden starten")
        case .loginNote: ("Stay in your menu bar when you sign in to your Mac.", "Nach der Anmeldung am Mac in der Menüleiste verfügbar.")
        case .loginApproval: ("Allow Bell of Mindfulness in Login Items to finish enabling this option.", "Bell of Mindfulness unter Anmeldeobjekte erlauben, um diese Option zu aktivieren.")
        case .openSystemSettings: ("Open System Settings", "Systemeinstellungen öffnen")
        case .loginFailed: ("Couldn’t change launch at login.", "Der Anmeldestart konnte nicht geändert werden.")
        case .soundFailed: ("Couldn’t play the bell.", "Der Klang konnte nicht abgespielt werden.")
        case .settingsRecovered: ("Your saved settings couldn’t be read. A backup was kept and defaults were restored.", "Gesicherte Einstellungen konnten nicht gelesen werden. Eine Sicherung wurde aufbewahrt und Standardwerte wurden geladen.")
        case .settingsSaveFailed: ("Couldn’t save your settings.", "Die Einstellungen konnten nicht gesichert werden.")
        case .dismiss: ("Dismiss", "Schließen")
        case .about: ("About Bell of Mindfulness", "Über Bell of Mindfulness")
        case .version: ("Version", "Version")
        case .close: ("Close", "Schließen")
        case .previewNote: ("Preview is manual and also plays during quiet hours.", "Der manuelle Test funktioniert auch während der Ruhezeiten.")
        case .pauseNote: ("Resuming starts a new interval.", "Beim Fortsetzen beginnt ein neues Intervall.")
        case .resetInterval: ("Restart interval", "Intervall neu starten")
        case .nextDay: ("next day", "Folgetag")
        case .allDayWarning: ("Your periods cover the whole week. Automatic bells will stay silent.", "Die Ruhezeiten decken die ganze Woche ab. Automatische Klänge bleiben stumm.")
        case .daily: ("Daily", "Täglich")
        case .soundMissing: ("The bundled sound is missing. Rebuild or reinstall the app.", "Die Klangdatei fehlt. Die App bitte neu erstellen oder installieren.")
        case .intervalRange: ("Choose an interval from 1 to 1,440 minutes.", "Ein Intervall zwischen 1 und 1.440 Minuten wählen.")
        case .automaticBell: ("Automatic bell", "Automatischer Klang")
        case .deletePeriod: ("Delete quiet period", "Ruhezeit löschen")
        case .edit: ("Edit", "Bearbeiten")
        case .custom: ("Custom", "Eigene")
        case .done: ("Done", "Fertig")
        case .firstRunTitle: ("Make room for a moment.", "Zeit für einen ruhigen Moment.")
        case .startListening: ("Ready when you are.", "Bereit, wenn du es bist.")
        case .silentVolume: ("Playback volume is zero. Automatic bells will be silent.", "Die Wiedergabelautstärke ist null. Automatische Klänge bleiben stumm.")
        case .enable: ("Turn on", "Einschalten")
        case .disable: ("Turn off", "Ausschalten")
        case .undo: ("Undo", "Widerrufen")
        case .redo: ("Redo", "Wiederholen")
        case .cut: ("Cut", "Ausschneiden")
        case .copy: ("Copy", "Kopieren")
        case .paste: ("Paste", "Einsetzen")
        case .selectAll: ("Select All", "Alles auswählen")
        }
    }

    func text(_ language: AppLanguage) -> String {
        language == .english ? translations.0 : translations.1
    }
}
