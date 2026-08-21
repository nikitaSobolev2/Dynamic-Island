cask "dynamic-island" do
  version "1.3.1"
  sha256 "b2b50ee3e75ba689b49c6fe9dc7a3c62748f2a37a3686ff4bc98b0b94f0d4240"

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
