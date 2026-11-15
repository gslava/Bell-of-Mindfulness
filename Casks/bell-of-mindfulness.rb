cask "bell-of-mindfulness" do
  version "1.0.0"
  sha256 "92c2c44dc0aa9ddd4a482ae71a376e91634ea36f19f7b5c307254a94727660fb"

  url "https://github.com/gslava/Bell-of-Mindfulness/releases/download/v#{version}/Bell-of-Mindfulness-#{version}-universal.zip"
  name "Bell of Mindfulness"
  desc "Menu bar singing bowl reminder with adjustable intervals and quiet hours"
  homepage "https://github.com/gslava/Bell-of-Mindfulness"

  depends_on macos: :sonoma

  app "Bell of Mindfulness.app"

  uninstall quit: "com.gslava.BellOfMindfulness"

  caveats <<~EOS
    The app is ad-hoc signed and not notarized by Apple.
    macOS may require approval in System Settings > Privacy & Security on first launch.
    Quit Bell of Mindfulness before upgrading, then reopen it from Applications.
  EOS
end
