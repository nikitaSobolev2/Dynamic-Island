cask "dynamic-island" do
  version "2.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

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

  caveats <<~EOS
    This build is not notarized. After installing, clear Gatekeeper quarantine:

      xattr -cr #{appdir}/Atoll.app
  EOS

  zap trash: [
    "~/Documents/ClipboardData",
    "~/Library/Application Support/DynamicIsland",
    "~/Library/Preferences/com.Ebullioscopic.Atoll.plist",
    "~/Library/Preferences/com.Ebullioscopic.Atoll.dev.plist",
  ]
end
