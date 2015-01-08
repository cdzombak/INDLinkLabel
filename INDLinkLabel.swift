//
//  INDLinkLabel.swift
//  INDLinkLabel
//
//  Created by Indragie on 12/31/14.
//  Copyright (c) 2014 Indragie Karunaratne. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:

//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.

//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

/// A simple UILabel subclass that is similar to UILabel but allows for
/// tapping on links (i.e. anything marked with `NSLinkAttributeName`)
@IBDesignable public class INDLinkLabel: UILabel {
    
    override public var attributedText: NSAttributedString! {
        didSet { cacheLinkRanges() }
    }
    
    override public var lineBreakMode: NSLineBreakMode {
        didSet { textContainer.lineBreakMode = lineBreakMode }
    }
    
    /// The color of the highlight that appears over a link when tapping on it
    @IBInspectable public var linkHighlightColor: UIColor = UIColor(white: 0, alpha: 0.2)
    
    /// The corner radius of the highlight that appears over a link when
    /// tapping on it
    @IBInspectable public var linkHighlightCornerRadius: CGFloat = 2
    
    // MARK: Text Layout
    
    override public var numberOfLines: Int {
        didSet {
            textContainer.maximumNumberOfLines = numberOfLines
        }
    }
    
    // MARK: Tap Handling
    
    public typealias LinkHandler = NSURL -> Void
    
    /// Called when a link is tapped.
    ///
    /// If no handler is provided, the link will be opened using
    /// `UIApplication.openURL()`
    public var linkTapHandler: LinkHandler?
    
    /// Called when a link is long pressed.
    ///
    /// If no handler is provided, nothing will happen on logn press.
    public var linkLongPressHandler: LinkHandler?
    
    // MARK: Private
    
    private var layoutManager: NSLayoutManager!
    private var textStorage: NSTextStorage!
    private var textContainer: NSTextContainer!
    
    private struct LinkRange {
        let URL: NSURL
        let glyphRange: NSRange
    }
    
    private var linkRanges: [LinkRange]?
    private var tappedLinkRange: LinkRange?
    
    // MARK: Initialization
    
    private func commonInit() {
        textContainer = NSTextContainer()
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = lineBreakMode
        textContainer.lineFragmentPadding = 0
        
        layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        
        userInteractionEnabled = true
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: Selector("handleTap:")))
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: Selector("handleLongPress:")))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: Attributes
    
    private func synchronizeTextStack() {
        textStorage.setAttributedString(attributedText)
        textContainer.size = CGSize(width: CGRectGetWidth(bounds), height: CGFloat.max)
    }
    
    private func cacheLinkRanges() {
        synchronizeTextStack()
        
        var ranges = [LinkRange]()
        textStorage.enumerateAttribute(NSLinkAttributeName, inRange: NSRange(location: 0, length: textStorage.length), options: nil) { (value, range, _) in
            // Because NSLinkAttributeName supports both NSURL and NSString
            // values. *sigh*
            let URL: NSURL? = {
                if let string = value as? String {
                    return NSURL(string: string)
                } else if let URL = value as? NSURL {
                    return URL
                }
                return nil
                }()
            if let URL = URL {
                self.layoutManager.ensureLayoutForCharacterRange(range)
                let glyphRange = self.layoutManager.glyphRangeForCharacterRange(range, actualCharacterRange: nil)
                ranges.append(LinkRange(URL: URL, glyphRange: glyphRange))
            }
        }
        linkRanges = ranges
    }
    
    // MARK: Drawing
    
    public override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        
        if let linkRange = tappedLinkRange {
            linkHighlightColor.setFill()
            for rect in highlightRectsForGlyphRange(linkRange.glyphRange) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: linkHighlightCornerRadius)
                path.fill()
            }
        }
    }
    
    private func highlightRectsForGlyphRange(range: NSRange) -> [CGRect] {
        var rects = [CGRect]()
        layoutManager.enumerateLineFragmentsForGlyphRange(range) { (_, rect, _, effectiveRange, _) in
            let boundingRect = self.layoutManager.boundingRectForGlyphRange(NSIntersectionRange(range, effectiveRange), inTextContainer: self.textContainer)
            rects.append(boundingRect)
        }
        return rects
    }
    
    // MARK: Touches
    
    private func linkRangeAtPoint(point: CGPoint) -> LinkRange? {
        if let linkRanges = linkRanges {
            synchronizeTextStack()
            layoutManager.ensureLayoutForTextContainer(textContainer)
            
            let glyphIndex = layoutManager.glyphIndexForPoint(point, inTextContainer: textContainer)
            for linkRange in linkRanges {
                if NSLocationInRange(glyphIndex, linkRange.glyphRange) {
                    return linkRange
                }
            }
        }
        return nil
    }
    
    public override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        tappedLinkRange = linkRangeAtPoint(touches.anyObject()!.locationInView(self))
        setNeedsDisplay()
    }
    
    public override func touchesEnded(touches: NSSet, withEvent event: UIEvent) {
        tappedLinkRange = nil
        setNeedsDisplay()
    }
    
    public override func touchesCancelled(touches: NSSet!, withEvent event: UIEvent!) {
        tappedLinkRange = nil
        setNeedsDisplay()
    }
    
    @objc private func handleTap(gestureRecognizer: UIGestureRecognizer) {
        if let linkRange = tappedLinkRange {
            if let handler = linkTapHandler {
                handler(linkRange.URL)
            } else {
                UIApplication.sharedApplication().openURL(linkRange.URL)
            }
        }
    }
    
    @objc private func handleLongPress(gestureRecognizer: UIGestureRecognizer) {
        if let linkRange = tappedLinkRange {
            if let handler = linkLongPressHandler {
                handler(linkRange.URL)
            }
        }
    }
}
