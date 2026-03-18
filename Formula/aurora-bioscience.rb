class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. SMART FOLDER DETECTION:
    # Look for package.json anywhere in the unpacked source.
    package_json = Dir.glob("**/package.json").first
    
    if package_json.nil?
      odie "Error: Could not find package.json in the source. Ensure your repository contains a Node.js project."
    end

    # Determine the actual root of the app (where package.json lives)
    app_source_dir = File.dirname(package_json)

    # 2. RUN INSTALL:
    # Perform npm install inside the discovered folder
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
    end

    # 3. STAGING:
    # Move everything into the Homebrew libexec folder
    libexec.install Dir["*"]

    # 4. OS-SPECIFIC CLEANUP:
    # Only run macOS-specific attribute cleaning if on a Mac
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 5. UNIVERSAL LAUNCHER:
    # We find where the app ended up inside libexec to hardcode the correct path
    installed_app_path = Dir.glob("#{libexec}/**/package.json").map { |f| File.dirname(f) }.first

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "Launching Aurora Bioscience... If an error popup appears, just click OK."
          
          # OS-Agnostic Messaging
          sys_name = platform.system()
          if sys_name == "Darwin":
              # macOS Dialog
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          elif sys_name == "Linux":
              # Linux/WSL Notification (if notify-send exists)
              if os.system("which notify-send > /dev/null 2>&1") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          # Use the smart-detected path
          app_dir = "#{installed_app_path}"
          
          try:
              # Start the Node application
              subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # Make the launcher executable
    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    # Basic check to see if the command was created
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end