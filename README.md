# S

_Get strong typed, autocompleted resources like images, fonts and colors in Swift projects_

**S** is inspired (and complementary) to **R**.
It generates swift code from a **YAML** stylesheet. 

This:

```yaml

Color:
  red:
    "horizontal = compact and idiom = phone": "#aa0000"
    "default": "#ff0000"
  blue: "#00ff00"

Typography:
  small: Font("Helvetica", 12)
  
FooView:
  background: $Color.red
  font: $Typography.small

```

is transformed into a strongly typed, stylesheet in swift

```swift 

///Entry point for the app stylesheet
public class S {

	public static let FooView = FooViewStyle()
	public class FooViewStyle {
		public var background: UIColor { return Color.red  }
		public var font: UIFont { return Typography.small }
	}
    
	public static let Color = ColorStyle()
	public class ColorStyle {

		public var blue: UIColor { return UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0) }
		public var red: UIColor { return self.redWithTraitCollection() }

		public func redWithTraitCollection(traitCollection: UITraitCollection? = UIScreen.mainScreen().traitCollection) -> UIColor {
			if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Phone  && traitCollection?.horizontalSizeClass == .Compact {
                return UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0)
            }
			return UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
		}
	}
    
	public static let Typography = TypographyStyle()
	public class TypographyStyle {
		public var small: UIFont { return UIFont(name: "Helvetica", size: 12.0)! }
	}
}

```
And you can access to it by simply typing  `S.Color.red` 


## Installation
One line installation.
Copy and paste this in your terminal.

```
git clone https://github.com/alexdrone/S.git && cd S && cp sgen /usr/local/bin/sgen && chmod +x /usr/local/bin/sgen
```

The usage of the generator is as simple as 
```
sgen $SRCROOT
```

## Adding S as a build script

You can integrate **S** in your build pashes by adding it as a build script.

- Click on your **TARGET** abd go the **Build Phases** tab.
- Click on the **+** and select **New Run Script Phase** 

<p align="center">
![GitHub Logo](Doc/screen_1.jpg)

- Expand the **Run script** section
- Add `sgen $SRCROOT` in the script

<p align="center">
![GitHub Logo](Doc/screen_2.jpg)

- Now you can create your `.yaml` stylesheet. Make sure it is placed inside your project source root (`$SRCROOT`)

<p align="center">
![GitHub Logo](Doc/screen_3.jpg)

- The first time you build your target (with `cmd + B`) you need to drag the generated file inside the project. The generated swift file sits next to your stylesheet so, simply right click on your yaml stylesheet and select **Show in Finder** and drag the  `*.generated.swift` file inside your project


<p align="center">
![GitHub Logo](Doc/screen_4.jpg)

- Et voilà! Every time you will build your target the generated file will be updated as well.