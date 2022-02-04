const zgt = @import("zgt");
const std = @import("std");

const defaultcmd = "slock";
const defaulttime = "3m";
const shell = "/bin/sh";
const State = struct {
    cmd: zgt.StringDataWrapper = zgt.StringDataWrapper.of(defaultcmd),
    time: zgt.StringDataWrapper = zgt.StringDataWrapper.of(defaulttime),
};
var state: State = .{};

var window: zgt.Window = undefined;

var allocator = std.heap.GeneralPurposeAllocator(.{}){};
var gpa = allocator.allocator();

pub fn main() !void {
    try zgt.backend.init();
    const command = getCached("cmd") orelse defaultcmd;
    const time = getCached("time") orelse defaulttime;

    window = try zgt.Window.init();
    try window.set(zgt.Column(.{}, .{
        zgt.Label(.{ .text = "Ulysses" }),
        zgt.Row(.{}, .{
            zgt.Label(.{ .text = "Command To Run" }),
            // TODO cache this
            zgt.TextField(.{ .text = command }).setName("command"),
        }),
        zgt.Row(.{}, .{
            zgt.Label(.{ .text = "Minutes In Future" }),
            zgt.TextField(.{ .text = time }).setName("minutes"),
            zgt.Button(.{ .label = "Run", .onclick = runcmd }),
        }),
        zgt.Button(.{ .label = "Exit", .onclick = exit }),
    }));

    window.show();
    window.resize(400, 200);
    zgt.runEventLoop();
}

fn exit(b: *zgt.Button_Impl) !void {
    _ = b;
    std.os.exit(0);
}
fn runcmd(b: *zgt.Button_Impl) !void {
    const root = b.getRoot().?;

    const minutes = root.get("minutes").?.as(zgt.TextField_Impl).getText();
    const command = root.get("command").?.as(zgt.TextField_Impl).getText();
    try setCached("time", minutes);
    try setCached("cmd", command);
    const command_with_sleep = try std.mem.concat(gpa, u8, &.{ "sleep ", minutes, "&&", command });

    const argv: []const []const u8 = &.{ "/bin/sh", "-c", command_with_sleep };
    _ = argv;

    const pid = try std.os.fork();
    if (pid > 0) {
        std.os.exit(0);
    }
    _ = std.os.linux.syscall0(.setsid);
    std.log.info("running the command: `{s}`", .{command_with_sleep});
    std.process.execve(gpa, argv, null) catch std.os.exit(1);
}

fn getCached(name: []const u8) ?[]const u8 {
    const app_data_dir_s = std.fs.getAppDataDir(gpa, "ulysses") catch return null;
    const app_data_dir = std.fs.openDirAbsolute(app_data_dir_s, .{}) catch return null;
    const f = app_data_dir.openFile(name, .{}) catch return null;
    const bytes = f.readToEndAlloc(gpa, 4096) catch null;
    return bytes;
}
fn setCached(name: []const u8, text: []const u8) !void {
    const app_data_dir_s = try std.fs.getAppDataDir(gpa, "ulysses");
    std.fs.makeDirAbsolute(app_data_dir_s) catch {};
    const app_data_dir = try std.fs.openDirAbsolute(app_data_dir_s, .{});
    const f = try app_data_dir.createFile(name, .{});
    return f.writeAll(text);
}
