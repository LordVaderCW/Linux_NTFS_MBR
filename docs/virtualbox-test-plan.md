# VirtualBox Test Plan

Target VM:

- VM config: `P:\VM\Debian\Debian.vbox`
- Disk descriptor: `P:\VM\Debian\Debian.vmdk`
- Flat disk image: `P:\VM\Debian\Debian-flat.vmdk`
- Size: 16 GiB

The VM is present on disk but is not currently registered with VirtualBox.

## Register the VM

```powershell
VBoxManage registervm P:\VM\Debian\Debian.vbox
VBoxManage showvminfo Debian
```

## Build and Validate the MBR

```powershell
nasm -f bin -o mbr.bin mbr.asm
powershell -ExecutionPolicy Bypass -File tools\verify-mbr.ps1 .\mbr.bin
```

Expected validation:

- File size is exactly 512 bytes.
- Bytes at offsets `0x1FE..0x1FF` are `55 AA`.

## Safe Disk Test Loop

Always keep a copy of the blank disk before writing boot code:

```powershell
Copy-Item P:\VM\Debian\Debian-flat.vmdk P:\VM\Debian\Debian-flat.blank.vmdk
```

To restore the blank disk:

```powershell
Copy-Item P:\VM\Debian\Debian-flat.blank.vmdk P:\VM\Debian\Debian-flat.vmdk
```

After `mbr.bin` validates, write only the first 446 bytes if preserving an
existing partition table, or all 512 bytes only on a disposable blank disk.

For early blank-disk boot tests, writing all 512 bytes is acceptable because
there is no OS or partition table to preserve.

## Boot

```powershell
VBoxManage startvm Debian
```

In the desktop/GUI workflow, prefer the VirtualBox Manager window or the
`VirtualBoxVM` process as the liveness check. In this environment,
`VBoxManage showvminfo Debian --machinereadable` can report `VMState="poweroff"`
while the GUI VM is visibly still running.

For repeatable automated tests later, prefer headless mode plus screenshots or
serial output:

```powershell
VBoxManage startvm Debian --type headless
VBoxManage controlvm Debian poweroff
```
