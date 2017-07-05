
import Foundation

let indentRegex = try! NSRegularExpression(pattern: "^\t*", options: [])
let taskRegex = try! NSRegularExpression(pattern: "^([\\-+*]\\s)", options: [])
let projectRegex = try! NSRegularExpression(pattern: ":(?:\n|$)", options: [])
let tagRegex = try! NSRegularExpression(pattern: "(?:^|\\s+)@([A-z0-9]+)(?:\\(([^()]*)\\))?(?=\\s|$)", options: [])

struct TaskPaper {
	
	struct Options: OptionSet {
		let rawValue: Int
		
		static let normalize = Options(rawValue: 1 << 0)
	}
	
	var items: [Item] = []
	
	init(_ string: String, options: Options=[]) {
		var input = string
		
		if options.contains(.normalize) {
			input = (string as NSString).replacingOccurrences(of: "(\r\n|\n|\r)", with: "\n", options: .regularExpression, range: NSMakeRange(0, (string as NSString).length))
		}
		
		parse(input as NSString)
	}
	
	mutating func parse(_ input: NSString) {
		
		for (lineRange, line) in input.lines {
			let indentRange = indentRegex.rangeOfFirstMatch(in: input as String, options: [], range: lineRange)
			var bodyRange = NSMakeRange(NSMaxRange(indentRange), lineRange.length - indentRange.length)
			
			// trim newlines
			let newlineRange = input.rangeOfCharacter(from: CharacterSet.newlines, options: .backwards, range: lineRange)
			if newlineRange.location != NSNotFound, NSMaxRange(newlineRange) == NSMaxRange(lineRange) {
				bodyRange.length -= newlineRange.length
			}
			
			// parse tags first, since bodyRange excludes trailing tags
			let tags = tagsForLine(input: input, lineRange: lineRange)
			
			// remove trailing tags from bodyRange
			if let trailingRange = trailingRangeForLine(input: input, bodyRange: bodyRange, tags: tags) {
				bodyRange.length -= trailingRange.length
			}
			
			// parse item and add attributes
			let item = itemForLine(input: input, line: line, lineRange: lineRange, indentRange: indentRange, bodyRange: bodyRange)
			item.addAttributes(tags)
			
			attachItem(item, itemLevel: indentRange.length)
		}
		
	}
	
	func tagsForLine(input: NSString, lineRange: NSRange) -> [Attribute] {
		var attributes: [Attribute] = []
		
		tagRegex.enumerateMatches(in: input as String, options: [], range: lineRange) { (result, flags, stop) in
			guard let result = result else { return }
			
			let name = input.substring(with: result.rangeAt(1))
			var value: String? = nil
			if result.rangeAt(2).length > 0 {
				value = input.substring(with: result.rangeAt(2))
			}
			
			let attr = Attribute(name: name, value: value, sourceRange: result.range)
			
			attributes.append(attr)
		}
		
		return attributes
	}
	
	func trailingRangeForLine(input: NSString, bodyRange: NSRange, tags: [Attribute]) -> NSRange? {
		guard let lastAttr = tags.last else {
			return nil
		}
		
		guard NSMaxRange(lastAttr.sourceRange) == NSMaxRange(bodyRange) else {
			return nil
		}
		
		var trailRange = lastAttr.sourceRange
		for attr in tags.reversed() {
			if NSMaxRange(attr.sourceRange) == trailRange.location {
				trailRange.location = attr.sourceRange.location
				trailRange.length += attr.sourceRange.length
			} else {
				break
			}
		}
		
		return trailRange
	}
	
	func itemForLine(input: NSString, line: NSString, lineRange: NSRange, indentRange: NSRange, bodyRange: NSRange) -> Item {
		let taskRange = taskRegex.rangeOfFirstMatch(in: input as String, options: [], range: bodyRange)
		
		if taskRange.location != NSNotFound {
			let contentRange = NSMakeRange(NSMaxRange(taskRange), NSMaxRange(bodyRange) - NSMaxRange(taskRange))
			
			return Item(type: .task, sourceRange: lineRange, contentRange: contentRange)
		}
		
		let projectRange = projectRegex.rangeOfFirstMatch(in: input as String, options: [], range: bodyRange)
		
		if projectRange.location != NSNotFound {
			let contentRange = NSMakeRange(NSMaxRange(indentRange), NSMaxRange(bodyRange) - 1 - NSMaxRange(indentRange))
			
			return Item(type: .project, sourceRange: lineRange, contentRange: contentRange)
		}
		
		let contentRange = NSMakeRange(NSMaxRange(indentRange), NSMaxRange(bodyRange) - NSMaxRange(indentRange))
		
		return Item(type: .note, sourceRange: lineRange, contentRange: contentRange)
	}
	
	mutating func attachItem(_ item: Item, itemLevel: Int) {
		var container: Item? = nil
		var containerLevel = 0
		
		// find container
		if let lastItem = items.last {
			
			if containerLevel < itemLevel {
				container = lastItem
				containerLevel += 1
			}
			
			while let lastChild = container?.children.last {
				if containerLevel < itemLevel {
					container = lastChild
					containerLevel += 1
				} else {
					break
				}
			}
			
		}
		
		// attach
		if let container = container {
			container.addChild(item)
		} else {
			items.append(item)
		}
	}
	
}
