# Linux NTFS MBR Bootloader / XPSL

Research bootloader work for an XP-compatible BIOS/MBR boot path that can read
from NTFS and load a Linux-oriented shim named `XPSLDR`.

The long-term idea is **XP Subsystem For Linux**: make Linux able to participate
in an NT5/Windows XP-style boot environment, using NTFS as the boot volume and
eventually handing off to a Linux kernel, initrd, GRUB, or Syslinux payload.

This repository is currently a proof of concept, not a production bootloader.

## What Works Now

The current VirtualBox proof demonstrates this chain:

```text
BIOS
  -> MBR / partition boot path
      -> NTFS-aware boot stage
          -> finds XPSLDR by filename in NTFS metadata
              -> loads XPSLDR from NTFS resident data
                  -> jumps to XPSLDR
```

In the test VM, the boot code prints checkpoint letters while it walks the NTFS
metadata, then transfers execution to `XPSLDR`, which prints:

```text
XPSLDR loaded from NTFS
```

This proves the central bootloader idea: a BIOS boot path can locate a named
loader file on an NTFS partition and execute it without depending on `NTLDR`.

## Current Limits

The NTFS volume used for the proof is synthetic and intentionally tiny. It is
created directly by `tools/write-synthetic-ntfs.ps1`.

Current constraints:

- BIOS/MBR only; no UEFI support yet.
- Synthetic NTFS metadata, not a full Windows-formatted NTFS volume yet.
- One root-directory file named `XPSLDR`.
- `XPSLDR` is stored as resident `$DATA` inside one MFT record.
- No NTFS data-run decoding yet, so non-resident files are not supported.
- `XPSLDR` is a real-mode shim proof, not a Linux kernel loader yet.
- GRUB/Syslinux handoff is a planned next milestone, not complete.

## Repository Layout

- `mbr.asm` - original/early MBR bootloader source.
- `stage1/xpsl_ntfs_stage1.asm` - current real-mode NTFS stage proof.
- `stage2/xpsldr.asm` - current `XPSLDR` shim payload.
- `tools/build-xpsldr.ps1` - builds the shim payload with portable NASM.
- `tools/build-stage1.ps1` - builds the NTFS boot stage.
- `tools/write-synthetic-ntfs.ps1` - creates the synthetic NTFS test layout.
- `tools/install-stage1.ps1` - writes the boot stage into the test disk.
- `tools/ntfs-find-file.ps1` - host-side parser used to validate NTFS lookup.
- `docs/xpsl-roadmap.md` - architecture and staged goals.
- `docs/ntfs-finder-notes.md` - details of the current NTFS proof.
- `artifacts/` - screenshots and generated test evidence.

## Portable Tooling

The project is set up to use local, portable tools where possible.

Portable NASM is expected at:

```text
tools/vendor/nasm-2.16.03/nasm.exe
```

MSYS2 base has also been unpacked under `tools/vendor/msys64` for future GRUB
or Linux tooling work, although package installation may depend on mirror/network
availability.

## Build And Test

Build `XPSLDR`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-xpsldr.ps1
```

Write the synthetic NTFS test volume and embed `XPSLDR`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\write-synthetic-ntfs.ps1 -DiskPath P:\VM\Debian\XPSL-test-flat.vmdk -FileName XPSLDR -PayloadPath .\build\xpsldr.bin
```

Build and install the NTFS boot stage:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-stage1.ps1
powershell -ExecutionPolicy Bypass -File tools\install-stage1.ps1 -DiskPath P:\VM\Debian\XPSL-test-flat.vmdk
```

Validate the file lookup from the host side:

```powershell
powershell -ExecutionPolicy Bypass -File tools\ntfs-find-file.ps1 P:\VM\Debian\XPSL-test-flat.vmdk XPSLDR -ExtractTo build\xpsldr.extracted.bin
```

Boot the VirtualBox VM normally:

```powershell
VBoxManage startvm Debian --type gui
```

When shutting the VM down during tests, use ACPI poweroff:

```powershell
VBoxManage controlvm Debian acpipowerbutton
```

## Test Target

The current disposable VirtualBox target is:

```text
P:\VM\Debian
```

The active test disk is:

```text
P:\VM\Debian\XPSL-test-flat.vmdk
```

This is a test image. Do not aim these scripts at a real disk unless the script
has been reviewed for that exact disk and the target has been backed up.

## Next Milestones

1. Split the current constrained 512-byte NTFS stage into a small PBR loader and
   a larger stage1.5 loader.
2. Add NTFS non-resident `$DATA` support by decoding data runs.
3. Load a larger `XPSLDR` payload from NTFS.
4. Teach `XPSLDR` to hand off to GRUB/Syslinux or load a Linux kernel/initrd
   directly.
5. Move from the synthetic NTFS volume to a real NTFS-formatted test partition.
6. Preserve and document a clean handoff ABI: BIOS drive, partition LBA, loader
   memory map, and boot options.

## Project Goal

The goal is not to replace Linux storage drivers. It is to explore a boot-time
bridge between the Windows XP/NT5 BIOS boot model and Linux:

- XP-compatible MBR/partition boot behavior.
- NTFS file discovery before an operating system is running.
- A Linux-oriented loader filename and handoff path.
- Future GRUB/Syslinux or Linux boot protocol support from NTFS.

If successful, the project becomes a research base for booting Linux from NTFS
on legacy BIOS systems and for studying XP-era boot compatibility from the Linux
side.

## License

This repository currently includes a `LICENSE` file for the project. Any
third-party reference material or imported research source should keep its own
license and attribution separate from the original project code.

