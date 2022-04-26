{
  nixpkgs,
  php-src,
}:

# These are older versions of PHP removed from Nixpkgs.

final:
prev:

let
  packageOverrides = import ./package-overrides.nix prev;

  /* Composes package overrides (i.e. overlays that only take prev). */
  composeOverrides = a: b: prev.lib.composeExtensions (_: a) (_: b) { };

  _mkArgs =
    args:

    args
    // {
      inherit packageOverrides;

      # For passing pcre2 to generic.nix.
      pcre2 =
        if prev.lib.versionAtLeast args.version "7.3"
        then prev.pcre2
        else prev.pcre;

      # Overrides attributes passed to the stdenv.mkDerivation for the unwrapped PHP
      # in <nixpkgs/pkgs/development/interpreters/php/generic.nix>.
      # This will essentially end up creating a derivation equivalent to the following:
      # stdenv.mkDerivation (versionSpecificOverrides (commonOverrides { /* stuff passed to mkDerivation in generic.nix */ }))
      phpAttrsOverrides =
        let
          commonOverrides =
            attrs:

            {
              patches =
                attrs.patches or []
                ++ prev.lib.optionals (prev.lib.versions.majorMinor args.version == "7.2") [
                  # Building the bundled intl extension fails on Mac OS.
                  # See https://bugs.php.net/bug.php?id=76826 for more information.
                  (prev.pkgs.fetchpatch {
                    url = "https://bugs.php.net/patch-display.php?bug_id=76826&patch=bug76826.poc.0.patch&revision=1538723399&download=1";
                    sha256 = "aW+MW9Kb8N/yBO7MdqZMZzgMSF7b+IMLulJKgKPWrUA=";
                  })
                ];

              configureFlags =
                attrs.configureFlags
                ++ prev.lib.optionals (prev.lib.versionOlder args.version "7.4") [
                  # phar extension’s build system expects hash or it will degrade.
                  "--enable-hash"

                  "--enable-libxml"
                  "--with-libxml-dir=${prev.libxml2.dev}"
                ];

              preConfigure =
                prev.lib.optionalString (prev.lib.versionOlder args.version "7.4") ''
                  # Workaround “configure: error: Your system does not support systemd.”
                  # caused by PHP build system expecting PKG_CONFIG variable to contain
                  # an absolute path on PHP ≤ 7.4.
                  # Also patches acinclude.m4, which ends up being used by extensions.
                  # https://github.com/NixOS/nixpkgs/pull/90249
                  for i in $(find . -type f -name "*.m4"); do
                    substituteInPlace $i \
                      --replace 'test -x "$PKG_CONFIG"' 'type -P "$PKG_CONFIG" >/dev/null'
                  done
                ''
                + attrs.preConfigure;
            };

          versionSpecificOverrides = args.phpAttrsOverrides or (attrs: { });
        in
        composeOverrides commonOverrides versionSpecificOverrides;

      # For passing pcre2 to php-packages.nix.
      callPackage =
        cpFn:
        cpArgs:

        prev.callPackage
          cpFn
          (
            cpArgs
            // {
              pcre2 =
                if prev.lib.versionAtLeast args.version "7.3"
                then prev.pcre2
                else prev.pcre;

              # For passing pcre2 to stuff called with callPackage in php-packages.nix.
              pkgs =
                prev
                // (
                  prev.lib.makeScope
                    prev.newScope
                    (self: {
                      pcre2 =
                        if prev.lib.versionAtLeast args.version "7.3"
                        then prev.pcre2
                        else prev.pcre;
                    })
                );
            }
          );
    };

  generic = "${nixpkgs}/pkgs/development/interpreters/php/generic.nix";
  mkPhp = args: prev.callPackage generic (_mkArgs args);
in
{
  php56 = import ./php/5.6.nix { inherit prev mkPhp; };

  php70 = import ./php/7.0.nix { inherit prev mkPhp; };

  php71 = import ./php/7.1.nix { inherit prev mkPhp; };

  php72 = import ./php/7.2.nix { inherit prev mkPhp; };

  php73 = import ./php/7.3.nix { inherit prev mkPhp; };

  php74 = import ./php/7.4.nix { inherit prev mkPhp; };

  php80 = prev.php80.override {
    inherit packageOverrides;
  };

  php81 = prev.php81.override {
    inherit packageOverrides;
  };

  php-master = base-master.withExtensions (
    { all, ... }:

    with all; (
      [
        bcmath
        calendar
        curl
        ctype
        dom
        exif
        fileinfo
        filter
        ftp
        gd
        gettext
        gmp
        iconv
        intl
        ldap
        mbstring
        mysqli
        mysqlnd
        opcache
        openssl
        pcntl
        pdo
        pdo_mysql
        pdo_odbc
        pdo_pgsql
        pdo_sqlite
        pgsql
        posix
        readline
        session
        simplexml
        sockets
        soap
        sodium
        sqlite3
        tokenizer
        xmlreader
        xmlwriter
        zip
        zlib
      ]
      ++ prev.lib.optionals (!prev.stdenv.isDarwin) [
        imap
      ]
    )
  );
}
