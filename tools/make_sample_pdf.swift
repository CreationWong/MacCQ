import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: make_sample_pdf <in.txt> <out.pdf>\n".data(using: .utf8)!)
    exit(1)
}
let inPath = args[1]
let outPath = args[2]

guard let text = try? String(contentsOfFile: inPath, encoding: .utf8) else {
    FileHandle.standardError.write("cannot read input\n".data(using: .utf8)!)
    exit(2)
}

let pageSize = CGSize(width: 612, height: 792) // US Letter
var mediaBox = CGRect(origin: .zero, size: pageSize)
let data = NSMutableData()

guard let consumer = CGDataConsumer(data: data as CFMutableData),
      let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    FileHandle.standardError.write("cannot create context\n".data(using: .utf8)!)
    exit(3)
}

let lines = text.components(separatedBy: .newlines)
let fontSize: CGFloat = 11
let fontName = "PingFangSC-Regular" as CFString
var font: CTFont? = CTFontCreateWithName(fontName, fontSize, nil)
func drawText(_ string: String, at y: CGFloat, bold: Bool) -> CGFloat {
    var f = font ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
    if bold { f = CTFontCreateWithName("PingFangSC-Semibold" as CFString, fontSize, nil) }
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
    ]
    let lineHeight = ceil(CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f))
    let attrStr = NSAttributedString(string: string, attributes: attrs)
    let ctLine = CTLineCreateWithAttributedString(attrStr)
    ctx.textPosition = CGPoint(x: 48, y: y)
    CTLineDraw(ctLine, ctx)
    return y - (lineHeight + 2)
}

var pageIndex = 0
var currentY: CGFloat = 0
var writtenPages = 0

func beginPage() {
    ctx.beginPDFPage(nil)
    ctx.textMatrix = .identity
    currentY = pageSize.height - 60
}

beginPage()
for line in lines {
    let trimmed = line
    let isBold = trimmed.contains("操作技术能力题库")
    if currentY < 48 {
        ctx.endPDFPage()
        beginPage()
        pageIndex += 1
    }
    currentY = drawText(trimmed, at: currentY, bold: isBold)
}
ctx.endPDFPage()

ctx.closePDF()

let _ = data.write(toFile: outPath, atomically: true)
print("wrote \(outPath)")
