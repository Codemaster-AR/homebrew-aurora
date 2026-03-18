class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/Codemaster-AR/aurora"
  # URL for the v4.0.0 release
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "4d17d149eb9af4e24d16e3f699e8b9eed861f67b464e3d4e55d40c0d9349740f"
  version "4.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    # 1. Install all application files into libexec
    libexec.install Dir["*"]

    # 2. Re-install production dependencies inside the installation folder
    cd "#{libexec}/genelab" do
      system "npm", "install", "--production"
    end

    # 3. Strip Gatekeeper quarantine on macOS
    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}"
    end

    # 4. Create the final launcher script in /usr/local/bin/aurora-bioscience
    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          msg = "There could be an error. If there is, just press OK."
          if platform.system() == "Darwin":
              os.system(f"osascript -e 'display dialog "{msg}" buttons {{"OK"}} default button "OK"'")
          else:
              print(f"INFO: {msg}")

          app_dir = "#{libexec}/genelab"
          
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