# Major releases of erlang should typically start out as separate formula in
# Homebrew-versions, and only be merged to master when things like couchdb and
# elixir are compatible.
class Erlang < Formula
  desc "Programming language for highly scalable real-time systems"
  homepage "https://www.erlang.org/"
  head "https://github.com/erlang/otp.git"

  stable do
    # Download tarball from GitHub; it is served faster than the official tarball.
    url "https://github.com/erlang/otp/archive/OTP-19.0.tar.gz"
    sha256 "107b629aa7aea1bf76df0197629a50ce4fea61143ebb0e9a1b633b1fbaf9beb7"
  end

  bottle do
    cellar :any
    sha256 "3df1ac0cb76ea2d0511dbd7d42d536b486098251c84afbf5eb39cd658d229b4d" => :el_capitan
    sha256 "25d81e60062d18590d837356527bde513fa69a7d82a86fd979dea931545bc8d6" => :yosemite
    sha256 "c9bb4cf2ad9b4bd8c55518e4dbad390299bc3ec0539a4304f03ee7b00ddaaece" => :mavericks
  end

  option "without-hipe", "Disable building hipe; fails on various OS X systems"
  option "with-native-libs", "Enable native library compilation"
  option "with-dirty-schedulers", "Enable experimental dirty schedulers"
  option "without-docs", "Do not install documentation"

  deprecated_option "disable-hipe" => "without-hipe"
  deprecated_option "no-docs" => "without-docs"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "openssl"
  depends_on "fop" => :optional # enables building PDF docs
  depends_on "wxmac" => :recommended # for GUI apps like observer

  fails_with :llvm

  resource "man" do

    url "https://www.erlang.org/download/otp_doc_man_19.0.tar.gz"
    sha256 "c7a3d6d85a5a2b96d844297a3fa1bee448c3dd86237734688466249fd5a1401e"
  end

  resource "html" do
    url "https://www.erlang.org/download/otp_doc_html_19.0.tar.gz"
    sha256 "b6f7c4e964673333f6c3eea8530dd988b41339b8912ae293f6f1b429489159ff"
  end

  def install
    # Unset these so that building wx, kernel, compiler and
    # other modules doesn't fail with an unintelligable error.
    %w[LIBS FLAGS AFLAGS ZFLAGS].each { |k| ENV.delete("ERL_#{k}") }

    ENV["FOP"] = "#{HOMEBREW_PREFIX}/bin/fop" if build.with? "fop"

    # Do this if building from a checkout to generate configure
    system "./otp_build", "autoconf" if File.exist? "otp_build"

    args = %W[
      --disable-debug
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-kernel-poll
      --enable-threads
      --enable-sctp
      --enable-dynamic-ssl-lib
      --with-ssl=#{Formula["openssl"].opt_prefix}
      --enable-shared-zlib
      --enable-smp-support
    ]

    args << "--enable-darwin-64bit" if MacOS.prefer_64_bit?
    args << "--enable-native-libs" if build.with? "native-libs"
    args << "--enable-dirty-schedulers" if build.with? "dirty-schedulers"
    args << "--enable-wx" if build.with? "wxmac"

    if MacOS.version >= :snow_leopard && MacOS::CLT.installed?
      args << "--with-dynamic-trace=dtrace"
    end

    if build.without? "hipe"
      # HIPE doesn't strike me as that reliable on OS X
      # https://syntatic.wordpress.com/2008/06/12/macports-erlang-bus-error-due-to-mac-os-x-1053-update/
      # https://www.erlang.org/pipermail/erlang-patches/2008-September/000293.html
      args << "--disable-hipe"
    else
      args << "--enable-hipe"
    end

    system "./configure", *args
    system "make"
    ENV.j1 # Install is not thread-safe; can try to create folder twice and fail
    system "make", "install"

    if build.with? "docs"
      (lib/"erlang").install resource("man").files("man")
      doc.install resource("html")
    end
  end

  def caveats; <<-EOS.undent
    Man pages can be found in:
      #{opt_lib}/erlang/man

    Access them with `erl -man`, or add this directory to MANPATH.
    EOS
  end

  test do
    system "#{bin}/erl", "-noshell", "-eval", "crypto:start().", "-s", "init", "stop"
  end
end
