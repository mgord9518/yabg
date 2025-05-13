const std = @import("std");

const psf1_magic = [2]u8{
    0x36,
    0x04,
};

const psf2_magic = [4]u8{
    0x72,
    0xb5,
    0x4a,
    0x86,
};

pub const ParseError = error{
    BadMagic,
};

pub const Psf2Error = error{};

pub const Psf1Header = extern struct {
    magic: [2]u8,
    flags: Flags,
    bytes_per_glyph: u8,

    pub const Flags = packed struct(u8) {
        has_512_glyphs: bool,
        has_unicode_table: bool,
        seq: bool,
        _3: u5,
    };
};

pub const Psf2Header = extern struct {
    magic: [4]u8,
    version: u32,
    header_size: u32,
    flags: Flags,
    glyph_num: u32,
    bytes_per_glyph: u32,
    h: u32,
    w: u32,

    pub const Flags = packed struct(u32) {
        has_unicode_table: bool,
        _1: u31,
    };
};

pub const Font = struct {
    glyphs: std.AutoHashMap(u21, []const u8),
    w: u32,
    h: u32,

    pub const Glyph = []const u8;

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Font {
        if (std.mem.eql(u8, data[0..4], &psf2_magic)) {
            return try parsePsf2(allocator, data);
        }

        if (std.mem.eql(u8, data[0..2], &psf1_magic)) {
            return try parsePsf1(allocator, data);
        }

        return ParseError.BadMagic;
    }

    pub fn parsePsf2(allocator: std.mem.Allocator, data: []const u8) !Font {
        const header: Psf2Header = @bitCast(data[0..32].*);

        var glyphs = std.AutoHashMap(u21, []const u8).init(allocator);

        var offset: usize = header.header_size;

        const table_offset = header.header_size + header.glyph_num * header.bytes_per_glyph;

        var it = try Psf2TableIterator.init(data[table_offset..]);

        var idx: usize = 0;
        while (try it.next()) |entry| {
            if (idx >= header.glyph_num) break;

            try glyphs.put(
                entry.codepoint,
                data[offset..][0..header.bytes_per_glyph],
            );

            if (entry.idx != idx) {
                offset += header.bytes_per_glyph;
            }

            idx = entry.idx;
        }

        return .{
            .glyphs = glyphs,
            .w = header.w,
            .h = header.h,
        };
    }

    pub fn parsePsf1(allocator: std.mem.Allocator, data: []const u8) !Font {
        const header: Psf1Header = @bitCast(data[0..4].*);

        var glyphs = std.AutoHashMap(u21, []const u8).init(allocator);

        var offset: usize = @sizeOf(Psf1Header);

        const glyph_num: usize = if (header.flags.has_512_glyphs) 512 else 256;

        var idx: usize = 0;
        while (idx < glyph_num) {
            try glyphs.put(
                @truncate(idx),
                data[offset..][0..header.bytes_per_glyph],
            );

            idx += 1;
            offset += header.bytes_per_glyph;
        }

        return .{
            .glyphs = glyphs,
            .w = 8,
            .h = header.bytes_per_glyph,
        };
    }

    pub fn deinit(font: *Font) void {
        font.glyphs.deinit();
    }
};

pub const Psf2TableIterator = struct {
    buf: []const u8,
    utf8_it: std.unicode.Utf8Iterator,
    quit_on_next: bool = false,
    idx: usize,

    const sequence = 0xfe;
    const end_glyph = 0xff;

    pub fn init(table: []const u8) !Psf2TableIterator {
        var it = Psf2TableIterator{
            .buf = table,
            .utf8_it = undefined,
            .idx = 0,
        };

        it.utf8_it = std.unicode.Utf8Iterator{
            .bytes = it.buf,
            .i = 0,
        };

        return it;
    }

    fn reset(it: *Psf2TableIterator) !bool {
        const remaining_len = it.utf8_it.bytes.len - it.utf8_it.i;

        std.mem.copyForwards(
            u8,
            it.buf[0..remaining_len],
            it.buf[it.utf8_it.i..][0..remaining_len],
        );

        // Now read new data after what we just moved back
        it.utf8_it.bytes.len = try it.reader.readAll(
            it.buf[remaining_len..],
        ) + remaining_len;

        it.buf.len = it.utf8_it.bytes.len;

        if (it.utf8_it.bytes.len == 0) return true;

        // Append a terminator byte if the reader is finished
        // and didn't fill the entire buffer
        if (it.utf8_it.bytes.len < it.buf.len) {
            it.buf[it.utf8_it.bytes.len] = '\xff';
            return true;
        }

        it.utf8_it.i = 0;

        return false;
    }

    pub const TableIteratorRet = struct {
        idx: usize,
        codepoint: u21,
    };

    pub fn next(it: *Psf2TableIterator) !?TableIteratorRet {
        if (it.utf8_it.i >= it.buf.len) return null;

        while (it.buf[it.utf8_it.i] == Psf2TableIterator.sequence) {
            it.utf8_it.i += 1;
        }

        while (it.buf[it.utf8_it.i] == Psf2TableIterator.end_glyph) {
            it.utf8_it.i += 1;

            it.idx += 1;
            return .{
                .codepoint = 0x00,
                .idx = it.idx,
            };
        }

        while (it.utf8_it.nextCodepointSlice()) |utf8_codept| {
            const codepoint = try std.unicode.utf8Decode(utf8_codept);

            // Skip multi-codepoint sequences
            // TODO: implement
            if (it.buf[it.utf8_it.i] == Psf2TableIterator.sequence) {
                while (it.buf[it.utf8_it.i] != '\xff') {
                    it.utf8_it.i += 1;
                }
            }

            if (it.buf[it.utf8_it.i] == Psf2TableIterator.end_glyph) {
                it.utf8_it.i += 1;
                it.idx += 1;
            }

            const ret = TableIteratorRet{
                .idx = it.idx,
                .codepoint = codepoint,
            };

            return ret;
        }

        unreachable;
    }
};
