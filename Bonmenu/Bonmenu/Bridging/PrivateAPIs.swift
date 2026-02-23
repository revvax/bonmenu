import CoreGraphics

// MARK: - CoreGraphics Server (CGS) Private API Declarations
//
// These are undocumented functions from the CoreGraphics private framework.
// They provide access to the window server for menu bar item management.
// Requires unsandboxed execution.

typealias CGSConnectionID = Int32

// MARK: - Connection

/// Returns the main connection ID to the window server.
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

// MARK: - Window Listing

/// Gets the list of menu bar windows for a specific process.
/// - Parameters:
///   - cid: The connection ID (from CGSMainConnectionID)
///   - targetCID: Connection ID of the target process (0 for all processes)
///   - count: Maximum number of window IDs to return
///   - list: Buffer to receive window IDs
///   - outCount: Actual number of window IDs returned
@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: UnsafeMutablePointer<Int32>
) -> CGError

/// Gets the list of on-screen windows for a specific connection.
@_silgen_name("CGSGetOnScreenWindowList")
func CGSGetOnScreenWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: UnsafeMutablePointer<Int32>
) -> CGError

/// Gets the screen-space rectangle for a window.
@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outRect: UnsafeMutablePointer<CGRect>
) -> CGError

// MARK: - Space Management

/// Returns the ID of the currently active space.
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> UInt64

/// Copies the spaces that contain the specified windows.
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(
    _ cid: CGSConnectionID,
    _ mask: UInt32,
    _ windowIDs: CFArray
) -> Unmanaged<CFArray>?

// MARK: - Window Properties

/// Gets the window level for a specified window.
@_silgen_name("CGSGetWindowLevel")
func CGSGetWindowLevel(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outLevel: UnsafeMutablePointer<Int32>
) -> CGError
