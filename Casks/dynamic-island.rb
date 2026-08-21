cask "dynamic-island" do
  version "1.2.0"
  sha256 "7a899e1ecc10a4a96937e50f4047555214975391bf8361cde7deb499b9f02644"

  url "https://github.com/nikitaSobolev2/Dynamic-Island/releases/download/v#{version}/DynamicIsland-#{version}.dmg"
  name "Dynamic Island"
  desc "Dynamic Island for macOS"
  homepage "https://github.com/nikitaSobolev2/Dynamic-Island"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Atoll.app"

  uninstall quit: "com.Ebullioscopic.Atoll"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Atoll.app"],
                   must_succeed: false
  end

  caveats <<~EOS
    This build is not notarized. Homebrew removes the quarantine flag after
    install. Accessibility and related permissions persist across upgrades when
    consecutive builds share the same code-signing identity.
  EOS

  zap trash: [
    "~/Documents/ClipboardData",
    "~/Library/Application Support/DynamicIsland",
    "~/Library/Preferences/com.Ebullioscopic.Atoll.plist",
    "~/Library/Preferences/com.Ebullioscopic.Atoll.dev.plist",
  ]
end
