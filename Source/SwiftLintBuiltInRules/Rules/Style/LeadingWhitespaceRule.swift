import Foundation
import SourceKittenFramework

struct LeadingWhitespaceRule: CorrectableRule, SourceKitFreeRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "leading_whitespace",
        name: "Leading Whitespace",
        description: "Files should not contain leading whitespace",
        kind: .style,
        nonTriggeringExamples: [
            Example("//")
        ],
        triggeringExamples: [
            Example("\n//"),
            Example(" //"),
        ].skipMultiByteOffsetTests().skipDisableCommandTests(),
        corrections: [
            Example("\n //", testMultiByteOffsets: false): Example("//")
        ]
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        let countOfLeadingWhitespace = file.contents.countOfLeadingCharacters(in: .whitespacesAndNewlines)
        if countOfLeadingWhitespace == 0 {
            return []
        }

        return [
            StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: Location(file: file.path, line: 1)
            ),
        ]
    }

    func correct(file: SwiftLintFile) -> Int {
        let whitespaceAndNewline = CharacterSet.whitespacesAndNewlines
        let spaceCount = file.contents.countOfLeadingCharacters(in: whitespaceAndNewline)
        guard spaceCount > 0,
              let firstLineRange = file.lines.first?.range,
              file.ruleEnabled(violatingRanges: [firstLineRange], for: self).isNotEmpty else {
            return 0
        }

        let indexEnd = file.contents.index(
            file.contents.startIndex,
            offsetBy: spaceCount,
            limitedBy: file.contents.endIndex) ?? file.contents.endIndex
        file.write(String(file.contents[indexEnd...]))
        return 1
    }
}
