import Foundation

/// "12*3+4" or "2,5×4=" at the end of the text -> result for the suggestion bar.
public enum MathEval {
    public struct Result: Equatable {
        /// Shown in the bar, e.g. "= 40".
        public let display: String
        /// Typed when tapped: the result, after "=" if the text did not end with one.
        public let insert: String
    }

    private static let allowed = Set("0123456789.,+-*/×÷^%() =")

    public static func result(contextBefore: String?) -> Result? {
        let tail = String((contextBefore ?? "").reversed().prefix { allowed.contains($0) }.reversed())
        var expr = tail.trimmingCharacters(in: .whitespaces)
        let endsWithEquals = expr.hasSuffix("=")
        if endsWithEquals { expr = String(expr.dropLast()).trimmingCharacters(in: .whitespaces) }
        while let f = expr.first, "+*/×÷^%)=".contains(f) { expr.removeFirst() } // "a-b" style text before
        guard expr.contains(where: \.isNumber) else { return nil }
        var parser = Parser(Array(expr.filter { $0 != " " }))
        guard let value = parser.parse(), parser.sawOperator, value.isFinite else { return nil }
        let text = format(value, comma: expr.contains(","))
        return Result(display: "= " + text, insert: (endsWithEquals ? "" : "=") + text)
    }

    static func format(_ v: Double, comma: Bool) -> String {
        var s: String
        if v == v.rounded(), abs(v) < 1e15 {
            s = String(Int64(v))
        } else {
            s = String(format: "%.10g", v)
            if s.contains("."), !s.contains("e") {
                while s.hasSuffix("0") { s.removeLast() }
                if s.hasSuffix(".") { s.removeLast() }
            }
        }
        return comma ? s.replacingOccurrences(of: ".", with: ",") : s
    }

    /// expr := term (+|- term)*, term := unary (*|/ unary)*, unary := -unary | power, power := atom (^ unary)?
    private struct Parser {
        let c: [Character]
        var i = 0
        var sawOperator = false

        init(_ c: [Character]) { self.c = c }

        mutating func parse() -> Double? {
            guard let v = expr(), i == c.count else { return nil }
            return v
        }

        private var peek: Character? { i < c.count ? c[i] : nil }

        private mutating func expr() -> Double? {
            guard var v = term() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                i += 1
                guard let r = term() else { return nil }
                v = op == "+" ? v + r : v - r
                sawOperator = true
            }
            return v
        }

        private mutating func term() -> Double? {
            guard var v = unary() else { return nil }
            while let op = peek, "*/×÷".contains(op) {
                i += 1
                guard let r = unary() else { return nil }
                if op == "/" || op == "÷" {
                    guard r != 0 else { return nil }
                    v /= r
                } else {
                    v *= r
                }
                sawOperator = true
            }
            return v
        }

        private mutating func unary() -> Double? {
            if peek == "-" {
                i += 1
                return unary().map { -$0 }
            }
            guard let base = atom() else { return nil }
            if peek == "^" {
                i += 1
                guard let e = unary() else { return nil }
                sawOperator = true
                return pow(base, e)
            }
            return base
        }

        private mutating func atom() -> Double? {
            var v: Double
            if peek == "(" {
                i += 1
                guard let inner = expr(), peek == ")" else { return nil }
                i += 1
                v = inner
            } else {
                let start = i
                while let ch = peek, ch.isNumber || ch == "." || ch == "," { i += 1 }
                guard i > start, let n = Double(String(c[start..<i]).replacingOccurrences(of: ",", with: ".")) else { return nil }
                v = n
            }
            if peek == "%" { // "50%" alone is not a sum to show
                i += 1
                v /= 100
            }
            return v
        }
    }
}
