import Foundation
import SourceKittenFramework

private extension SwiftLintFile {
    func violatingRanges(for pattern: String) -> [NSRange] {
        match(pattern: pattern, excludingSyntaxKinds: SyntaxKind.commentKinds)
    }
}

struct VerticalWhitespaceBetweenCasesRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    private static let nonTriggeringExamples: [Example] = [
        Example("""
            switch x {

            case 0..<5:
                print("x is low")

            case 5..<10:
                print("x is high")

            default:
                print("x is invalid")

            @unknown default:
                print("x is out of this world")
            }
            """),
        Example("""
            switch x {
            case 0..<5:
                print("x is low")

            case 5..<10:
                print("x is high")

            default:
                print("x is invalid")
            }
            """),
        Example("""
            switch x {
            case 0..<5: print("x is low")
            case 5..<10: print("x is high")
            default: print("x is invalid")
            @unknown default: print("x is out of this world")
            }
            """),
        // Testing handling of trailing spaces: do not convert to """ style
        Example([
            "switch x {    \n",
            "case 1:    \n",
            "    print(\"one\")    \n",
            "    \n",
            "default:    \n",
            "    print(\"not one\")    \n",
            "}    ",
        ].joined()),
    ]

    private static let violatingToValidExamples: [Example: Example] = [
        Example("""
            switch x {
            case 0..<5:
                return "x is valid"
            ↓default:
                return "x is invalid"
            ↓@unknown default:
                print("x is out of this world")
            }
            """): Example("""
                switch x {
                case 0..<5:
                    return "x is valid"

                default:
                    return "x is invalid"

                @unknown default:
                    print("x is out of this world")
                }
                """),
        Example("""
            switch x {
            case 0..<5:
                print("x is valid")
            ↓default:
                print("x is invalid")
            }
            """): Example("""
                switch x {
                case 0..<5:
                    print("x is valid")

                default:
                    print("x is invalid")
                }
                """),
        Example("""
            switch x {
            case .valid:
                print("x is valid")
            ↓case .invalid:
                print("x is invalid")
            }
            """): Example("""
                switch x {
                case .valid:
                    print("x is valid")

                case .invalid:
                    print("x is invalid")
                }
                """),
        Example("""
            switch x {
            case .valid:
                print("multiple ...")
                print("... lines")
            ↓case .invalid:
                print("multiple ...")
                print("... lines")
            }
            """): Example("""
                switch x {
                case .valid:
                    print("multiple ...")
                    print("... lines")

                case .invalid:
                    print("multiple ...")
                    print("... lines")
                }
                """),
    ]

    private let pattern = "([^\\n{][ \\t]*\\n)([ \\t]*(?:case[^\\n]+|default|@unknown default):[ \\t]*\\n)"

    private func violationRanges(in file: SwiftLintFile) -> [NSRange] {
        file.violatingRanges(for: pattern).filter {
            !isFalsePositive(in: file, range: $0)
        }
    }

    private func isFalsePositive(in file: SwiftLintFile, range: NSRange) -> Bool {
        // Regex incorrectly flags blank lines that contain trailing whitespace (#2538)
        let patternRegex = regex(pattern)
        let substring = file.contents.substring(from: range.location, length: range.length)
        guard let matchResult = patternRegex.firstMatch(in: substring, options: [], range: substring.fullNSRange),
              matchResult.numberOfRanges > 1 else {
            return false
        }

        let matchFirstRange = matchResult.range(at: 1)
        let matchFirstString = substring.substring(from: matchFirstRange.location, length: matchFirstRange.length)
        return matchFirstString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension VerticalWhitespaceBetweenCasesRule: OptInRule {
    static let description = RuleDescription(
        identifier: "vertical_whitespace_between_cases",
        name: "Vertical Whitespace Between Cases",
        description: "Include a single empty line between switch cases",
        kind: .style,
        nonTriggeringExamples: (violatingToValidExamples.values + nonTriggeringExamples).sorted(),
        triggeringExamples: Array(violatingToValidExamples.keys).sorted(),
        corrections: violatingToValidExamples.removingViolationMarkers()
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        let patternRegex = regex(pattern)
        return violationRanges(in: file).compactMap { violationRange in
            let substring = file.contents.substring(from: violationRange.location, length: violationRange.length)
            guard let matchResult = patternRegex.firstMatch(in: substring, options: [],
                                                            range: substring.fullNSRange) else {
                return nil
            }

            let violatingSubrange = matchResult.range(at: 2)
            let characterOffset = violationRange.location + violatingSubrange.location

            return StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: Location(file: file, characterOffset: characterOffset)
            )
        }
    }
}

extension VerticalWhitespaceBetweenCasesRule: CorrectableRule {
    func correct(file: SwiftLintFile) -> Int {
        let violatingRanges = file.ruleEnabled(violatingRanges: violationRanges(in: file), for: self)
        guard violatingRanges.isNotEmpty else {
            return 0
        }
        let patternRegex = regex(pattern)
        var fileContents = file.contents
        for violationRange in violatingRanges.reversed() {
            fileContents = patternRegex.stringByReplacingMatches(
                in: fileContents,
                options: [],
                range: violationRange,
                withTemplate: "$1\n$2"
            )
        }
        file.write(fileContents)
        return violatingRanges.count
    }
}
