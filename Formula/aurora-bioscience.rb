class AuroraBioscience < Formula
  desc "Launcher for the Aurora Bioscience Dashboard"
  homepage "https://github.com/your-username/aurora"
  # PASTE YOUR GITHUB RELEASE URL HERE
  url "https://github.com/Codemaster-AR/aurora/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "af5faada4e05c7f4dfcf4aa66ea58b42f640dce18c8f6183362a301eecb5a2ee"
  version "2.0.0"

  depends_on "node"
  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]

    cd "#{libexec}/genelab" do
      system "npm", "install", "--production"
    end

    if OS.mac?
      system "xattr", "-rd", "com.apple.quarantine", "#{libexec}"
    end

    (bin/"aurora-bioscience").write <<~EOS
      #!/usr/bin/env python3
      import os, subprocess, sys, platform
      def main():
          msg = "There could be an error. If there is, just press OK."
          if platform.system() == "Darwin":
              os.system(f"osascript -e 'display dialog \\\"{msg}\\\" buttons {{\\\"OK\\\"}} default button \\\"OK\\\"'")
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