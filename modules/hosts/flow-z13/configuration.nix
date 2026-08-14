{
  self,
  inputs,
  ...
}: {
  flake.nixosModules."flow-z13Configuration" = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules."flow-z13Hardware"
      self.nixosModules.base
      self.nixosModules.devices
      self.nixosModules.desktop
      self.nixosModules.printing

      self.nixosModules.networking
      self.nixosModules."programs-3d"
    ];

    networking.hostName = "flow-z13";

    # bootloader
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = 1;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # faster initrd: systemd stage-1 + zstd compression
    boot.initrd.systemd.enable = true;
    boot.initrd.compressor = "zstd";

    # skip waiting for a full network connection before declaring boot done
    systemd.services.NetworkManager-wait-online.enable = false;

    # graphics + Intel iGPU power saving
    boot.kernelParams = [
      "nvidia_drm.fbdev=1"
      "nvidia_drm.modeset=1"
      "i915.enable_psr=1" # panel self-refresh
      "i915.enable_fbc=1" # framebuffer compression
      "mem_sleep_default=deep" # S3 deep sleep on suspend
    ];
    # preserve GPU memory across suspend so nvidia-modeset can resume cleanly
    boot.extraModprobeConfig = ''
      options nvidia NVreg_PreserveVideoMemoryAllocations=1
      options nvidia NVreg_TemporaryFilePath=/var/tmp
      options nvidia NVreg_DynamicPowerManagementVideoMemoryThreshold=0
    '';
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
    };
    hardware.nvidia = {
      open = false;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0@0:2:0";
        nvidiaBusId = "PCI:1@0:0:0";
      };
    };
    services.xserver.videoDrivers = [
      "modesetting"
      "nvidia"
    ];

    # battery and asus stuff
    services.upower.enable = true;
    services.asusd.enable = true;
    # supergfxd persists the GPU mode across reboots in /etc/asusd/supergfxd.conf
    # do NOT set a default mode here so manual changes (Integrated/Hybrid/etc.) survive rebuilds
    services.supergfxd.enable = true;

    # suspend on lid close (logind defaults to ignore on Wayland without a DE)
    services.logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
    };

    # dynamic CPU frequency + turbo boost based on load and AC/battery state
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "powersave";
        turbo = "auto";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };

    # SD card reader disabled — unused; caused sdhci errors on resume
    # re-enable by uncommenting below and removing the blacklist
    boot.blacklistedKernelModules = ["sdhci_pci"];
    # systemd.services.sdhci-resume = {
    #   description = "Reload sdhci_pci after resume";
    #   after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    #   wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "/bin/sh -c 'modprobe -r sdhci_pci && modprobe sdhci_pci'";
    #   };
    # };

    networking.networkmanager.enable = true;

    users.users.dazza = {
      isNormalUser = true;
      description = "Daren Drahos";
      extraGroups = ["networkmanager" "wheel"];
      packages = with pkgs; [
      ];
    };

    environment.systemPackages = with pkgs; [
    ];

    system.stateVersion = "25.05"; # Did you read the comment?
  };
}
