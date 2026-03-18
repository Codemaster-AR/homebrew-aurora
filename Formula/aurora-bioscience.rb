class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. Locate the 'genelab' directory anywhere in the unpacked source
    # This fixes the error if the folder is nested (e.g., inside 'aurora-4.0.0/...')
    genelab_path = Dir.glob("**/genelab").first
    
    if genelab_path.nil?
      odie "Could not find the 'genelab' directory in the source. Please check your repository structure."
    end

    # 2. Run npm install inside that directory
    cd genelab_path do
      system "npm", "install", "--production"
    end

    # 3. Move everything to libexec
    libexec.install Dir["*"]

    # 4. Strip Gatekeeper quarantine on macOS
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}"
    end

    # 5. Create the launcher
    # We re-locate the 'genelab' folder inside the final libexec path
    final_genelab_path = Dir.glob("#{libexec}/**/genelab").first
    
    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "There could be an error. If there is, just press OK."
          if platform.system() == "Darwin":
              os.system(f'osascript -e "display dialog \\"{msg}\\" buttons {{\\"OK\\"}} default button \\"OK\\""')
          else:
              print(f"INFO: {msg}")

          app_dir = "#{final_genelab_path}"
          
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