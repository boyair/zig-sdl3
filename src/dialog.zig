const C = @import("c.zig").C;
const errors = @import("errors.zig");
const std = @import("std");
const video = @import("video.zig");

/// Callback used by file dialog functions.
///
/// ## Function Parameters
/// * `user_data`: An app provided pointer for callback's use.
/// * `file_list`: The file(s) chosen by the user.
/// * `filter`: Index of the selected filter.
///
/// ## Remarks
/// The specific usage is described in each function.
///
/// If `file_list` is:
/// * `null`, an error occurred. Details can be obtained with `errors.get()`.
/// * A pointer to `null`, the user either didn't choose any file or canceled the dialog.
/// * A pointer to non-`null`, the user chose one or more files. The argument is a null-terminated array of pointers to UTF-8 encoded strings, each containing a path.
///
/// The `file_list` argument should not be freed; it will automatically be freed when the callback returns.
///
/// The filter argument is the index of the filter that was selected,
/// or `-1` if no filter was selected or if the platform or method doesn't support fetching the selected filter.
///
/// In Android, the `file_list` are `content://` URIs.
/// They should be opened using `io.fromFile()` with appropriate modes.
/// This applies both to open and save file dialog.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
///
/// ## Code Examples
/// TODO!!!
pub const FileCallback = *const fn (user_data: ?*anyopaque, file_list: [*c]const [*c]const u8, filter: c_int) callconv(.C) void;

/// Data for a file callback.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub fn FileCallbackData(comptime UserData: type) type {
    return struct {
        /// User data structure.
        user_data: ?*UserData,
        /// This is `null` if a seclection was not made, or at least one entry otherwise.
        file_list: ?[]const [*:0]const u8,
        /// Filter index if used and supported, `null` otherwise.
        filter: ?usize,
    };
}

/// An entry for filters for file dialogs.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
///
/// ## Code Examples
/// This structure is most often used as an array:
///
/// ```zig
/// const filters = [_]FileFilter {
///     { .name = "PNG images",  .pattern = "png" },
///     { .name = "JPEG images", .pattern = "jpg;jpeg" },
///     { .name = "All images",  .pattern = "png;jpg;jpeg" },
///     { .name = "All files",   .pattern = "*" },
/// };
/// ```
pub const FileFilter = extern struct {
    /// A user-readable label for the filter (for example, "Office document").
    name: [*:0]const u8,
    /// A semicolon-separated list of file extensions (for example, "doc;docx").
    /// File extensions may only contain alphanumeric characters, hyphens, underscores and periods.
    /// Alternatively, the whole string can be a single asterisk ("*"), which serves as an "All files" filter.
    pattern: [*:0]const u8,
};

/// Various types of file dialogs.
///
/// ## Remarks
/// This is used by `dialog.showWithProperties()` to decide what kind of dialog to present to the user.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const Type = enum(c_uint) {
    open_file = C.SDL_FILEDIALOG_OPENFILE,
    save_file = C.SDL_FILEDIALOG_SAVEFILE,
    open_folder = C.SDL_FILEDIALOG_OPENFOLDER,
};

/// Sanatize data from a dialog callback.
///
/// ## Function Parameters
/// * `UserData`: The type of user data expected.
/// * `user_data`: User data from the callback.
/// * `file_list`: File list from the callback.
/// * `filter`: Filter from the callback.
///
/// ## Return Value
/// Returns a sanatized struct where `user_data` has been casted to `UserData` if present,
/// `file_list` is `null` if a selection was not made or at least one entry otherwise, and `filter` is a filter index if used and supported (`null` otherwise).
///
/// ## Version
/// This function is provided by zig-sdl3.
pub fn sanatizeFileCallback(
    comptime UserData: type,
    user_data: ?*anyopaque,
    file_list: [*c]const [*c]const u8,
    filter: c_int,
) !FileCallbackData(UserData) {
    var list: ?[]const [*:0]const u8 = null;
    if (file_list != null) {
        if (file_list.* != null) {
            const items = std.mem.span(@as([*c]const usize, @ptrCast(file_list)));
            list = @as([*]const [*:0]const u8, @ptrCast(items.ptr))[0..items.len];
        }
    } else {
        return errors.wrapNull(FileCallbackData(UserData), null);
    }
    return .{
        .user_data = @alignCast(@ptrCast(user_data)),
        .file_list = list,
        .filter = if (filter < 0) null else @intCast(filter),
    };
}

