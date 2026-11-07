# GPU pods on k3s through CDI. The NVIDIA device plugin counts the GPU for the scheduler
# (`nvidia.com/gpu: 1`), and the `nvidia-cdi` runtime handler injects the device from
# the CDI spec that `hardware.nvidia-container-toolkit` already generates for Docker.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # k3s maps known binary names on PATH to handlers (pkg/agent/containerd/runtimes.go).
  # Expose only CDI: the legacy wrapper needs nvidia-container-cli, absent on NixOS.
  toolkitTools = pkgs.runCommand "k3s-nvidia-cdi-runtime" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime.cdi "$out/bin/"
  '';
  cdiGenerator = "nvidia-container-toolkit-cdi-generator.service";
  # The handler for `nvidia-container-runtime.cdi`. The plain `nvidia` handler resolves to
  # legacy mode, which needs nvidia-container-cli that NixOS does not ship.
  runtimeClass = "nvidia-cdi";
in
{
  config = lib.mkIf config.hardware.nvidia-container-toolkit.enable {
    systemd.services.k3s = {
      path = [ toolkitTools ];
      # Pods started right after boot need the spec in /var/run/cdi.
      after = [ cdiGenerator ];
      wants = [ cdiGenerator ];
    };

    services.k3s.autoDeployCharts.nvidia-device-plugin = {
      repo = "https://nvidia.github.io/k8s-device-plugin/stable";
      name = "nvidia-device-plugin";
      version = "0.20.1";
      hash = "sha256-twUULwOsF5Br/PrOkxni97mlcNKvfwTyMlJyPOLAu44=";
      targetNamespace = "kube-system";
      values = {
        runtimeClassName = runtimeClass;
        # This single-node cluster has no NFD labels; do not require them to schedule.
        affinity = null;
        nfd.enabled = false;
        tolerations = [
          {
            key = "nvidia.com/gpu";
            operator = "Exists";
            effect = "NoSchedule";
          }
        ];
        deviceListStrategy = "envvar";
        deviceIDStrategy = "index";
        failOnInitError = true;
        image.tag = "v0.20.1@sha256:27c1b2553a690ca3d29889dcd61df97525d46f58272c0be8dc63c2b18f120075";
        # The chart unconditionally sets NVIDIA_VISIBLE_DEVICES=all for NVML access.
      };
    };

    services.k3s.manifests.nvidia-gpu-policy.content = [
      {
        apiVersion = "node.k8s.io/v1";
        kind = "RuntimeClass";
        metadata.name = runtimeClass;
        handler = runtimeClass;
      }
      # Without the handler a GPU pod schedules but gets no device or driver libraries.
      {
        apiVersion = "admissionregistration.k8s.io/v1";
        kind = "ValidatingAdmissionPolicy";
        metadata.name = "gpu-pods-use-${runtimeClass}";
        spec = {
          failurePolicy = "Fail";
          matchConstraints.resourceRules = [
            {
              apiGroups = [ "" ];
              apiVersions = [ "v1" ];
              operations = [
                "CREATE"
                "UPDATE"
              ];
              resources = [ "pods" ];
            }
          ];
          validations = [
            {
              expression = ''
                !(object.spec.containers + (has(object.spec.initContainers) ? object.spec.initContainers : []))
                  .exists(c, has(c.resources) && has(c.resources.limits) && 'nvidia.com/gpu' in c.resources.limits)
                || (has(object.spec.runtimeClassName) && object.spec.runtimeClassName == '${runtimeClass}')
              '';
              message = "pods requesting nvidia.com/gpu must set runtimeClassName: ${runtimeClass}";
            }
          ];
        };
      }
      {
        apiVersion = "admissionregistration.k8s.io/v1";
        kind = "ValidatingAdmissionPolicyBinding";
        metadata.name = "gpu-pods-use-${runtimeClass}";
        spec = {
          policyName = "gpu-pods-use-${runtimeClass}";
          validationActions = [ "Deny" ];
        };
      }
    ];
  };
}
