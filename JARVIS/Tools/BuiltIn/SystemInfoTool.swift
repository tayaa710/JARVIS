import Foundation

struct SystemInfoTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "system_info",
            description: "Returns macOS system information including OS version, hostname, username, disk space, and memory",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let hostname = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let username = NSUserName()

        let diskInfo = diskSpaceInfo()
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        let content = """
        OS Version: \(osVersion)
        Hostname: \(hostname)
        User: \(username)
        Disk Total: \(diskInfo.totalGB) GB
        Disk Free: \(diskInfo.freeGB) GB
        RAM: \(String(format: "%.1f", ramGB)) GB
        """

        Logger.tools.info("system_info executed for id=\(id)")
        return ToolResult(toolUseId: id, content: content, isError: false)
    }

    // MARK: - Private

    private struct DiskInfo {
        let totalGB: String
        let freeGB: String
    }

    private func diskSpaceInfo() -> DiskInfo {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return DiskInfo(totalGB: "N/A", freeGB: "N/A")
        }
        let totalGB = String(format: "%.1f", Double(total) / 1_073_741_824)
        let freeGB = String(format: "%.1f", Double(free) / 1_073_741_824)
        return DiskInfo(totalGB: totalGB, freeGB: freeGB)
    }
}
