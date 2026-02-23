import Foundation

// Registers all 10 built-in tools into the provided registry.
// Called by AppDelegate at startup and by integration tests.
func registerBuiltInTools(in registry: any ToolRegistry) throws {
    try registry.register(SystemInfoTool())
    try registry.register(AppListTool())
    try registry.register(AppOpenTool())
    try registry.register(FileSearchTool())
    try registry.register(FileReadTool())
    try registry.register(FileWriteTool())
    try registry.register(ClipboardReadTool())
    try registry.register(ClipboardWriteTool())
    try registry.register(WindowListTool())
    try registry.register(WindowManageTool())
}
