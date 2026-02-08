{
  lib,
  rustPlatform,
  fetchFromGitHub,

  # nativeBuildInputs
  pkg-config,
  autoPatchelfHook,
  autoAddDriverRunpath,

  # buildInputs
  openssl,
  onnxruntime,

  cudaPackages ? { },
  cudaCapability ? null,

  config,
  cudaSupport ? config.cudaSupport,
}:

let

  # TEI requires compute capability >= 8.0 for flash attention v2
  minRequiredCudaCapability = "8.0";
  inherit (cudaPackages.flags or { cudaCapabilities = [ ]; }) cudaCapabilities;
  cudaCapabilityString =
    if cudaCapability == null then
      (builtins.head (
        (builtins.filter (cap: lib.versionAtLeast cap minRequiredCudaCapability) cudaCapabilities)
        ++ [
          (lib.warn "text-embeddings-inference doesn't support ${lib.concatStringsSep " " cudaCapabilities}" minRequiredCudaCapability)
        ]
      ))
    else
      cudaCapability;
  cudaCapability' =
    if cudaSupport then
      lib.toInt ((cudaPackages.flags or { }).dropDots or (_: "80") cudaCapabilityString)
    else
      0;

in
rustPlatform.buildRustPackage {
  pname = "text-embeddings-inference";
  version = "1.8.3";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "huggingface";
    repo = "text-embeddings-inference";
    rev = "v1.8.3";
    hash = "sha256-Z6dNThzIHCKbiuyGTbvhZ9Wc2cbsxEp4nRTAOUqbuow=";
  };

  cargoHash = "sha256-9DOPHt6SoCTJpKRujDBr8vBvFT+YHA3hHFsLW2EOcxc=";

  buildAndTestSubdir = "router";

  nativeBuildInputs = [
    pkg-config
  ]
  ++ lib.optionals cudaSupport [
    # WARNING: autoAddDriverRunpath must run AFTER autoPatchelfHook
    autoPatchelfHook
    autoAddDriverRunpath
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals (!cudaSupport) [
    onnxruntime
  ]
  ++ lib.optionals cudaSupport [
    cudaPackages.cuda_cccl
    cudaPackages.cuda_cudart
    cudaPackages.cuda_nvrtc
    cudaPackages.libcublas
    cudaPackages.libcurand
  ];

  buildNoDefaultFeatures = true;
  buildFeatures = [
    "http"
    "candle"
  ]
  ++ lib.optionals (!cudaSupport) [ "ort" ]
  ++ lib.optionals cudaSupport [
    "candle-cuda"
    "dynamic-linking"
  ];

  env =
    lib.optionalAttrs (!cudaSupport) {
      ORT_STRATEGY = "system";
      ORT_LIB_LOCATION = "${onnxruntime}/lib";
    }
    // lib.optionalAttrs cudaSupport {
      CUDA_COMPUTE_CAP = cudaCapability';
      CUDA_TOOLKIT_ROOT_DIR = lib.getDev cudaPackages.cuda_cudart;
    };

  appendRunpaths = lib.optionals cudaSupport [
    (lib.makeLibraryPath [ cudaPackages.libcublas ])
  ];

  # libcuda.so.1 is provided by the driver at runtime
  autoPatchelfIgnoreMissingDeps = lib.optionals cudaSupport [ "libcuda.so.1" ];

  # Tests require GPU or specific model downloads
  doCheck = false;

  meta = {
    description =
      "High-performance text embeddings inference" + lib.optionalString cudaSupport " (CUDA)";
    homepage = "https://github.com/huggingface/text-embeddings-inference";
    license = lib.licenses.asl20;
    platforms = if cudaSupport then lib.platforms.linux else lib.platforms.unix;
    mainProgram = "text-embeddings-router";
  };
}
