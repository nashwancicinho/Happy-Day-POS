import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override var isOpaque: Bool {
    get { return true }
    set { super.isOpaque = true }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let defaultSize = NSSize(width: 1100, height: 750)
    self.setContentSize(defaultSize)
    self.minSize = NSSize(width: 900, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.isOpaque = true
    self.backgroundColor = NSColor.windowBackgroundColor
    self.titlebarAppearsTransparent = false

    super.awakeFromNib()
  }
}
