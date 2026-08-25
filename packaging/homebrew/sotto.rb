cask "sotto" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/ugurcandede/sotto/releases/download/v#{version}/sotto-macos.zip"
  name "sotto"
  desc "Menu bar app to mute your microphone system-wide"
  homepage "https://github.com/ugurcandede/sotto"

  app "sotto.app"

  postflight do
    system "xattr", "-cr", "#{appdir}/sotto.app"
  end

  uninstall quit: "com.ugurcandede.sotto"

  caveats <<~EOS
    sotto needs no permissions to mute your microphone.

    Assigning the microphone key (F5) remaps it with hidutil so that pressing it
    mutes instead of starting Dictation. The remap is removed when you pick
    another key or quit sotto, and it never survives a logout.
  EOS
end
