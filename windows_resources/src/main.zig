const std = @import("std");
const Io = std.Io;

const w = std.os.windows;

// define b/c zig doesn't have these -------- START
const HRSRC = w.HANDLE;
const HGLOBAL = w.HANDLE;
const RT_RCDATA: w.LPCWSTR = @ptrFromInt(@as(usize, 10)); // https://learn.microsoft.com/en-us/windows/win32/menurc/resource-types
const HEAP_ZERO_MEMORY = 0x00000008;

// https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-findresourcew
pub extern "kernel32" fn FindResourceW(
    hModule: w.HMODULE,
    lpName: w.LPCWSTR,
    lpType: w.LPCWSTR,
) callconv(.winapi) ?HRSRC;

// https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadresource
pub extern "kernel32" fn LoadResource(
    hModule: w.HMODULE,
    hResInfo: HRSRC,
) callconv(.winapi) ?HGLOBAL;

// https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-lockresource
pub extern "kernel32" fn LockResource(
    hResData: HGLOBAL,
) callconv(.winapi) ?w.LPVOID;

// https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-sizeofresource
pub extern "kernel32" fn SizeofResource(
    hModule: w.HMODULE,
    hResInfo: HRSRC,
) callconv(.winapi) w.DWORD;

pub extern "kernel32" fn HeapAlloc(
    hHeap: ?*w.HEAP,
    dwFlags: w.DWORD,
    dwBytes: usize,
) callconv(.winapi) ?w.LPVOID;

pub extern "kernel32" fn HeapFree(
    hHeap: ?*w.HEAP,
    dwFlags: w.DWORD,
    lpMem: w.LPVOID,
) callconv(.winapi) w.BOOL;

extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?w.PCWSTR,
) callconv(.winapi) ?w.HMODULE;

// define b/c zig doesn't have these -------- END

pub fn utf8ToUtf16Le(out_buf: []u16, utf8_str: []const u8) !w.PCWSTR {
    if (out_buf.len <= utf8_str.len) {
        return error.BufferTooSmall;
    }

    const len = try std.unicode.utf8ToUtf16Le(out_buf, utf8_str);

    out_buf[len] = 0;

    return @ptrCast(&out_buf[0]); // I'm totally sure this is just fine :-P
}

pub fn main() !void {
    const hModule: w.HMODULE = GetModuleHandleW(null) orelse {
        return error.FailedToGetModuleHandle;
    };

    var buf: [128]u16 = undefined;
    const lpName: w.PCWSTR = try utf8ToUtf16Le(&buf, "FOO");

    const hRsrc = FindResourceW(
        hModule,
        lpName,
        RT_RCDATA,
    ) orelse {
        std.debug.print("Failed FindResourceW\n", .{});
        std.process.exit(1);
    };

    const hGlobal = LoadResource(
        hModule,
        hRsrc,
    ) orelse {
        std.debug.print("Failed LoadResource\n", .{});
        std.process.exit(1);
    };

    const fooPtr = LockResource(hGlobal) orelse {
        std.debug.print("Failed LockResource\n", .{});
        std.process.exit(1);
    };

    const fooSize = SizeofResource(
        hModule,
        hRsrc,
    );

    if (fooSize == 0) {
        std.debug.print("Failed SizeofResource\n", .{});
        std.process.exit(1);
    }

    const hHeap = w.GetProcessHeap() orelse {
        std.debug.print("Failed to GetProcessHeap\n", .{});
        std.process.exit(1);
    };

    const fooHeap = HeapAlloc(
        hHeap,
        HEAP_ZERO_MEMORY,
        fooSize,
    ) orelse {
        std.debug.print("Failed to heapalloc\n", .{});
        std.process.exit(1);
    };

    // weird zig shit...deal with it...
    const dest_slice = @as([*]u8, @ptrCast(fooHeap))[0..fooSize];
    const src_slice = @as([*]const u8, @ptrCast(fooPtr))[0..fooSize];

    std.mem.copyBackwards(u8, dest_slice, src_slice);

    std.mem.reverse(u8, dest_slice);

    std.debug.print("{s}\n", .{dest_slice});

    if (HeapFree(
        hHeap,
        0,
        fooHeap,
    ) == w.BOOL.FALSE) {
        std.debug.print(
            "Failed to heapfree\n",
            .{},
        );

        std.process.exit(1);
    }
}
