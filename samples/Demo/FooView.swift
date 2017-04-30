import UIKit

class FooView: UIView {

  let appearanceProxy = S.FooViewAppearanceProxy()

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.didChangeAppearanceProxy()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func didChangeAppearanceProxy() {
    self.backgroundColor = self.appearanceProxy.backgroundColor
  }
}
