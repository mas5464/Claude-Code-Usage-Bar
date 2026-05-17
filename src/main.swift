import Cocoa

if CommandLine.arguments.contains("--statusline") {
    renderStatusLine()
    exit(0)
}

let app = NSApplication.shared
let del = AppDelegate()
app.delegate = del
app.run()
