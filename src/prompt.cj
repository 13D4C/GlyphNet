package glyphnet

public let PROMPT_TERMINATORS: Array<UInt8> = [
    UInt8(35),
    UInt8(62),
    UInt8(36),
    UInt8(37),
    UInt8(58)
]

public func isPromptTerminator(b: UInt8): Bool {
    for (t in PROMPT_TERMINATORS) {
        if (b == t) {
            return true
        }
    }
    return false
}

public func stripAnsiEscapes(input: String): String {
    let bytes = input.toArray()
    let out = Array<UInt8>(bytes.size, repeat: 0)
    var w = 0
    var i = 0
    let ESC: UInt8 = 27
    let BEL: UInt8 = 7

    while (i < bytes.size) {
        let b = bytes[i]
        if (b != ESC) {
            out[w] = b
            w += 1
            i += 1
            continue
        }

        if (i + 1 >= bytes.size) {
            i += 1
            continue
        }
        let next = bytes[i + 1]
        if (next == UInt8(91)) {
            var j = i + 2
            while (j < bytes.size) {
                let c = bytes[j]

                if (c >= UInt8(64) && c <= UInt8(126)) {
                    break
                }
                j += 1
            }
            i = j + 1
            continue
        }
        if (next == UInt8(93)) {
            var j = i + 2
            while (j < bytes.size) {
                if (bytes[j] == BEL) {
                    break
                }
                if (bytes[j] == ESC && j + 1 < bytes.size && bytes[j + 1] == UInt8(92)) {
                    j += 1
                    break
                }
                j += 1
            }
            i = j + 1
            continue
        }

        i += 2
    }
    return String.fromUtf8(out[0..w])
}

public func normalizeLineEndings(input: String): String {
    let bytes = input.toArray()
    let out = Array<UInt8>(bytes.size, repeat: 0)
    var w = 0
    var i = 0
    let CR: UInt8 = 13
    let LF: UInt8 = 10
    while (i < bytes.size) {
        let b = bytes[i]
        if (b == CR) {
            if (i + 1 < bytes.size && bytes[i + 1] == LF) {
                out[w] = LF
                w += 1
                i += 2
                continue
            }
            out[w] = LF
            w += 1
            i += 1
            continue
        }
        out[w] = b
        w += 1
        i += 1
    }
    return String.fromUtf8(out[0..w])
}

public func cleanOutput(input: String): String {
    return normalizeLineEndings(stripAnsiEscapes(input))
}

public func lastNonEmptyLine(text: String): String {
    let normalized = normalizeLineEndings(text)
    let lines = normalized.split("\n")
    var i = lines.size - 1
    while (i >= 0) {
        let candidate = lines[i].trimAsciiEnd()
        if (!candidate.trimAscii().isEmpty()) {
            return candidate
        }
        i -= 1
    }
    return ""
}

public func looksLikeBracketPrompt(line: String): Bool {
    let t = line.trimAsciiEnd()
    if (t.size < 3) {
        return false
    }
    if (!t.startsWith("[") || !t.endsWith("]")) {
        return false
    }
    return !t.toAsciiLower().startsWith("[edit")
}

public func promptStem(prompt: String): String {
    var s = prompt.trimAscii()

    while (!s.isEmpty()) {
        let bytes = s.toArray()
        let last = bytes[bytes.size - 1]
        if (isPromptTerminator(last) || last == UInt8(32) || last == UInt8(9) ||
            looksLikeBracketPrompt(s)) {
            s = String.fromUtf8(bytes[0..(bytes.size - 1)])
            continue
        }
        break
    }
    return s
}

public func promptBase(stem: String): String {
    let idx = stem.indexOf("(")
    match (idx) {
        case Some(i) =>
            if (i > 0) {
                return stem[0..i]
            }
            return stem
        case None => return stem
    }
}

public func looksLikePrompt(line: String, stem: String): Bool {
    let t = line.trimAsciiEnd()
    if (t.isEmpty()) {
        return false
    }
    let bytes = t.toArray()
    if (!isPromptTerminator(bytes[bytes.size - 1]) && !looksLikeBracketPrompt(t)) {
        return false
    }
    if (stem.isEmpty()) {
        return true
    }
    return t.startsWith(promptBase(stem))
}

public func endsWithPrompt(buffer: String, stem: String): Bool {
    if (buffer.isEmpty()) {
        return false
    }

    let normalized = normalizeLineEndings(buffer)
    let trimmed = normalized.trimAsciiEnd()
    if (trimmed.isEmpty()) {
        return false
    }
    return looksLikePrompt(lastNonEmptyLine(trimmed), stem)
}

public func extractCommandOutput(raw: String, command: String, stem: String): String {
    let cleaned = cleanOutput(raw)
    var lines = cleaned.split("\n")

    var startIdx = 0
    var endIdx = lines.size

    let cmd = command.trimAscii()
    if (!cmd.isEmpty()) {
        var i = 0
        while (i < lines.size && i < 3) {
            let line = lines[i].trimAsciiEnd()
            if (line.endsWith(cmd) || line.trimAscii() == cmd) {
                startIdx = i + 1
                break
            }
            i += 1
        }
    }

    var j = endIdx - 1
    while (j >= startIdx) {
        let line = lines[j].trimAsciiEnd()
        if (line.trimAscii().isEmpty()) {
            j -= 1
            continue
        }
        if (looksLikePrompt(line, stem)) {
            endIdx = j
        }
        break
    }

    while (startIdx < endIdx && lines[startIdx].trimAscii().isEmpty()) {
        startIdx += 1
    }

    if (startIdx >= endIdx) {
        return ""
    }

    let sb = StringBuilder()
    var k = startIdx
    var wroteAny = false
    while (k < endIdx) {
        if (wroteAny) {
            sb.append("\n")
        }
        sb.append(lines[k].trimAsciiEnd())
        wroteAny = true
        k += 1
    }

    return sb.toString().trimAsciiEnd()
}
