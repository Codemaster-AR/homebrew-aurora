class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"
  # FIX: Electron is required to run the dashboard
  depends_on "electron"

  def install
    # 1. SMART DOUBLE UNPACK
    nested_tarball = Dir.glob("**/*.tar.gz").first
    if nested_tarball
      ohai "Detected nested tarball: #{nested_tarball}. Performing secondary extraction..."
      system "tar", "-xzf", nested_tarball, "--strip-components=1" rescue system "tar", "-xzf", nested_tarball
    end

    # 2. SMART FOLDER DETECTION
    package_json = Dir.glob("**/package.json").first
    if package_json.nil?
      system "ls", "-R"
      odie "Error: Could not find package.json anywhere in the source."
    end

    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
    end

    # 4. MOVE TO FINAL LOCATION
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING (macOS only)
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. UNIVERSAL LAUNCHER
    # Locate where the app settled inside libexec
    final_app_path = Dir.glob("#{libexec}/**/package.json").map { |f| File.dirname(f) }.first

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "Aurora Bioscience is starting..."
          
          current_os = platform.system()
          if current_os == "Darwin":
              # FIX: Correctly escaped AppleScript string to avoid 'variable not defined' error
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          elif current_os == "Linux":
              if os.system("which notify-send > /dev/null 2>&1") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          app_dir = "#{final_app_path}"
          
          # FIX: We find the Homebrew-installed Electron binary to ensure it works on all OSs
          # Homebrew Prefix is usually /opt/homebrew (Mac) or /home/linuxbrew/.linuxbrew (Linux)
          hb_prefix = "#{HOMEBREW_PREFIX}"
          electron_bin = os.path.join(hb_prefix, "bin", "electron")

          try:
              # We use 'electron .' directly to ensure it uses the engine Homebrew just installed
              subprocess.run([electron_bin, "."], cwd=app_dir)
          except FileNotFoundError:
              # Fallback to npm start if electron binary isn't found directly
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