# XP Subsystem For Linux Roadmap

XPSL is a research boot path for making Linux participate in the NT5/XP BIOS
boot ecosystem. The immediate target is not to run XP inside the MBR; it is to
build a boot pipeline where an XP-compatible MBR can reach NTFS, locate a Linux
loader shim, and then boot Linux from files stored on NTFS.

## Architecture

```text
BIOS
  -> MBR chainloader
      -> active NTFS partition boot sector
          -> NTFS stage loader
              -> XPSLDR
                  -> Linux kernel/initrd or GRUB/Syslinux
```

## Milestones

1. XP-compatible MBR chainloader works in VirtualBox.
   - Find exactly one active MBR partition.
   - Read the partition boot sector with BIOS `int 13h`.
   - Validate the boot signature.
   - Jump to the partition boot sector with the BIOS drive number preserved.

2. NTFS boot-sector stage finds a named file on NTFS.
   - Read the NTFS BPB.
   - Locate the MFT.
   - Read enough root directory/index metadata to find a fixed filename.
   - Load that file into memory.

3. Replace `NTLDR` target semantics with `XPSLDR`.
   - Use a Linux-oriented loader filename.
   - Define a simple handoff ABI from the NTFS stage to `XPSLDR`.
   - Preserve useful BIOS and partition context.

4. Teach `XPSLDR` to boot Linux.
   - Option A: load a Linux kernel and initrd directly using the Linux boot
     protocol.
   - Option B: hand off to GRUB/Syslinux from NTFS.
   - Option C: support both, with GRUB/Syslinux first for faster testing.

5. Explore XP-as-subsystem behavior after Linux boots.
   - Mount the NTFS system volume from Linux.
   - Inspect/use XP boot metadata and files.
   - Later research can target VM, Wine/ReactOS-style compatibility, or a
     controlled XP runtime environment from the NTFS install.

## VirtualBox Target

The current test VM is `P:\VM\Debian`, with a blank 16 GiB flat VMDK. Early
tests should use that disposable disk and should verify one stage at a time.
