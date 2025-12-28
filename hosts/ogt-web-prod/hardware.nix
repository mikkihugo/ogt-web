{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/3EB9-886F"; fsType = "vfat"; };
  
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" ];
  boot.initrd.kernelModules = [ "nvme" ];
}