/// Displays a dialog that lets the user select a file on their filesystem.
///
/// ## Function Parameters
/// * `callback`: A function pointer to be invoked when the user selects a file and accepts, or cancels the dialog, or an error occurs.
/// * `user_data`: An optional pointer to pass extra data to the callback when it will be invoked.
/// * `window`: The window that the dialog should be modal for, may be `null`. Not all platforms support this option.
/// * `filters`: Slice of filters, may be `null`. Not all platforms support this option, and platforms that do support it may allow the user to ignore the filters.
/// * `default_location`: The default folder or file to start the dialog at, may be `null`. Not all platforms support this option.
/// * `allow_many`: If the user will be allowed to select multiple entries. Not all platforms support this option.
///
/// ## Remarks
/// This is an asynchronous function; it will return immediately, and the result will be passed to the callback.
///
/// The callback will be invoked with a null-terminated list of files the user chose.
/// The list will be empty if the user canceled the dialog, and it will be `null` if an error occurred.
///
/// Note that the callback may be called from a different thread than the one the function was invoked on.
///
/// Depending on the platform, the user may be allowed to input paths that don't yet exist.
///
/// On Linux, dialogs may require XDG Portals, which requires DBus, which requires an event-handling loop.
/// Apps that do not use SDL to handle events should add a call to `events.pump()` in their main loop.
///
/// ## Thread Safety
/// This function should be called only from the main thread.
/// The callback may be invoked from the same thread or from a different one, depending on the OS's constraints.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn showOpenFile(
    callback: FileCallback,
    user_data: ?*anyopaque,
    window: ?video.Window,
    filters: ?[]const FileFilter,
    default_location: ?[:0]const u8,
    allow_many: bool,
) void {
    C.SDL_ShowOpenFileDialog(
        callback,
        user_data,
        if (window) |val| val.value else null,
        if (filters) |val| @ptrCast(val.ptr) else null,
        if (filters) |val| @intCast(val.len) else 0,
        if (default_location) |val| val.ptr else null,
        allow_many,
    );
}

/// Displays a dialog that lets the user select a folder on their filesystem.
///
/// ## Function Parameters
/// * `callback`: A function pointer to be invoked when the user selects a file and accepts, or cancels the dialog, or an error occurs.
/// * `user_data`: An optional pointer to pass extra data to the callback when it will be invoked.
/// * `window`: The window that the dialog should be modal for, may be `null`. Not all platforms support this option.
/// * `default_location`: The default folder or file to start the dialog at, may be `null`. Not all platforms support this option.
/// * `allow_many`: If non-zero, the user will be allowed to select multiple entries. Not all platforms support this option.
///
/// ## Remarks
/// This is an asynchronous function; it will return immediately, and the result will be passed to the callback.
///
/// The callback will be invoked with a null-terminated list of files the user chose.
/// The list will be empty if the user canceled the dialog, and it will be `null` if an error occurred.
///
/// Note that the callback may be called from a different thread than the one the function was invoked on.
///
/// Depending on the platform, the user may be allowed to input paths that don't yet exist.
///
/// On Linux, dialogs may require XDG Portals, which requires DBus, which requires an event-handling loop.
/// Apps that do not use SDL to handle events should add a call to `events.pump()` in their main loop.
///
/// ## Thread Safety
/// This function should be called only from the main thread.
/// The callback may be invoked from the same thread or from a different one, depending on the OS's constraints.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn showOpenFolder(
    callback: FileCallback,
    user_data: ?*anyopaque,
    window: ?video.Window,
    default_location: ?[:0]const u8,
    allow_many: bool,
) void {
    C.SDL_ShowOpenFolderDialog(
        callback,
        user_data,
        if (window) |val| val.value else null,
        if (default_location) |val| val.ptr else null,
        allow_many,
    );
}

/// Displays a dialog that lets the user choose a new or existing file on their filesystem.
///
/// ## Function Parameters
/// * `callback`: A function pointer to be invoked when the user selects a file and accepts, or cancels the dialog, or an error occurs.
/// * `user_data`: An optional pointer to pass extra data to the callback when it will be invoked.
/// * `window`: The window that the dialog should be modal for, may be `null`. Not all platforms support this option.
/// * `filters`: Slice of filters, may be `null`. Not all platforms support this option, and platforms that do support it may allow the user to ignore the filters.
/// * `default_location`: The default folder or file to start the dialog at, may be `null`. Not all platforms support this option.
///
/// ## Remarks
/// This is an asynchronous function; it will return immediately, and the result will be passed to the callback.
///
/// The callback will be invoked with a null-terminated list of files the user chose.
/// The list will be empty if the user canceled the dialog, and it will be `null` if an error occurred.
///
/// Note that the callback may be called from a different thread than the one the function was invoked on.
///
/// The chosen file may or may not already exist.
///
/// On Linux, dialogs may require XDG Portals, which requires DBus, which requires an event-handling loop.
/// Apps that do not use SDL to handle events should add a call to `events.pump()` in their main loop.
///
/// ## Thread Safety
/// This function should be called only from the main thread.
/// The callback may be invoked from the same thread or from a different one, depending on the OS's constraints.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn showSaveFile(
    callback: FileCallback,
    user_data: ?*anyopaque,
    window: ?video.Window,
    filters: ?[]const FileFilter,
    default_location: ?[:0]const u8,
) void {
    C.SDL_ShowSaveFileDialog(
        callback,
        user_data,
        if (window) |val| val.value else null,
        if (filters) |val| @ptrCast(val.ptr) else null,
        if (filters) |val| @intCast(val.len) else 0,
        if (default_location) |val| val.ptr else null,
    );
}

// File dialog related tests.
test "File Dialog" {
    comptime try std.testing.expectEqual(@sizeOf(C.SDL_DialogFileFilter), @sizeOf(FileFilter));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_DialogFileFilter, "name"), @offsetOf(FileFilter, "name"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_DialogFileFilter, "name")), @sizeOf(@FieldType(FileFilter, "name")));
    comptime try std.testing.expectEqual(@offsetOf(C.SDL_DialogFileFilter, "pattern"), @offsetOf(FileFilter, "pattern"));
    comptime try std.testing.expectEqual(@sizeOf(@FieldType(C.SDL_DialogFileFilter, "pattern")), @sizeOf(@FieldType(FileFilter, "pattern")));
}
