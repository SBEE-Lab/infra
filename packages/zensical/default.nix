{
  lib,
  buildPythonPackage,
  fetchPypi,
  cargo,
  rustPlatform,
  rustc,
  libiconv,
  stdenv,
  # Python dependencies
  click,
  deepmerge,
  markdown,
  pymdown-extensions,
  pygments,
  pyyaml,
  tomli,
}:
buildPythonPackage rec {
  pname = "zensical";
  version = "0.0.20";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-lenpdKaLTuqWo2WzVH85mtIvaQaEh5blZnKIwUu2JUk=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    name = "${pname}-${version}";
    hash = "sha256-rN9A45qHcDW9tk352u2/upuCnSt7UZez+6IHameTwKA=";
  };

  nativeBuildInputs = [
    cargo
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
    rustc
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  propagatedBuildInputs = [
    click
    deepmerge
    markdown
    pygments
    pymdown-extensions
    pyyaml
    tomli
  ];

  pythonImportsCheck = [ "zensical" ];

  meta = with lib; {
    description = "A modern static site generator built by the creators of Material for MkDocs";
    homepage = "https://zensical.org/";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
