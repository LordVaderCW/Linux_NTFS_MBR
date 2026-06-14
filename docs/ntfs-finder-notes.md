# NTFS Finder Notes

Current test image:

- Disk: `P:\VM\Debian\XPSL-test-flat.vmdk`
- MBR partition type: `0x07`
- Active partition LBA: `2048`
- Test filename: `XPSLDR`

The current NTFS test volume is synthetic. It is written directly by
`tools\write-synthetic-ntfs.ps1` and is intentionally minimal:

- NTFS BPB at partition LBA `2048`.
- 512-byte sectors.
- 8 sectors per cluster.
- `$MFT` starts at LCN `4`.
- 1024-byte MFT records.
- Root directory MFT record is placed at record number `5`.
- Root `INDEX_ROOT` contains a single filename entry for `XPSLDR`.

The host-side parser is `tools\ntfs-find-file.ps1`.

Known working command:

```powershell
powershell -ExecutionPolicy Bypass -File tools\ntfs-find-file.ps1 P:\VM\Debian\XPSL-test-flat.vmdk XPSLDR
```

Expected result:

```text
NTFS volume found
  Partition LBA: 2048
  Bytes/sector: 512
  Sectors/cluster: 8
  Cluster size: 4096
  MFT LCN: 4
  MFT record size: 1024
File found
  Name: XPSLDR
```

## Porting Target

The boot-stage NTFS reader needs the same operations in real mode:

1. Read the active partition boot sector.
2. Validate the NTFS OEM string.
3. Read bytes/sector, sectors/cluster, `$MFT` LCN, and file-record size.
4. Read MFT record 5.
5. Apply NTFS multi-sector fixups.
6. Walk resident attributes to find `INDEX_ROOT`.
7. Walk root index entries and match the UTF-16 name `XPSLDR`.

This proves name discovery only. Loading file contents comes next: the stage
must read the target file's MFT record, find its `$DATA` attribute, decode data
runs if non-resident, and load the bytes to the XPSLDR handoff address.

## Current XPSLDR Payload Proof

The synthetic NTFS writer now embeds the built `build\xpsldr.bin` payload as
resident `$DATA` in MFT record `0x18`.

Build and install flow:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-xpsldr.ps1
powershell -ExecutionPolicy Bypass -File tools\write-synthetic-ntfs.ps1 -DiskPath P:\VM\Debian\XPSL-test-flat.vmdk -FileName XPSLDR -PayloadPath .\build\xpsldr.bin
powershell -ExecutionPolicy Bypass -File tools\build-stage1.ps1
powershell -ExecutionPolicy Bypass -File tools\install-stage1.ps1 -DiskPath P:\VM\Debian\XPSL-test-flat.vmdk
```

Verification:

```powershell
powershell -ExecutionPolicy Bypass -File tools\ntfs-find-file.ps1 P:\VM\Debian\XPSL-test-flat.vmdk XPSLDR -ExtractTo build\xpsldr.extracted.bin
```

The current VM-visible stage-1 proof is still constrained to the synthetic
layout, but it now performs dynamic lookup inside that layout. It reads the BPB,
derives the `$MFT` LBA, reads root MFT record `5`, scans the resident
`INDEX_ROOT` for the UTF-16 filename `XPSLDR`, reads the discovered file record,
copies resident `$DATA` to `0000:8000`, and jumps to it.

Expected VM text:

```text
XCDEFG
XPSLDR loaded from NTFS
```

The checkpoint letters mean:

- `X`: stage1 started.
- `C`: root MFT record was read and starts with `FILE`.
- `D`: `XPSLDR` was found in the root index.
- `E`: `XPSLDR` MFT record was read.
- `F`: `XPSLDR` record starts with `FILE`.
- `G`: resident `$DATA` was copied to `0000:8000`.

Successful screenshot:

- `artifacts\xpsl-dynamic-stage1-fixed.png`

The next generalization is non-resident `$DATA` support. That requires decoding
NTFS data runs and reading arbitrary cluster runs instead of requiring the
loader file to fit inside one resident MFT record.
