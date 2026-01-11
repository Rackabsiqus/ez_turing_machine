const std = @import("std");
const ez_turing_machine = @import("ez_turing_machine");
const TuringMachine = ez_turing_machine.TuringMachine;
const TransitionResult = ez_turing_machine.TransitionResult;

const Alphabet = enum { a, @"_" };
const States = enum { even, odd, halt_even, halt_odd };
const Functions = struct {
    fn transition(state: States, symbol: Alphabet) TransitionResult(Alphabet, States) {
        return switch (symbol) {
            .a => switch (state) {
                .even => .init(.a, .odd, .R),
                .odd => .init(.a, .even, .R),
                else => error.UnexpectedState,
            },

            ._ => switch (state) {
                .even => .init(._, .halt_even, .R),
                .odd => .init(._, .halt_odd, .R),
                else => error.UnexpectedState,
            },
        };
    }

    fn accept(state: States) ez_turing_machine.Accept {
        return switch (state) {
            .halt_even => .accept,
            .halt_odd => .reject,
            else => .none,
        };
    }
};

/// This machine checks that the input has an even amount of characters
const ExampleMachine = TuringMachine(
    Alphabet,
    Alphabet._,
    States,
    States.even,
    Functions.transition,
    Functions.accept,
    .{
        .name = "Is amount of symbols even?",
        .render_submachines = true,
        .draw_rejecting_states = true,
    },
);

test "evenAmountOfSymbols" {
    const allocator = std.testing.allocator;
    var machine = try ExampleMachine.init(allocator);
    defer machine.deinit();

    const symbols: [10]Alphabet = @splat(.a);
    try std.testing.expectEqual(true, try machine.execute(&.{}));
    for (1..10) |i| {
        try std.testing.expectEqual(i % 2 == 0, try machine.execute(symbols[0..i]));
    }
}

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(debug_allocator.deinit() != .leak);
    const allocator = debug_allocator.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdout_buffer);
    var stdout_writer = &stdout.interface;
    defer stdout_writer.flush() catch @panic("Couldn't flush");

    try ExampleMachine.render(allocator, stdout_writer);
}
