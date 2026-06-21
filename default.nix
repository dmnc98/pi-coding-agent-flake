{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
}:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.79.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-ygNsI/iP0oG5jgzw79AenGAx3kYEC1bVjLBHR5NnvYw=";
  };

  # Upstream tarball ships an old lockfileVersion-1 npm-shrinkwrap.json that
  # prefetch-npm-deps can't parse. We vendor a regenerated lockfileVersion-3
  # package-lock.json next to this file so the build is fully deterministic —
  # no network resolver, no drifting hash. Refresh it on every version bump.
  postPatch = ''
    rm -f npm-shrinkwrap.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-RHrSpcyny+ozHJUQFFkYDfPTDO4Fs/3nJ7joAZqztyk=";

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
