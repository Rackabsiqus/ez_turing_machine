const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Direction = enum {
    L,
    S,
    R,
};

pub fn Tape(Alphabet: type, blank_symbol: Alphabet) type {
    const block_size = 1024;
    const Block = [block_size]Alphabet;

    return struct {
        const This = @This();
        cells_blocks: std.ArrayList(*Block) = .empty, // TODO: Change this to a double linked listed maybe?
        head_position: u64 = 0,

        pub fn init(allocator: Allocator) !*This {
            const tape = try allocator.create(This);
            tape.* = .{};
            return tape;
        }

        pub fn deinit(this: *This, allocator: Allocator) void {
            for (this.cells_blocks.items) |block| allocator.destroy(block);
            this.cells_blocks.deinit(allocator);
            allocator.destroy(this);
        }

        pub fn moveHead(this: *This, direction: Direction) void {
            switch (direction) {
                .L => this.head_position -|= 0,
                .R => this.head_position += 1,
                .S => {},
            }
        }

        fn reset(this: *This) void {
            this.head_position = 0;
            for (this.cells_blocks.items) |block| @memset(block, blank_symbol);
        }

        pub fn copyInput(this: *This, allocator: Allocator, input: []const Alphabet) Allocator.Error!void {
            this.reset();

            const number_of_blocks = (input.len + block_size - 1) / block_size;
            while (this.cells_blocks.items.len <= number_of_blocks) {
                try this.addNewCellBlock(allocator);
            }

            for (0..number_of_blocks) |block_index| {
                const pos = block_index * block_size;
                const len = @min(block_size, input.len - pos);
                @memcpy(this.cells_blocks.items[block_index][0..len], input[pos .. pos + len]);
            }
        }

        inline fn getCurrentSymbol(this: This) *Alphabet {
            const index = this.head_position / block_size;
            const offset = this.head_position % block_size;

            return &this.cells_blocks.items[index][offset];
        }

        pub fn readSymbol(this: *This, allocator: Allocator) Allocator.Error!Alphabet {
            if (this.head_position >= this.cells_blocks.items.len * block_size) {
                @branchHint(.unlikely);
                try this.addNewCellBlock(allocator);
            }

            return this.getCurrentSymbol().*;
        }

        pub fn writeSymbol(this: This, symbol: Alphabet) void {
            this.getCurrentSymbol().* = symbol;
        }

        fn addNewCellBlock(this: *This, allocator: Allocator) Allocator.Error!void {
            const new_block = try allocator.create(Block);
            new_block.* = @splat(blank_symbol);
            try this.cells_blocks.append(allocator, new_block);
        }
    };
}
