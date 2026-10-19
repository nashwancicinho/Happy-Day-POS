import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override var isOpaque: Bool {
    get { return true }
    set { super.isOpaque = true }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.isOpaque = true
    self.backgroundColor = NSColor.windowBackgroundColor
    self.titlebarAppearsTransparent = false

    super.awakeFromNib()
  }
}
