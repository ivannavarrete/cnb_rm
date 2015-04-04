
CNB project

Documentation for the Real Mode Crash 'N Burn OS 1


OS components
These are the main components of the OS:
  File Manager (FM)
  File System (FS)
  Memory Manager (MM)
  Memory System (MS)
  Command Interpreter (CI)
  Boot Sector (BS)
  InitOS code


Boot Sector
  The first thing the BS does is, using the BIOS ints, to load the CNB.BIN
file from the FS, which is always at a default location on the boot media. It
places this file at memory location 0x0700, right after the interrupt vector
table, the ROM BIOS data area, and the reserved 512 bytes for the FAT mirror.
It then reads the identification field of the file to determine whether this
really is the correct file. If the check fails the BS displays an error message
and goes into an endless loop. To recover from this state it is necessary to
perform a reboot. If the check passes, the BS reads the InitOS offset and
calculates the address in memory of the InitOS code, and finaly jumps to this
location.


InitOS code
  The InitOS code first reads the MM, FM and CI recover offsets and calculates
their memory offsets. Then it sets the MM, FM and CI recover Ints. Then the FAT
mirror is loaded from the 2:nd sector on disk to 0x500 in memory, right after
the ROM BIOS data area. After that the Memory Manager is asked to forcibly clear
the user memory space, and the last thing it does is to jump to the Command
Interpreter code.


Command Interpreter
  The command interpteret has a default routine running when there is nothing
else for the OS to do. This routine uses BIOS interrupts to read input from the
keyboard. This input is reflected to the screen, again via BIOS ints. Whenever
the user specifies an internal OS command, the default routine passes control
to the code that runs this command. Whenever the user specifies an input that
is not an internal OS command, the CI asks the File Manager for a list of file-
names to see whether there is a file that matches the users input. If there
isn't, the CI displays an error message and returns to the default routine. If
there is a matching filename, the CI asks the Memory Manager to map the file
into memory and then examines to see whether it is an executable file. If it is,
it loads the entry point offset and calculates the memory offset and then jumps
to the program code. If it isn't an executable file, the CI displays an error
message, asks the Memory Manager to deallocate the memory allocated for the file
and then returns to the default routine.
  The following internal OS commands exists:
    HELP      displays all the internal OS commands
    LIST      lists the files in the file system
    MEM       displays information about the memory system
    TIME      displays the date and time
    BOOT      do a soft reboot of the computer
    CLS       clear screen
    FORMAT      format the file system
    DEL <filename>  delete a file from the file system

  There is a function in the CI that can be accessed through the CI recover
interrupt. It has two functions. One of them can be called whenever the system
is in an instable state. This routine basically forcibly cleares the user memory
space and returns to the CI default routine. The other function is the way for
user programs to terminate execution. It deallocates the programs memory block
and jumps to the default routine.


File System
  The file system has a few default parts. The BS is at the first sector of
the harddrive (enforced by the hardware on Intel chips). After that comes the
File Allocation Table, which is one sector in size. It has the following format:

    |-------------------|
    | allocation table  | 20b
    |-------------------|
    | cnb.bin entry     | 16b
    |-------------------|
    | file entry 2      | 16b
    |-------------------|
    /                   /
    /                   /
    |-------------------|
    | file entry 20     |
    |-------------------|
    | reserved          |
    |-------------------|

Then comes the CNB.BIN file, which is 10k in size (as all the files in this
version of cnb), thus occupying 20 512 byte sectors. After this file there is
room for another 19 files a 10k, which dictates the size of the file system to
20 * 10k = 200k. All the files occupy 20 continuous sectors on the harddrive.
There cannot be any fragmentation. The space after the CNB.BIN file up to the
end of the file system is managed by the file manager. This space is simply a
big chunk of sectors reserved for use as files. There is no support for subdirs.
  The CNB.BIN file has the following format:

    |-------------------|
    | Magic value       | 4b
    |-------------------|
    | InitOS offset     | 2b
    |-------------------|
    | FM offset         | 2b
    |-------------------|
    | MM offset         | 2b
    |-------------------|
    | CI recover offset | 2b
    |-------------------|
    | reserved          | xb
    |-------------------|
    | InitOS code       | xb
    |-------------------|
    | FM code           | xb
    |-------------------|
    | MM code           | xb
    |-------------------|
    | CI code           | xb
    |-------------------|
    | reserved          | xb
    |-------------------|

  Executable files have a 4-byte magic value as the first four bytes of the
file, that identifies them as an executable file. The magic value is 'EXE '.
  Executable files have the following format:

    |-------------------|
    | Magic value       | 4b
    |-------------------|
    | Entry point off.  | 2b
    |-------------------|
    | reserved          | xb
    |-------------------|
    | Code              | xb
    |-------------------|
    | reserved          | xb
    |-------------------|


File Manager
  The File Manager is accessed through an special interrupt, the FM Int. The
FM Int takes parameters in the CPU registers to determine which function is
called and to determine the function parameters. The File Manager has the
following set of routines:
  GetFile
    Input: filename ptr
    Output: 2 bytes that specify the starting sector on the hd of the start
          the file.
    Result: none

  ListFiles
    Input: none
    Output: a list of files that currently exists on the file system.
    Result: none

  Format
    Input: none
    Output: none
    Result: The user files (the max 19 files) are forcibly erased from the
          file system.


Memory System
  The memory system is divided into The Interrupt Vector Table, the system
memory block and the user memory block. The format of the memory system is:

    |---------------|
    | IVT           | 0x0000-0x03FF
    |---------------|
    | ROM data      | 0x0400-0x04FF
    |---------------|
    | FAT mirror    | 0x0500-0x06FF
    |---------------|
    | System memory | 0x0700-0x2EFF
    |---------------|
    | User memory   | 0x2F00-0x34F00
    |---------------|
    /               /
    /               /
    |---------------|
    | Video memory  | 0xB8000-0xB8FF0
    |---------------|
    /               /
    /               /
    |---------------|
    | BIOS          |
    |---------------|
    /               /
    /               /

The System memory is 20k in size and holds the CNB.BIN file. It has no memory
block prefix. The user memory is divided into 20 blocks each of size 512 * 20 =
10k. Each memory block has a 16 byte memory block prefix which specifyes the
block status, and has two pointers, one to the next free memory block and one
to the previous free memory block. The total size of all block prefixes is 512
bytes. The total size of the memory blocks is 200k.


Memory Manager
  The Memory Manager is accessed through a special interrupt, the MM Int. The
MM Int takes parameters in the CPU registers to determine which function is
called and to the determine the function parameters. The Memory Manager has the
following set of routines:
  * Input: none
    Output: pointer to an allocated memory block
    Result: a memory block is allocated from the user memory space

  * Input: pointer to an allocated memory block
    Output: none
    Result: a memory block in the user memory space is freed

  * Input: pointer to a sector on the harddrive specifying the start of a file
    Output: pointer to a block of memory with the memory mapped file.
    Result: a memory block is allocated from the user memory space

  * Input: none
    Output: none
    Result: The user memory space, beginning at 0x2C00 and ranging to 0x34C00
            is forcibly cleared from user programs.
