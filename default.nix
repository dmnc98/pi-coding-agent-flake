{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
  stdenvNoCC,
  cacert,
}:

let
  pname = "pi-coding-agent";
  version = "0.77.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-EFOKehAW6zEIyx72Xb9t4uMdJvLAka455W72qcIaTDE=";
  };

  # Upstream tarball ships an old lockfileVersion-1 npm-shrinkwrap.json that
  # prefetch-npm-deps can't parse. Regenerate a v3 lockfile via npm's resolver.
  # This needs network, so it's a fixed-output derivation.
  packageLock = stdenvNoCC.mkDerivation {
    name = "${pname}-${version}-package-lock";
    inherit src;

    nativeBuildInputs = [ nodejs_22 cacert ];
    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      rm -f npm-shrinkwrap.json package-lock.json
      HOME=$TMPDIR npm install \
        --package-lock-only \
        --ignore-scripts \
        --no-audit \
        --no-fund
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp package-lock.json $out/
      runHook postInstall
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-IVQH9cN3NKmEc8tpsP7H2wYOm3Qmanjv02qoxwcD/z0=";
  };
in
buildNpmPackage {
  inherit pname version src;

  postPatch = ''
    rm -f npm-shrinkwrap.json
    cp ${packageLock}/package-lock.json package-lock.json
  '';

  npmDepsHash = "sha256-yr74CFu2qZKXpr9urVVvssLOBJNplFO24iWzeGjWV04=";

  # dist/ is prebuilt; matches upstream's `npm install -g --ignore-scripts`.
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  nodejs = nodejs_22;

  nativeBuildInputs = [ makeWrapper ];

  # Ensure `pi install npm:<pkg>` spawns the bundled Linux npm, not Windows
  # npm.cmd that WSL interop would otherwise resolve from $PATH.
  postFixup = ''
    wrapProgram $out/bin/pi --prefix PATH : ${nodejs_22}/bin
  '';

  meta = {
    description = "Minimal terminal coding harness (Pi Coding Agent)";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = lib.platforms.unix;
  };
}
