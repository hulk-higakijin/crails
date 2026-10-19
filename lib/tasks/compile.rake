desc "Compile app to a native binary via Roundhouse spinel target and Spinel"
task compile: :environment do
  require "shellwords"
  require "fileutils"

  out = ENV.fetch("OUT", "out/spinel")
  # Roundhouse's spinel target names the binary after its own scaffold
  # (bin/blog.rb -> build/blog), not after this app. BIN_NAME lets the
  # caller pick the file name; it defaults to the app directory name so
  # `bin/rails compile` in crails reports build/crails instead of blog.
  bin_name = ENV.fetch("BIN_NAME", File.basename(File.expand_path(".")))
  skip_check = ENV["SKIP_CHECK"] == "1"
  skip_assets = ENV["SKIP_ASSETS"] == "1"
  skip_build = ENV["SKIP_BUILD"] == "1"

  tools = %w[roundhouse spinel spin make]
  missing = tools.reject { |bin| system("command -v #{Shellwords.escape(bin)} >/dev/null 2>&1") }
  unless missing.empty?
    abort "Missing tools on PATH: #{missing.join(", ")}. Install roundhouse, spinel/spin, and make first."
  end

  unless skip_check
    puts "==> roundhouse check --continue ."
    sh "roundhouse check --continue ."
  end

  puts "==> roundhouse --target spinel . -o #{out}"
  FileUtils.mkdir_p(out)
  sh "roundhouse --target spinel . -o #{Shellwords.escape(out)}"

  built = nil
  Dir.chdir(out) do
    puts "==> bundle install (emitted tree)"
    sh "bundle install"

    unless skip_assets
      puts "==> make assets"
      sh "make assets"
    end

    unless skip_build
      puts "==> make build"
      sh "make build"
    end

    unless skip_build
      # Find whatever the emitted Makefile actually produced instead of
      # assuming build/blog: spin lays executables under build/bin/* and
      # the Makefile copies one up to build/*.
      candidates = Dir.glob(File.join("build", "bin", "*")).select do |f|
        File.file?(f) && File.executable?(f)
      end
      if candidates.empty?
        candidates = Dir.glob(File.join("build", "*")).select do |f|
          File.file?(f) && File.executable?(f)
        end
      end
      built = candidates.first
      if built && File.basename(built) != bin_name
        FileUtils.cp(built, File.join("build", bin_name))
        built = File.join("build", bin_name)
      end
    end
  end

  if built
    puts "Done. Binary: #{out}/#{built}"
    puts "Run from the emitted root: cd #{out} && ./#{built}"
  else
    puts "Done. Emit finished in #{out} (build skipped or produced no binary)."
  end
end
