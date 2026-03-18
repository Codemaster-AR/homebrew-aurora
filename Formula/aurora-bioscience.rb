class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. Run npm install at the root (works on Mac & Linux)
    system "npm", "install", "--production"

    # 2. Move everything to libexec
    libexec.install Dir["*"]

    # 3. Strip Gatekeeper quarantine (macOS only)
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}"
    end

    # 4. Create the final launcher script (Cross-Platform)
    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "There could be an error. If there is, just press OK."
          
          # Cross-platform popup/notification logic
          if platform.system() == "Darwin":
              # macOS: Use AppleScript
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          elif platform.system() == "Linux":
              # Linux/WSL: Try to use notify-send (common) or just print to terminal
              if os.system("which notify-send > /dev/null") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          # Use libexec path (Homebrew handles the path difference between Mac and Linux automatically)
          app_dir = "#{libexec}"
          
          try:
              subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end