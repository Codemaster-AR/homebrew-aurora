class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. SMART DOUBLE UNPACK
    # We look for any .tar.gz files that were accidentally put INSIDE the main download.
    # If found, we unpack it right here in the build directory.
    nested_tarball = Dir.glob("**/*.tar.gz").first
    if nested_tarball
      ohai "Detected nested tarball: #{nested_tarball}. Performing secondary extraction..."
      # Unpack the inner tarball and flatten it
      system "tar", "-xzf", nested_tarball, "--strip-components=1" rescue system "tar", "-xzf", nested_tarball
    end

    # 2. SMART FOLDER DETECTION
    # We search recursively (**) for package.json to find the actual app root.
    package_json = Dir.glob("**/package.json").first
    
    if package_json.nil?
      # If we still can't find it, we list the files to help you debug.
      system "ls", "-R"
      odie "Error: Could not find package.json anywhere in the source (even after checking for nested tarballs)."
    end

    # This is the directory where the Node.js app actually lives.
    app_source_dir = File.dirname(package_json)

    # 3. INSTALL DEPENDENCIES (Universal)
    # We use --omit=dev for a smaller installation footprint.
    cd app_source_dir do
      system "npm", "install", "--omit=dev"
    end

    # 4. MOVE TO FINAL LOCATION
    # We move the entire structure into libexec, which Homebrew handles 
    # differently on Mac (/opt/homebrew) vs Linux (/home/linuxbrew).
    libexec.install Dir["*"]

    # 5. OS-SPECIFIC ATTRIBUTE CLEANING
    # macOS puts "quarantine" flags on downloaded files; Linux does not.
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}" rescue nil
    end

    # 6. UNIVERSAL LAUNCHER (Python-based)
    # We re-locate the package.json path inside the final libexec folder.
    final_app_path = Dir.glob("#{libexec}/**/package.json").map { |f| File.dirname(f) }.first

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "Aurora Bioscience is starting..."
          
          # OS-Agnostic UI feedback
          current_os = platform.system()
          if current_os == "Darwin":
              # macOS: Use native AppleScript dialog
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          elif current_os == "Linux":
              # Linux/WSL: Use notify-send if available, otherwise print to terminal
              if os.system("which notify-send > /dev/null 2>&1") == 0:
                  os.system(f'notify-send "Aurora Bioscience" "{msg}"')
              else:
                  print(f"INFO: {msg}")

          # Use the smart-detected path inside the Homebrew Cellar
          app_dir = "#{final_app_path}"
          
          try:
              # Start the Node application using the correct working directory
              subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora Bioscience: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    # 7. MAKE EXECUTABLE
    chmod 0755, bin/"aurora-bioscience"
  end

  test do
    # Simple check to ensure the binary was actually linked
    assert_predicate bin/"aurora-bioscience", :exist?
  end
end