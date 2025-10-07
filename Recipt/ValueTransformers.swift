import Foundation

@objc(TagsValueTransformer)
final class TagsValueTransformer: NSSecureUnarchiveFromDataTransformer {
    override static var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSString.self]
    }
}

extension NSValueTransformerName {
    static let tagsValueTransformerName = NSValueTransformerName(
        rawValue: String(describing: TagsValueTransformer.self)
    )
}
