import CoreGraphics
import SwiftUI

/// Parses SVG path data (the `d` attribute) into a SwiftUI `Path`.
///
/// The RN app draws its icons from single-path SVGs in `assets/icons` with a
/// 24x24 viewBox. This parser supports every path command those files use:
/// M, L, H, V, C, S, Q, T, A and Z, absolute and relative.
enum SVGPathParser {
    enum ParseError: Error, Equatable {
        case unexpectedCharacter(Character)
        case missingNumber
    }

    static func parse(_ data: String) throws -> Path {
        var scanner = Scanner(Array(data.utf8))
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: UInt8 = 0

        while scanner.skipSeparators() {
            var command: UInt8
            if let c = scanner.peekCommand() {
                command = c
                scanner.advance()
            } else if lastCommand != 0 {
                // Implicit repetition. A moveto repeats as a lineto.
                command = lastCommand == UInt8(ascii: "M") ? UInt8(ascii: "L")
                    : lastCommand == UInt8(ascii: "m") ? UInt8(ascii: "l") : lastCommand
            } else {
                throw ParseError.unexpectedCharacter(Character(UnicodeScalar(scanner.current ?? 0)))
            }
            let relative = command >= UInt8(ascii: "a")
            let upper = relative ? command - 32 : command
            let base = relative ? current : .zero

            switch upper {
            case UInt8(ascii: "M"):
                let p = try scanner.point(offset: base)
                path.move(to: p)
                current = p
                subpathStart = p
                lastControl = nil
            case UInt8(ascii: "L"):
                let p = try scanner.point(offset: base)
                path.addLine(to: p)
                current = p
                lastControl = nil
            case UInt8(ascii: "H"):
                let x = try scanner.number() + (relative ? current.x : 0)
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "V"):
                let y = try scanner.number() + (relative ? current.y : 0)
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
                lastControl = nil
            case UInt8(ascii: "C"):
                let c1 = try scanner.point(offset: base)
                let c2 = try scanner.point(offset: base)
                let p = try scanner.point(offset: base)
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            case UInt8(ascii: "S"):
                let c1 = reflect(lastControl, around: current, when: lastCommand, in: "CcSs")
                let c2 = try scanner.point(offset: base)
                let p = try scanner.point(offset: base)
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            case UInt8(ascii: "Q"):
                let c = try scanner.point(offset: base)
                let p = try scanner.point(offset: base)
                path.addQuadCurve(to: p, control: c)
                lastControl = c
                current = p
            case UInt8(ascii: "T"):
                let c = reflect(lastControl, around: current, when: lastCommand, in: "QqTt")
                let p = try scanner.point(offset: base)
                path.addQuadCurve(to: p, control: c)
                lastControl = c
                current = p
            case UInt8(ascii: "A"):
                let rx = try scanner.number()
                let ry = try scanner.number()
                let rotation = try scanner.number()
                let largeArc = try scanner.flag()
                let sweep = try scanner.flag()
                let p = try scanner.point(offset: base)
                addArc(to: &path, from: current, to: p, rx: rx, ry: ry,
                       rotationDegrees: rotation, largeArc: largeArc, sweep: sweep)
                current = p
                lastControl = nil
            case UInt8(ascii: "Z"):
                path.closeSubpath()
                current = subpathStart
                lastControl = nil
            default:
                throw ParseError.unexpectedCharacter(Character(UnicodeScalar(command)))
            }
            lastCommand = command
        }
        return path
    }

    private static func reflect(_ control: CGPoint?, around p: CGPoint, when last: UInt8, in commands: String) -> CGPoint {
        guard let control, commands.utf8.contains(last) else { return p }
        return CGPoint(x: 2 * p.x - control.x, y: 2 * p.y - control.y)
    }

    /// Converts an SVG endpoint arc to cubic Bezier segments (SVG 1.1, appendix F.6).
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint,
                               rx rxIn: CGFloat, ry ryIn: CGFloat, rotationDegrees: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 {
            path.addLine(to: p1)
            return
        }
        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : sqrt(max(0, num / den))
        if largeArc == sweep { coef = -coef }
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(step / 4)
        var theta = theta1
        for _ in 0..<segments {
            let cos1 = cos(theta), sin1 = sin(theta)
            let cos2 = cos(theta + step), sin2 = sin(theta + step)
            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: cosPhi * rx * x - sinPhi * ry * y + cx,
                        y: sinPhi * rx * x + cosPhi * ry * y + cy)
            }
            let c1 = map(cos1 - t * sin1, sin1 + t * cos1)
            let c2 = map(cos2 + t * sin2, sin2 - t * cos2)
            let end = map(cos2, sin2)
            path.addCurve(to: end, control1: c1, control2: c2)
            theta += step
        }
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0

        init(_ bytes: [UInt8]) { self.bytes = bytes }

        var current: UInt8? { index < bytes.count ? bytes[index] : nil }

        mutating func advance() { index += 1 }

        /// Skips whitespace and commas. Returns false at the end of input.
        mutating func skipSeparators() -> Bool {
            while let c = current, c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x2C {
                index += 1
            }
            return current != nil
        }

        func peekCommand() -> UInt8? {
            guard let c = current else { return nil }
            let commands = "MmLlHhVvCcSsQqTtAaZz".utf8
            return commands.contains(c) ? c : nil
        }

        mutating func flag() throws -> Bool {
            _ = skipSeparators()
            guard let c = current, c == UInt8(ascii: "0") || c == UInt8(ascii: "1") else {
                throw ParseError.missingNumber
            }
            index += 1
            return c == UInt8(ascii: "1")
        }

        mutating func point(offset: CGPoint) throws -> CGPoint {
            let x = try number()
            let y = try number()
            return CGPoint(x: x + offset.x, y: y + offset.y)
        }

        mutating func number() throws -> CGFloat {
            _ = skipSeparators()
            let start = index
            if let c = current, c == UInt8(ascii: "-") || c == UInt8(ascii: "+") { index += 1 }
            var sawDot = false
            var sawDigit = false
            while let c = current {
                if c >= UInt8(ascii: "0") && c <= UInt8(ascii: "9") {
                    sawDigit = true
                    index += 1
                } else if c == UInt8(ascii: ".") && !sawDot {
                    sawDot = true
                    index += 1
                } else if (c == UInt8(ascii: "e") || c == UInt8(ascii: "E")) && sawDigit {
                    index += 1
                    if let s = current, s == UInt8(ascii: "-") || s == UInt8(ascii: "+") { index += 1 }
                } else {
                    break
                }
            }
            guard sawDigit, let value = Double(String(decoding: bytes[start..<index], as: UTF8.self)) else {
                throw ParseError.missingNumber
            }
            return CGFloat(value)
        }
    }
}
