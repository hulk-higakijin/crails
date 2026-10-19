desc "Compile app to a native binary via Roundhouse spinel target and Spinel"
task compile: :environment do
  require "shellwords"

  out = ENV.fetch("OUT", "out/spinel")
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
  end

  puts "Done. Binary: #{out}/build/blog"
  puts "Run from the emitted root: cd #{out} && ./build/blog"
end
