# NT5 Boot Reference Map

This project keeps its implementation clean-room. The adjacent NT5 source tree can
be used to understand boot flow and file layout, but proprietary source or binary
blobs should not be copied into this repository.

Useful local reference paths:

- `P:\OAI\Agent\nt5src\Source\XPSP1\NT\base\boot\bootcode\mbr\i386\x86mboot.asm`
  - BIOS MBR chainloader flow: relocate, validate the partition table, find the
    active partition, read the partition boot record, and jump to it.
- `P:\OAI\Agent\nt5src\Source\XPSP1\NT\base\boot\bootcode\mbr\i386\bootmbr.h`
  - Generated 512-byte MBR image.
- `P:\OAI\Agent\nt5src\Source\XPSP1\NT\base\boot\bootcode\ntfs\i386\ntfsboot.asm`
  - NTFS partition boot flow. It reads additional boot sectors, understands
    enough NTFS metadata to locate a loader file, and transfers control to it.
- `P:\OAI\Agent\nt5src\Source\XPSP1\NT\base\boot\bootcode\ntfs\i386\ntfs.inc`
  - NTFS on-disk structure definitions used by the NTFS boot code.
- `P:\OAI\Agent\nt5src\Source\XPSP1\NT\base\boot\bootcode\ntfs\i386\bootntfs.h`
  - Generated 8192-byte NTFS boot image.

## Local Milestones

1. Build and test the MBR chainloader in a VM disk image.
2. Add a small test harness that validates the output is exactly 512 bytes and
   has the boot signature at offsets `0x1FE..0x1FF`.
3. Design a clean NTFS stage-1/1.5 loader that can find a Linux-oriented loader
   file instead of `NTLDR`.
4. Test with a Debian VM on an MBR-partitioned disk containing an NTFS boot
   partition.
