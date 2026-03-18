class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. MASTER DOUBLE UNPACK
    # Some GitHub releases contain nested tarballs. This ensures we get to the actual source.
    nested_tarball = Dir.glob("**/*.tar.gz").first
    if nested_tarball
      ohai "Detected nested tarball: #{nested_tarball}. Performing secondary extraction..."
      # Attempt to unpack and flatten; fallback to standard unpack if strip-components fails
      system "tar", "-xzf", nested_tarball, "--strip-components=1" rescue system "tar", "-xzf", nested_tarball
    end

    # 2. SMART RECURSIVE FOLDER DETECTION
    # We search the entire unpacked tree for package.json to find the application root.
    package_json = Dir.glob("**/package.json").first
    
    if package_json.nil?
      system "ls", "-R" # Debugging: show what WE actually found
      odie "Error: Could not find package.json anywhere in the source. Check repository structure."
    end

    # The directory where the actual Node.js project lives
    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES & ELECTRON
    # Since 'electron' isn't a standalone Homebrew formula, we install it via npm 
    # directly into the app's local node_modules.
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
      # We explicitly ensure electron is available in the local .bin folder
      system "npm", "install", "electron", "--save-dev"
    end

    # 4. STAGING TO LIBEXEC
    # Move the entire structure (including node_modules) into the Homebrew Cellar.
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING (macOS only)
    if OS.mac?
      # Strips "Downloaded from Internet" flags to prevent security popups
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. MASTER UNIVERSAL LAUNCHER (Python-based)
    # Re-calculate the final path inside libexec where the package.json ended up.
    final_app_path = Dir.glob("#{libexec}/**/package.json").map { |f| File.dirname(f) }.first

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "Aurora Bioscience is starting..."
          
          # OS-Agnostic UI Logic
          current_os = platform.system()
          if current_os == "Darwin":
              # macOS: Use native AppleScript dialog. 
              # Corrected escaping: \\"{msg}\\" treats it as a string, not a variable.
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          elif current_os == "Linux":
              # Linux/WSL: Try notify-send for GUI, fallback to terminal print
              if os.system("which notify-send > /dev/null 2>&1") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          # Path to the application code
          app_dir = "#{final_app_path}"
          
          # Path to the locally installed electron engine
          electron_bin = os.path.join(app_dir, "node_modules", ".bin", "electron")

          # Execution logic
          try:
              if os.path.exists(electron_bin):
                  # Use the specific electron binary we just installed
                  subprocess.run([electron_bin, "."], cwd=app_dir)
              else:
                  # Fallback to npm start if binary is missing
                  subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 7. PERMISSIONS
    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end