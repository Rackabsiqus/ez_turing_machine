const std = @import("std");
const Allocator = std.mem.Allocator;

const Tape = @import("Tape.zig").Tape;

pub const Error = error{UnexpectedState};
pub const Direction = @import("Tape.zig").Direction;
pub const Accept = enum { none, accept, reject };

pub fn TransitionResult(Alphabet: type, States: type) type {
    return Error!struct {
        write_symbol: Alphabet,
        new_state: States,
        direction: Direction,

        pub fn init(write_symbol: Alphabet, new_state: States, direction: Direction) @This() {
            return .{
                .write_symbol = write_symbol,
                .new_state = new_state,
                .direction = direction,
            };
        }
    };
}

pub const Options = struct {
    name: ?[]const u8 = null,
    render_submachines: bool = true,
    draw_rejecting_states: bool = true,
};
pub fn TuringMachine(
    Alphabet: type,
    blank_symbol: Alphabet,
    States: type,
    initial_state: States,
    transition: fn (state: States, symbol: Alphabet) TransitionResult(Alphabet, States),
    accept: fn (state: States) Accept,
    options: Options,
) type {
    std.debug.assert(@typeInfo(Alphabet) == .@"enum");
    std.debug.assert(@typeInfo(States) == .@"enum");
    return struct {
        const This = @This();

        const block_size = 1;
        const Block = [block_size]Alphabet;

        allocator: Allocator,
        state: States,
        tape: *Tape(Alphabet, blank_symbol),
        tape_owner: bool = false,

        pub fn init(allocator: Allocator) !This {
            return .{
                .allocator = allocator,
                .state = initial_state,
                .tape = try .init(allocator),
                .tape_owner = true,
            };
        }

        pub fn deinit(this: This) void {
            if (this.tape_owner) this.tape.deinit(this.allocator);
        }

        pub fn execute(this: *This, input: []const Alphabet) (Allocator.Error || Error)!bool {
            _ = this;
            _ = input;
            @compileError("Bruh c'est le devoir à Stefanos, je mettrais cette fonction après la date de remise");
        }

        fn writeSymbol(this: *This, symbol: Alphabet) void {
            this.blocks.items[this.head_position / block_size][this.head_position % block_size] = symbol;
        }

        pub fn render(allocator: Allocator, writer: *std.Io.Writer) !void {
            var subgraph_count: u64 = 0;

            try writer.writeAll("digraph {\n");
            try writer.print("{s} [style=diagonals]\n", .{@tagName(initial_state)});
            try renderSubmachine(allocator, writer, &subgraph_count);
            try writer.writeAll("}\n");
        }

        pub fn renderSubmachine(allocator: Allocator, writer: *std.Io.Writer, subgraph_count: *u64) !void {
            try writer.print("subgraph cluster_{d} {{\nlabel=\"{s}\";\n", .{ subgraph_count.*, options.name orelse "Anonymous" });
            subgraph_count.* += 1;

            for (std.enums.values(States)) |state| {
                if (switch (accept(state)) {
                    .accept => "green",
                    .reject => "red",
                    .none => null,
                }) |color| {
                    try writer.print("{s} [style=bold,color={s}]\n", .{ @tagName(state), color });
                }

                var transitions: std.AutoHashMapUnmanaged(States, std.ArrayList(struct { Alphabet, Alphabet, Direction })) = .empty;
                defer {
                    var it = transitions.valueIterator();
                    while (it.next()) |array_list| {
                        array_list.deinit(allocator);
                    }
                    transitions.deinit(allocator);
                }

                for (std.enums.values(Alphabet)) |symbol| {
                    const transition_result = transition(state, symbol) catch continue;
                    if (transitions.contains(transition_result.new_state) == false) {
                        try transitions.put(allocator, transition_result.new_state, .empty);
                    }

                    try transitions
                        .getPtr(transition_result.new_state).?
                        .append(allocator, .{ symbol, transition_result.write_symbol, transition_result.direction });
                }

                var it = transitions.iterator();
                while (it.next()) |entry| {
                    const new_state = entry.key_ptr.*;
                    if (options.draw_rejecting_states == false and accept(new_state) == .reject) continue;
                    try writer.print("{s} -> {s}[label=\"", .{ @tagName(state), @tagName(new_state) });

                    var first_transition: bool = true;
                    for (entry.value_ptr.items) |item| {
                        if (first_transition) {
                            first_transition = false;
                        } else {
                            try writer.writeByte('\n');
                        }

                        const on_symbol, const new_symbol, const direction = item;
                        try writer.print("{s}→{s},{s}", .{
                            @tagName(on_symbol),
                            @tagName(new_symbol),
                            @tagName(direction),
                        });
                    }
                    try writer.writeAll("\"]\n");
                }
            }
            try writer.writeAll("}\n");
        }
    };
}

test "evenAmountOfSymbols" {
    const Alphabet = enum { a, @"_" };
    const States = enum { even, odd, halt_even, halt_odd };

    const Functions = struct {
        fn transition(state: States, symbol: Alphabet) TransitionResult(Alphabet, States) {
            return switch (symbol) {
                .a => switch (state) {
                    .even => .init(._, .odd, .R),
                    .odd => .init(._, .even, .R),
                    else => error.UnexpectedState,
                },

                ._ => switch (state) {
                    .even => .init(._, .halt_even, .R),
                    .odd => .init(._, .halt_odd, .R),
                    else => error.UnexpectedState,
                },
            };
        }

        fn accept(state: States) Accept {
            return switch (state) {
                .halt_even => .accept,
                .halt_odd => .reject,
                else => .none,
            };
        }
    };

    const allocator = std.testing.allocator;
    const Machine = TuringMachine(
        Alphabet,
        Alphabet._,
        States,
        .even,
        Functions.transition,
        Functions.accept,
        .{},
    );
    var machine = try Machine.init(allocator);
    defer machine.deinit();

    const symbols: [10]Alphabet = @splat(.a);
    try std.testing.expectEqual(true, try machine.execute(&.{}));
    for (1..10) |i| {
        try std.testing.expectEqual(i % 2 == 0, try machine.execute(symbols[0..i]));
    }
}
