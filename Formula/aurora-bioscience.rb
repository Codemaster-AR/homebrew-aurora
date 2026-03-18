class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  # Core dependencies for the environment
  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. MASTER DOUBLE UNPACK
    # Your GitHub release has a tarball inside a tarball. 
    # This finds the inner .tar.gz and extracts it into the current build directory.
    nested_tarball = Dir.glob("**/*.tar.gz").first
    if nested_tarball
      ohai "Detected nested tarball: #{nested_tarball}. Performing secondary extraction..."
      # Unpack the inner tarball and attempt to flatten the structure
      system "tar", "-xzf", nested_tarball
    end

    # 2. SMART RECURSIVE FOLDER DETECTION
    # We search the entire directory tree (**) specifically for the 'genelab' folder
    # which we now know contains your package.json.
    package_json = Dir.glob("**/genelab/package.json").first
    
    if package_json.nil?
      # Fallback: search for ANY package.json if 'genelab' isn't found
      package_json = Dir.glob("**/package.json").first
    end

    if package_json.nil?
      # If still not found, list the files to help with terminal debugging
      system "ls", "-R"
      odie "Error: Could not find package.json anywhere in the source (even after checking for nested tarballs)."
    end

    # This is the directory where the Node.js application actually lives.
    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES & ELECTRON (Universal)
    # We use --omit=dev for a smaller footprint, then force-install electron
    # because it is not a standalone Homebrew formula.
    cd app_source_dir do
      ohai "Running npm install in: #{Dir.pwd}"
      system "npm", "install", "--omit=dev"
      # We explicitly ensure electron is available in the local node_modules/.bin folder
      system "npm", "install", "electron", "--save-dev"
    end

    # 4. STAGING TO LIBEXEC
    # We move the entire structure into libexec, which Homebrew handles 
    # differently on Mac (/opt/homebrew) vs Linux (/home/linuxbrew).
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING (macOS only)
    # This prevents the "App is damaged" or "Unknown Developer" errors on Mac.
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. UNIVERSAL MASTER LAUNCHER (Python-based)
    # We re-calculate the final path inside libexec where the package.json ended up.
    final_app_path = Dir.glob("#{libexec}/**/genelab").first || Dir.glob("#{libexec}/**/package.json").map { |f| File.dirname(f) }.first

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "Aurora Bioscience is starting..."
          
          # OS-Agnostic UI feedback logic
          current_os = platform.system()
          if current_os == "Darwin":
              # macOS: Use native AppleScript dialog.
              # Escape fix: Using single quotes for the shell command and escaped double quotes
              # for the AppleScript string to prevent "variable not defined" errors.
              cmd = f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button 1"'
              os.system(cmd)
          elif current_os == "Linux":
              # Linux/WSL: Use notify-send if available, otherwise print to terminal
              if os.system("which notify-send > /dev/null 2>&1") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          # Path to the actual application code within the Homebrew Cellar
          app_dir = "#{final_app_path}"
          
          # Path to the locally installed electron binary
          electron_bin = os.path.join(app_dir, "node_modules", ".bin", "electron")

          # Final execution attempt
          try:
              if os.path.exists(electron_bin):
                  # Best method: Run electron directly in the app directory
                  subprocess.run([electron_bin, "."], cwd=app_dir)
              else:
                  # Fallback: Use npm start if for some reason the binary isn't found
                  subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 7. MAKE EXECUTABLE
    # Ensures the launcher script can be run by the system.
    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    # Simple check to ensure the binary was actually linked and exists
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end