
import Foundation

let tagRegex = try! NSRegularExpression(pattern: "(?:^|\\s+)@([A-z0-9]+)(?:\\(([^()])*)\\)?(?=\\s|$)", options: [])

struct TaskPaper {
	
	struct Options: OptionSet {
		let rawValue: Int
		
		static let normalize = Options(rawValue: 1 << 0)
	}
	
	var document: Document
	
	init(_ string: String, options: Options=[]) {
		self.document = Document()
		
		var input = string
		
		if options.contains(.normalize) {
			input = (string as NSString).replacingOccurrences(of: "(\r\n|\n|\r)", with: "\n", options: .regularExpression, range: NSMakeRange(0, (string as NSString).length))
		}
		
		parse(input as NSString)
	}
	
	func parse(_ input: NSString) {
		
		for (lineRange, line) in input.lines {
			let indentRange = input.range(of: "^\t*", options: .regularExpression, range: lineRange)
			var bodyRange = NSMakeRange(NSMaxRange(indentRange), lineRange.length - indentRange.length)
			
			// parse tags first, since bodyRange excludes trailing tags
			let tags = tagsForLine(input: input, lineRange: lineRange)
			
			// remove trailing tags from bodyRange
			if let trailingRange = trailingRangeForLine(input: input, lineRange: lineRange, tags: tags) {
				bodyRange.length -= trailingRange.length
			}
			
			// parse item and add attributes
			let item = itemForLine(input: input, line: line, lineRange: lineRange, indentRange: indentRange, bodyRange: bodyRange)
			item.addAttributes(tags)
			
			// attach item
			let container = appropriateContainer(for: item, level: indentRange.length)
			container.addChild(item)
		}
		
	}
	
	func tagsForLine(input: NSString, lineRange: NSRange) -> [Attribute] {
		var attributes: [Attribute] = []
		
		tagRegex.enumerateMatches(in: input as String, options: [], range: lineRange) { (result, flags, stop) in
			guard let result = result else { return }
			
			let name = input.substring(with: result.rangeAt(1))
			var value: String? = input.substring(with: result.rangeAt(2))
			if value!.isEmpty {
				value = nil
			}
			
			let attr = Attribute(name: name, value: value, sourceRange: result.range)
			
			attributes.append(attr)
		}
		
		return attributes
	}
	
	func trailingRangeForLine(input: NSString, lineRange: NSRange, tags: [Attribute]) -> NSRange? {
		guard let lastAttr = tags.last else {
			return nil
		}
		
		guard NSMaxRange(lastAttr.sourceRange) == NSMaxRange(lineRange) else {
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
		let taskRange = input.range(of: "^([\\-+*]\\s)", options: .regularExpression, range: bodyRange)
		
		if taskRange.location != NSNotFound {
			let contentRange = NSMakeRange(NSMaxRange(taskRange), lineRange.length - NSMaxRange(taskRange))
			
			return Item(type: .task, sourceRange: lineRange, contentRange: contentRange)
		}
		
		if line.hasSuffix(":") {
			let contentRange = NSMakeRange(NSMaxRange(indentRange), lineRange.length - 1 - NSMaxRange(indentRange))
			
			return Item(type: .project, sourceRange: lineRange, contentRange: contentRange)
		}
		
		let contentRange = NSMakeRange(NSMaxRange(indentRange), lineRange.length - NSMaxRange(indentRange))
		
		return Item(type: .note, sourceRange: lineRange, contentRange: contentRange)
	}
	
	func appropriateContainer(for item: Item, level itemLevel: Int) -> Container {
		var container: Container = document
		var containerLevel = 0
		
		while let lastChild = container.children.last {
			if containerLevel < itemLevel {
				container = lastChild
				containerLevel += 1
			} else {
				break
			}
		}
		
		return container
	}
	
}
