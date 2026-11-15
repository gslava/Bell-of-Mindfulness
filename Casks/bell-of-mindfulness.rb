cask "bell-of-mindfulness" do
  version "1.0.2"
  sha256 "44bdcf21c436157ee249589e24f5e7ca42b29aa4be4b8c68bd329222a8c2da05"

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
