# Progress

<!--
[![CI Status](http://img.shields.io/travis/popodidi/Progress.svg?style=flat)](https://travis-ci.org/popodidi/Progress)
-->
[![Version](https://img.shields.io/cocoapods/v/Progress.svg?style=flat)](http://cocoapods.org/pods/Progress)
[![License](https://img.shields.io/cocoapods/l/Progress.svg?style=flat)](http://cocoapods.org/pods/Progress)
[![Platform](https://img.shields.io/cocoapods/p/Progress.svg?style=flat)](http://cocoapods.org/pods/Progress)

Apart from any kinds of ProgresHUDs that capture the whole screen and lock the user interaction, Progress provides a more precise and elegant progress indicator. Progress allows you to add any number/kinds of progressor views into each view with only one line of code. The progress indicator can be an arbitrary combination of built-in/custom progressors. Progress helps you provide a fluent user experience in your iOS application.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

Progress is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Progress"
```

## Screenshot
![](Progress_demo.gif)

## Basic usage

```swift

// start progress
Prog.start(in: imageView, .blur(.dark), .activityIndicator)

// start progress with call back after animation
Prog.start(in: imageView, .blur(.dark), .activityIndicator) {
	// do something....
}

// update completion ratio
Prog.update(0.87, in: imageView)

// end progress
Prog.end(in: imageView)

// end progress with call back after animation
Prog.end(in: imageView) {
	// do something....
}

// dismiss progress
Prog.dismiss(in: imageView)

// dismiss progress with call back after animation
Prog.dismiss(in: imageView) {
	// do something....
}

```

### end vs. dismiss

Calling `Prog.dismiss(in:)` simply removes progressors without ending animations. For example, given a progress with `.label` progressor, `Prog.dismiss(in:)` only fades out the percentage label while `Prog.end(in:)` makes the percentage go to `100%` and then fades out the label.

### Built-in progressor types

- `.sync([ProgressorType])`
- `.color(ColorProgressorParameter?)`
- `.blur(BlurProgressorParameter?)`
- `.activityIndicator`
- `.bar(BarProgressorParameter?)`
- `.ring(RingProgressorParameter?)`
- `.label(LabelProgressorParameter?)`
- `.dismissable`

#### parameters

```swift
public typealias ColorProgressorParameter = UIColor
public let DefaultColorProgressorParameter: ColorProgressorParameter = UIColor.white.withAlphaComponent(0.5)

public typealias BlurProgressorParameter = UIBlurEffectStyle
public let DefaultBlurProgressorParameter: BlurProgressorParameter = .light

public typealias BarProgressorParameter = (type: BarProgressorType, side: BarProgressorSide, barColor: UIColor, barHeight: CGFloat)
public let DefaultBarProgressorParameter: BarProgressorParameter = (.proportional, .top, UIColor.black.withAlphaComponent(0.5), 2)

public typealias RingProgressorParameter = (type: RingProgressType, color: UIColor, radius: CGFloat,  lineWidth: CGFloat)
public let DefaultRingProgressorParameter: RingProgressorParameter = (.proportional, UIColor.black.withAlphaComponent(0.5), 12, 4)

public typealias LabelProgressorParameter = (font: UIFont, color: UIColor)
public let DefaultLabelProgressorParameter: LabelProgressorParameter = (UIFont.systemFont(ofSize: 14), .black)
```

Progress can start with multiple progressors in one parent.

> - Since `Prog` holds strong references to all the `ProgressParent` and `ProgressView`, **Always call `Prog.end(in:)`or `Prog.dismiss(in:)` at the end of progress**.
> - Make sure to `update`/`end`/`dismiss` progress after all the animations are done.
> 
> ```swift
> Prog.start(in: view, .blur(nil)) {
>   // do something
>   // ...
>   Prog.end(in: self.view)
>   // Prog.dismiss(in: self.view)
> }
> ```



### Synchronous progressor

By default, the progressors will be added and start animation one by one. When ending the progress, the progressors will end animation and be removed in reverse order. The starting and ending animations are executed one after another, i.e asynchronously. 

To have a synchronous progress animation, i.e. to execute animations of progressors at the same time, simply wrap the progressorTypes in `.sync` progressorType

```swift
let ringParam: RingProgressorParameter = (.proportional, UIColor.black.withAlphaComponent(0.4), 40, 1.5)
let labelParam: LabelProgressorParameter = (UIFont.systemFont(ofSize: 20, weight: UIFontWeightLight), UIColor.black.withAlphaComponent(0.6))

Prog.start(in: progressParent, .blur(nil), .sync([.ring(ringParam), .label(labelParam)]))
```

### Dismissable progressor

Adding `.dismissable` progressor allows user to dismiss progress on single tap.

```swift 
Prog.start(in: progressParent, .blur(nil), .sync([.ring(ringParam), .label(labelParam)]), .dismissable)
```

## Advanced usage

### ProgressParent

Classes that implement `ProgressParent` protocol are able to add/remove `ProgressView`. `UIView` and `UIViewController` conform `ProgressParent` by default.

The default implementation of `UIView` is to add `progressView` as subview with 0.2 second fade-in animation. `UIViewController` simply calls `self.view` implementations.

Fading duration can be configured by setting `Prog.fadingDuration`.

### Custom progressor

#### subclass custom progressor view

```swift
import Progress

class CustomProgressorView: ProgressorView {
    var label: UILabel = UILabel()
    override func layoutSubviews() {
        super.layoutSubviews()
        label.sizeToFit()
        label.center = center
    }
    
    // prepareForProgress is executed before being added to ProgressParent
    override func prepareForProgress(parameter: Any?) {
        addSubview(label)
        label.text = "loading..."
    }
    
    override func startProgress(parameter: Any?, completion: @escaping (() -> Void)) {
    	 // some starting animation ...
    	 // always call completion at the end of starting progress
        completion()
    }
    
    override func update(progress: Float) {
        // update progress view
        let percent = Int(floor(progress*100))
        label.text = "loading \(percent)% ..."
        setNeedsLayout()
    }
    
    override func endProgress(completion: @escaping (() -> Void)) {
        UIView.animate(withDuration: 1, animations: {
            self.label.text = "DONE!"
            self.label.transform = self.label.transform.scaledBy(x: 3, y: 3)
        }) { _ in
            // always call completion at the end of ending progress
            completion()
        }
    }
}
```

> #### Ending animation duration
> When implementing `endProgress(completion:)` with animation instead of simply call `completion()`, it is suggested to have the animation duration proportional to the remaining progress with the maximum value as `Prog.maxEndingAnimationDuration`. For example, if the progress is ending from 0.6 (60%), the animation duration should be `(1-0.6)*Prog.maxEndingAnimationDuration`.
> 
> The ending animation duration of built-in progressors can be configured by setting `Prog.maxEndingAnimationDuration` as well.

#### register custom progressor view

``` swift
Prog.register(progressor: CustomProgressorView.self, withIdentifier: "custom_example")
```

#### use as built-in ones

``` swift
Prog.start(in: imageView, .customer(identifier: "custom_example", parameter: nil))
```
The `parameter: Any?` here will be passed in to 

- `progressorView.prepareForProgress(parameter: Any?)`
- `progressorView.startProgress(parameter: Any?, completion: @escaping (() -> Void))`


## Author

[popodidi](changhao@haostudio.cc)

## License

Progress is available under the MIT license. See the LICENSE file for more info.
