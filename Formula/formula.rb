class Aurora < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/your-username/aurora"
  # PASTE YOUR RELEASE LINK BELOW
  url "https://github.com/your-username/aurora/releases/download/v1.0.0/aurora-1.0.0.tar.gz"
  sha256 "ef9b71d9178eabe4b8beef7e241f0588f7615ff2c105de984feee9641ff84202"
  version "1.0.0"

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

    # 4. Create the final launcher script in /usr/local/bin/aurora
    (bin/"aurora").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform

      def main():
          # Display the requested user message
          msg = "There could be an error. If there is, just press OK."
          if platform.system() == "Darwin":
              os.system(f"osascript -e 'display dialog \\\"{msg}\\\" buttons {{\\\"OK\\\"}} default button \\\"OK\\\"'")
          else:
              print(f"INFO: {msg}")

          # Path to the application files in Homebrew's libexec
          app_dir = "#{libexec}/genelab"
          
          try:
              # Start the Electron GUI via npm
              subprocess.run(["npm", "start"], cwd=app_dir)
          except Exception as e:
              print(f"Error launching Aurora: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
    EOS

    chmod 0755, bin/"aurora"
  end

  test do
    assert_predicate bin/"aurora", :exist?
  end
end