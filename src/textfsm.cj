package glyphnet

import glyphnet.errors.*
import std.collection.*
import std.regex.*

const TEXTFSM_MAX_NAME_LEN: Int64 = 48

const TFSM_TAB: UInt8 = 9
const TFSM_SPACE: UInt8 = 32
const TFSM_HASH: UInt8 = 35
const TFSM_DOLLAR: UInt8 = 36
const TFSM_OPEN_PAREN: UInt8 = 40
const TFSM_CLOSE_PAREN: UInt8 = 41
const TFSM_DASH: UInt8 = 45
const TFSM_ZERO: UInt8 = 48
const TFSM_NINE: UInt8 = 57
const TFSM_GT: UInt8 = 62
const TFSM_UPPER_A: UInt8 = 65
const TFSM_UPPER_Z: UInt8 = 90
const TFSM_BACKSLASH: UInt8 = 92
const TFSM_UNDERSCORE: UInt8 = 95
const TFSM_LOWER_A: UInt8 = 97
const TFSM_LOWER_Z: UInt8 = 122
const TFSM_OPEN_BRACE: UInt8 = 123
const TFSM_CLOSE_BRACE: UInt8 = 125

func tfsmIsSpace(b: UInt8): Bool {
    return b == TFSM_SPACE || b == TFSM_TAB
}

func tfsmIsDigit(b: UInt8): Bool {
    return b >= TFSM_ZERO && b <= TFSM_NINE
}

func tfsmIsAlpha(b: UInt8): Bool {
    return (b >= TFSM_UPPER_A && b <= TFSM_UPPER_Z) || (b >= TFSM_LOWER_A && b <= TFSM_LOWER_Z)
}

func tfsmIsWord(b: UInt8): Bool {
    return tfsmIsAlpha(b) || tfsmIsDigit(b) || b == TFSM_UNDERSCORE
}

func tfsmSkipSpaces(bytes: Array<UInt8>, from: Int64): Int64 {
    var i = from
    while (i < bytes.size && tfsmIsSpace(bytes[i])) {
        i += 1
    }
    return i
}

func tfsmTokenEnd(bytes: Array<UInt8>, from: Int64): Int64 {
    var i = from
    while (i < bytes.size && !tfsmIsSpace(bytes[i])) {
        i += 1
    }
    return i
}

func tfsmSlice(bytes: Array<UInt8>, from: Int64, to: Int64): String {
    if (to <= from) {
        return ""
    }
    return String.fromUtf8(bytes[from..to])
}

func tfsmIsComment(line: String): Bool {
    let bytes = line.toArray()
    var i = 0
    while (i < bytes.size && tfsmIsSpace(bytes[i])) {
        i += 1
    }
    if (i >= bytes.size) {
        return false
    }
    return bytes[i] == TFSM_HASH
}

func tfsmStartsIndented(line: String): Bool {
    let bytes = line.toArray()
    if (bytes.size == 0) {
        return false
    }
    return tfsmIsSpace(bytes[0])
}

func tfsmIsBlank(line: String): Bool {
    return line.trimAscii().isEmpty()
}

func tfsmValidName(name: String): Bool {
    let bytes = name.toArray()
    if (bytes.size == 0 || bytes.size > TEXTFSM_MAX_NAME_LEN) {
        return false
    }
    if (!tfsmIsAlpha(bytes[0]) && bytes[0] != TFSM_UNDERSCORE) {
        return false
    }
    var i = 1
    while (i < bytes.size) {
        if (!tfsmIsWord(bytes[i])) {
            return false
        }
        i += 1
    }
    return true
}

func tfsmFlag(map: HashMap<String, Bool>, key: String): Bool {
    match (map.get(key)) {
        case Some(v) => return v
        case None => return false
    }
}

func tfsmText(map: HashMap<String, String>, key: String): String {
    match (map.get(key)) {
        case Some(v) => return v
        case None => return ""
    }
}

public func splitOutputLines(text: String): Array<String> {
    if (text.isEmpty()) {
        return Array<String>()
    }
    let parts = normalizeLineEndings(text).split("\n")
    let out = ArrayList<String>()
    var i = 0
    while (i < parts.size) {
        if (i == parts.size - 1 && parts[i].isEmpty()) {
            break
        }
        out.add(parts[i])
        i += 1
    }
    return out.toArray()
}

public class TextFsmValue <: ToString {
    public let name: String
    public let regex: String
    public let template: String
    public let options: Array<String>
    public let required: Bool
    public let isList: Bool
    public let filldown: Bool
    public let fillup: Bool
    public let isKey: Bool

    init(name: String, regex: String, template: String, options: Array<String>, required: Bool,
         isList: Bool, filldown: Bool, fillup: Bool, isKey: Bool) {
        this.name = name
        this.regex = regex
        this.template = template
        this.options = options
        this.required = required
        this.isList = isList
        this.filldown = filldown
        this.fillup = fillup
        this.isKey = isKey
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("Value ")
        if (options.size > 0) {
            var i = 0
            while (i < options.size) {
                if (i > 0) {
                    sb.append(",")
                }
                sb.append(options[i])
                i += 1
            }
            sb.append(" ")
        }
        sb.append(name)
        sb.append(" ")
        sb.append(regex)
        return sb.toString()
    }
}

public class TextFsmRow <: ToString {
    private let fieldOrder: Array<String>
    private let listFields: HashMap<String, Bool>
    private let scalarValues: HashMap<String, String>
    private let listValues: HashMap<String, Array<String>>

    init(fieldOrder: Array<String>, listFields: HashMap<String, Bool>,
         scalarValues: HashMap<String, String>, listValues: HashMap<String, Array<String>>) {
        this.fieldOrder = fieldOrder
        this.listFields = listFields
        this.scalarValues = scalarValues
        this.listValues = listValues
    }

    public prop names: Array<String> {
        get() {
            fieldOrder
        }
    }

    public func has(name: String): Bool {
        return scalarValues.contains(name) || listValues.contains(name)
    }

    public func isListValue(name: String): Bool {
        return tfsmFlag(listFields, name)
    }

    public func get(name: String): String {
        return tfsmText(scalarValues, name)
    }

    public func getList(name: String): Array<String> {
        match (listValues.get(name)) {
            case Some(v) => return v
            case None => return Array<String>()
        }
    }

    func setScalar(name: String, value: String): Unit {
        scalarValues[name] = value
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("TextFsmRow(")
        var i = 0
        while (i < fieldOrder.size) {
            if (i > 0) {
                sb.append(", ")
            }
            let name = fieldOrder[i]
            sb.append(name)
            sb.append("=")
            if (isListValue(name)) {
                sb.append("[")
                let items = getList(name)
                var j = 0
                while (j < items.size) {
                    if (j > 0) {
                        sb.append(", ")
                    }
                    sb.append("'")
                    sb.append(items[j])
                    sb.append("'")
                    j += 1
                }
                sb.append("]")
            } else {
                sb.append("'")
                sb.append(get(name))
                sb.append("'")
            }
            i += 1
        }
        sb.append(")")
        return sb.toString()
    }
}

class TextFsmRule {
    let source: String
    let lineNumber: Int64
    let pattern: String
    let regex: Regex
    let groupNames: Array<String>
    let groupIndexes: Array<Int64>
    let lineOp: String
    let recordOp: String
    let newState: String

    init(source: String, lineNumber: Int64, pattern: String, regex: Regex,
         groupNames: Array<String>, groupIndexes: Array<Int64>, lineOp: String, recordOp: String,
         newState: String) {
        this.source = source
        this.lineNumber = lineNumber
        this.pattern = pattern
        this.regex = regex
        this.groupNames = groupNames
        this.groupIndexes = groupIndexes
        this.lineOp = lineOp
        this.recordOp = recordOp
        this.newState = newState
    }
}

func tfsmIsLineOp(token: String): Bool {
    return token == "Next" || token == "Continue" || token == "Error"
}

func tfsmIsRecordOp(token: String): Bool {
    return token == "Record" || token == "NoRecord" || token == "Clear" || token == "Clearall"
}

func tfsmSubstitute(text: String, varMap: HashMap<String, String>, lineNumber: Int64): String {
    let bytes = text.toArray()
    let out = ArrayList<UInt8>()
    var i = 0
    while (i < bytes.size) {
        let b = bytes[i]
        if (b != TFSM_DOLLAR) {
            out.add(b)
            i += 1
            continue
        }
        if (i + 1 >= bytes.size) {
            out.add(b)
            i += 1
            continue
        }
        let next = bytes[i + 1]
        if (next == TFSM_DOLLAR) {
            out.add(TFSM_DOLLAR)
            i += 2
            continue
        }
        if (next == TFSM_OPEN_BRACE) {
            var j = i + 2
            while (j < bytes.size && bytes[j] != TFSM_CLOSE_BRACE) {
                j += 1
            }
            if (j >= bytes.size) {
                throw TemplateException(
                    "unterminated value reference on template line ${lineNumber}: ${text}")
            }
            let name = tfsmSlice(bytes, i + 2, j)
            tfsmAppendVar(out, name, varMap, lineNumber, text)
            i = j + 1
            continue
        }
        if (tfsmIsAlpha(next) || next == TFSM_UNDERSCORE) {
            var j = i + 1
            while (j < bytes.size && tfsmIsWord(bytes[j])) {
                j += 1
            }
            let name = tfsmSlice(bytes, i + 1, j)
            tfsmAppendVar(out, name, varMap, lineNumber, text)
            i = j
            continue
        }
        out.add(b)
        i += 1
    }
    return String.fromUtf8(out.toArray())
}

func tfsmAppendVar(out: ArrayList<UInt8>, name: String, varMap: HashMap<String, String>,
                   lineNumber: Int64, source: String): Unit {
    match (varMap.get(name)) {
        case Some(replacement) =>
            for (b in replacement.toArray()) {
                out.add(b)
            }
        case None =>
            throw TemplateException(
                "unknown value '${name}' referenced on template line ${lineNumber}: ${source}")
    }
}

func tfsmCompileRegex(pattern: String, lineNumber: Int64): Regex {
    try {
        return Regex("\\A(?:${pattern})")
    } catch (e: Exception) {
        throw TemplateException(
            "invalid regular expression on template line ${lineNumber}: ${pattern}")
    }
}

func tfsmParseValue(line: String, lineNumber: Int64): TextFsmValue {
    let bytes = line.toArray()
    var p = tfsmSkipSpaces(bytes, 6)
    let firstEnd = tfsmTokenEnd(bytes, p)
    if (firstEnd == p) {
        throw TemplateException("malformed Value declaration on template line ${lineNumber}")
    }
    let firstToken = tfsmSlice(bytes, p, firstEnd)
    var q = tfsmSkipSpaces(bytes, firstEnd)
    if (q >= bytes.size) {
        throw TemplateException(
            "Value declaration needs a name and a regex on template line ${lineNumber}")
    }

    var optionText = ""
    var name = ""
    var regexStart = 0
    if (bytes[q] == TFSM_OPEN_PAREN) {
        name = firstToken
        regexStart = q
    } else {
        optionText = firstToken
        let secondEnd = tfsmTokenEnd(bytes, q)
        name = tfsmSlice(bytes, q, secondEnd)
        let r = tfsmSkipSpaces(bytes, secondEnd)
        if (r >= bytes.size) {
            throw TemplateException(
                "Value declaration needs a regex on template line ${lineNumber}")
        }
        regexStart = r
    }

    if (!tfsmValidName(name)) {
        throw TemplateException("invalid Value name '${name}' on template line ${lineNumber}")
    }

    let regex = tfsmSlice(bytes, regexStart, bytes.size).trimAsciiEnd()
    let regexBytes = regex.toArray()
    if (regexBytes.size < 3 || regexBytes[0] != TFSM_OPEN_PAREN ||
        regexBytes[regexBytes.size - 1] != TFSM_CLOSE_PAREN ||
        regexBytes[regexBytes.size - 2] == TFSM_BACKSLASH) {
        throw TemplateException(
            "Value '${name}' regex must be wrapped in a '()' pair on template line ${lineNumber}")
    }

    var required = false
    var isList = false
    var filldown = false
    var fillup = false
    var isKey = false
    let options = ArrayList<String>()
    if (!optionText.isEmpty()) {
        for (raw in optionText.split(",")) {
            let option = raw.trimAscii()
            if (option.isEmpty()) {
                continue
            }
            if (options.contains(option)) {
                throw TemplateException(
                    "duplicate option '${option}' on template line ${lineNumber}")
            }
            if (option == "Required") {
                required = true
            } else if (option == "List") {
                isList = true
            } else if (option == "Filldown") {
                filldown = true
            } else if (option == "Fillup") {
                fillup = true
            } else if (option == "Key") {
                isKey = true
            } else {
                throw TemplateException(
                    "unknown Value option '${option}' on template line ${lineNumber}")
            }
            options.add(option)
        }
    }

    if (filldown && fillup) {
        throw TemplateException(
            "Value '${name}' cannot be both Filldown and Fillup on template line ${lineNumber}")
    }

    let body = tfsmSlice(regexBytes, 1, regexBytes.size)
    let template = "(?<${name}>${body}"
    return TextFsmValue(name, regex, template, options.toArray(), required, isList, filldown,
                        fillup, isKey)
}

func tfsmParseRule(raw: String, lineNumber: Int64, varMap: HashMap<String, String>,
                   declared: HashMap<String, Bool>): TextFsmRule {
    let line = raw.trimAscii()
    if (line.isEmpty()) {
        throw TemplateException("empty rule on template line ${lineNumber}")
    }
    let bytes = line.toArray()

    var arrow = -1
    var k = bytes.size - 2
    while (k >= 1) {
        if (bytes[k] == TFSM_DASH && bytes[k + 1] == TFSM_GT && tfsmIsSpace(bytes[k - 1])) {
            arrow = k
            break
        }
        k -= 1
    }

    var matchText = line
    var actionText = ""
    if (arrow >= 0) {
        matchText = tfsmSlice(bytes, 0, arrow - 1).trimAsciiEnd()
        actionText = tfsmSlice(bytes, arrow + 2, bytes.size).trimAscii()
    }

    var lineOp = ""
    var recordOp = ""
    var newState = ""

    if (arrow >= 0 && !actionText.isEmpty()) {
        let tokens = ArrayList<String>()
        for (t in actionText.split(" ")) {
            let token = t.trimAscii()
            if (!token.isEmpty()) {
                tokens.add(token)
            }
        }
        var consumedOp = false
        let head = tokens[0]
        let dot = head.indexOf(".")
        match (dot) {
            case Some(idx) =>
                let left = head[0..idx]
                let right = head[(idx + 1)..head.size]
                if (!tfsmIsLineOp(left) || !tfsmIsRecordOp(right)) {
                    throw TemplateException(
                        "badly formatted action '${actionText}' on template line ${lineNumber}")
                }
                lineOp = left
                recordOp = right
                consumedOp = true
            case None =>
                if (tfsmIsLineOp(head)) {
                    lineOp = head
                    consumedOp = true
                } else if (tfsmIsRecordOp(head)) {
                    recordOp = head
                    consumedOp = true
                }
        }

        if (!consumedOp) {
            if (tokens.size != 1) {
                throw TemplateException(
                    "badly formatted action '${actionText}' on template line ${lineNumber}")
            }
            newState = head
        } else if (tokens.size > 1) {
            let sb = StringBuilder()
            var i = 1
            while (i < tokens.size) {
                if (i > 1) {
                    sb.append(" ")
                }
                sb.append(tokens[i])
                i += 1
            }
            newState = sb.toString()
        }

        if (lineOp == "Continue" && !newState.isEmpty()) {
            throw TemplateException(
                "Continue cannot specify a new state on template line ${lineNumber}")
        }
        if (lineOp != "Error" && !newState.isEmpty() && !tfsmValidName(newState)) {
            throw TemplateException(
                "invalid target state '${newState}' on template line ${lineNumber}")
        }
    }

    let pattern = tfsmSubstitute(matchText, varMap, lineNumber)
    let regex = tfsmCompileRegex(pattern, lineNumber)

    let names = ArrayList<String>()
    let indexes = ArrayList<Int64>()
    for ((groupName, groupIndex) in regex.getNamedGroups()) {
        if (tfsmFlag(declared, groupName)) {
            names.add(groupName)
            indexes.add(groupIndex)
        }
    }

    return TextFsmRule(line, lineNumber, pattern, regex, names.toArray(), indexes.toArray(),
                       lineOp, recordOp, newState)
}

func tfsmGroupText(md: MatchData, index: Int64): Option<String> {
    if (index > md.groupCount()) {
        return None
    }
    let pos = md.matchPosition(index)
    if (pos.start < 0) {
        return None
    }
    return Some(md.matchString(index))
}

public class TextFsmTemplate {
    let values: Array<TextFsmValue>
    let valueByName: HashMap<String, TextFsmValue>
    let states: HashMap<String, Array<TextFsmRule>>
    let stateOrder: Array<String>

    init(values: Array<TextFsmValue>, valueByName: HashMap<String, TextFsmValue>,
         states: HashMap<String, Array<TextFsmRule>>, stateOrder: Array<String>) {
        this.values = values
        this.valueByName = valueByName
        this.states = states
        this.stateOrder = stateOrder
    }

    public prop valueNames: Array<String> {
        get() {
            let out = Array<String>(values.size, repeat: "")
            var i = 0
            while (i < values.size) {
                out[i] = values[i].name
                i += 1
            }
            return out
        }
    }

    public prop stateNames: Array<String> {
        get() {
            stateOrder
        }
    }

    public prop valueDefinitions: Array<TextFsmValue> {
        get() {
            values
        }
    }

    public static func compile(text: String): TextFsmTemplate {
        if (text.trimAscii().isEmpty()) {
            throw TemplateException("empty TextFSM template")
        }
        let lines = normalizeLineEndings(text).split("\n")

        let values = ArrayList<TextFsmValue>()
        let valueByName = HashMap<String, TextFsmValue>()
        let declared = HashMap<String, Bool>()
        let varMap = HashMap<String, String>()

        var i = 0
        while (i < lines.size) {
            let line = lines[i].trimAsciiEnd()
            if (tfsmIsBlank(line)) {
                i += 1
                if (values.size > 0) {
                    break
                }
                continue
            }
            if (tfsmIsComment(line)) {
                i += 1
                continue
            }
            if (line.startsWith("Value ")) {
                let value = tfsmParseValue(line, i + 1)
                if (valueByName.contains(value.name)) {
                    throw TemplateException(
                        "duplicate Value '${value.name}' on template line ${i + 1}")
                }
                values.add(value)
                valueByName[value.name] = value
                declared[value.name] = true
                varMap[value.name] = value.template
                i += 1
                continue
            }
            if (values.size == 0) {
                throw TemplateException("no Value definitions found in TextFSM template")
            }
            break
        }

        let states = HashMap<String, Array<TextFsmRule>>()
        let stateOrder = ArrayList<String>()
        let looseRules = ArrayList<TextFsmRule>()

        while (i < lines.size) {
            let line = lines[i].trimAsciiEnd()
            if (tfsmIsBlank(line) || tfsmIsComment(line)) {
                i += 1
                continue
            }
            if (tfsmStartsIndented(line)) {
                looseRules.add(tfsmParseRule(line, i + 1, varMap, declared))
                i += 1
                continue
            }
            if (!tfsmValidName(line) || tfsmIsLineOp(line) || tfsmIsRecordOp(line)) {
                throw TemplateException("invalid state name '${line}' on template line ${i + 1}")
            }
            if (states.contains(line)) {
                throw TemplateException("duplicate state '${line}' on template line ${i + 1}")
            }
            let stateName = line
            let rules = ArrayList<TextFsmRule>()
            i += 1
            while (i < lines.size) {
                let ruleLine = lines[i].trimAsciiEnd()
                if (tfsmIsBlank(ruleLine)) {
                    i += 1
                    break
                }
                if (tfsmIsComment(ruleLine)) {
                    i += 1
                    continue
                }
                if (!tfsmStartsIndented(ruleLine)) {
                    throw TemplateException(
                        "rule must be indented on template line ${i + 1}: ${ruleLine}")
                }
                rules.add(tfsmParseRule(ruleLine, i + 1, varMap, declared))
                i += 1
            }
            states[stateName] = rules.toArray()
            stateOrder.add(stateName)
        }

        if (looseRules.size > 0) {
            if (states.contains("Start")) {
                throw TemplateException(
                    "rules found outside any state alongside an explicit Start state")
            }
            states["Start"] = looseRules.toArray()
            stateOrder.add("Start")
        }

        if (!states.contains("Start")) {
            throw TemplateException("TextFSM template has no 'Start' state")
        }

        if (states.contains("End")) {
            match (states.get("End")) {
                case Some(rules) =>
                    if (rules.size > 0) {
                        throw TemplateException("the 'End' state must be empty")
                    }
                case None => ()
            }
            states.remove("End")
        }
        if (states.contains("EOF")) {
            match (states.get("EOF")) {
                case Some(rules) =>
                    if (rules.size > 0) {
                        throw TemplateException("the 'EOF' state must be empty")
                    }
                case None => ()
            }
        }

        let ordered = ArrayList<String>()
        for (name in stateOrder) {
            if (states.contains(name)) {
                ordered.add(name)
            }
        }

        for ((stateName, rules) in states) {
            for (rule in rules) {
                if (rule.lineOp == "Error") {
                    continue
                }
                if (rule.newState.isEmpty() || rule.newState == "End" || rule.newState == "EOF") {
                    continue
                }
                if (!states.contains(rule.newState)) {
                    throw TemplateException(
                        "state '${rule.newState}' referenced from state '${stateName}' does not exist")
                }
            }
        }

        return TextFsmTemplate(values.toArray(), valueByName, states, ordered.toArray())
    }

    public func parse(output: String): Array<TextFsmRow> {
        return TextFsmMachine(this).run(output)
    }
}

class TextFsmMachine {
    private let template: TextFsmTemplate
    private let scalarSet = HashMap<String, Bool>()
    private let scalarText = HashMap<String, String>()
    private let filldownSet = HashMap<String, Bool>()
    private let filldownText = HashMap<String, String>()
    private let lists = HashMap<String, ArrayList<String>>()
    private let results = ArrayList<TextFsmRow>()
    private var stateName = "Start"
    private var stateRules = Array<TextFsmRule>()

    init(template: TextFsmTemplate) {
        this.template = template
        for (value in template.values) {
            lists[value.name] = ArrayList<String>()
        }
    }

    func run(output: String): Array<TextFsmRow> {
        clearAll()
        stateName = "Start"
        stateRules = rulesFor("Start")
        for (line in splitOutputLines(output)) {
            checkLine(line)
            if (stateName == "End" || stateName == "EOF") {
                break
            }
        }
        if (stateName != "End" && !template.states.contains("EOF")) {
            appendRecord()
        }
        return results.toArray()
    }

    private func rulesFor(name: String): Array<TextFsmRule> {
        match (template.states.get(name)) {
            case Some(rules) => return rules
            case None => throw TemplateException("state '${name}' does not exist")
        }
    }

    private func listFor(name: String): ArrayList<String> {
        match (lists.get(name)) {
            case Some(items) => return items
            case None =>
                let created = ArrayList<String>()
                lists[name] = created
                return created
        }
    }

    private func checkLine(line: String): Unit {
        for (rule in stateRules) {
            let found = rule.regex.find(line, group: true)
            if (let Some(md) <- found) {
                var i = 0
                while (i < rule.groupNames.size) {
                    assignVar(rule.groupNames[i], tfsmGroupText(md, rule.groupIndexes[i]))
                    i += 1
                }
                if (operations(rule, line)) {
                    if (!rule.newState.isEmpty()) {
                        stateName = rule.newState
                        if (rule.newState != "End" && rule.newState != "EOF") {
                            stateRules = rulesFor(rule.newState)
                        }
                    }
                    break
                }
            }
        }
    }

    private func assignVar(name: String, text: Option<String>): Unit {
        let value = match (template.valueByName.get(name)) {
            case Some(v) => v
            case None => return
        }
        if (value.isList) {
            if (let Some(t) <- text) {
                listFor(name).add(t)
            }
        } else {
            match (text) {
                case Some(t) =>
                    scalarSet[name] = true
                    scalarText[name] = t
                case None =>
                    scalarSet[name] = false
                    scalarText[name] = ""
            }
        }
        if (value.filldown) {
            match (text) {
                case Some(t) =>
                    filldownSet[name] = true
                    filldownText[name] = t
                case None =>
                    filldownSet[name] = false
                    filldownText[name] = ""
            }
        }
        if (value.fillup && !value.isList) {
            if (let Some(t) <- text) {
                if (!t.isEmpty()) {
                    fillUp(name, t)
                }
            }
        }
    }

    private func fillUp(name: String, text: String): Unit {
        var i = results.size - 1
        while (i >= 0) {
            let row = results[i]
            if (!row.get(name).isEmpty()) {
                break
            }
            row.setScalar(name, text)
            i -= 1
        }
    }

    private func operations(rule: TextFsmRule, line: String): Bool {
        if (rule.recordOp == "Record") {
            appendRecord()
        } else if (rule.recordOp == "Clear") {
            clearRecord()
        } else if (rule.recordOp == "Clearall") {
            clearAll()
        }

        if (rule.lineOp == "Error") {
            if (!rule.newState.isEmpty()) {
                throw ParseException(
                    "TextFSM Error action: ${stripQuotes(rule.newState)} (template line ${rule.lineNumber}, input line: ${line})")
            }
            throw ParseException(
                "TextFSM Error action raised (template line ${rule.lineNumber}, input line: ${line})")
        }
        if (rule.lineOp == "Continue") {
            return false
        }
        return true
    }

    private func appendRecord(): Unit {
        if (template.values.size == 0) {
            return
        }
        for (value in template.values) {
            if (!value.required) {
                continue
            }
            if (value.isList) {
                if (listFor(value.name).size == 0) {
                    clearRecord()
                    return
                }
            } else if (!tfsmFlag(scalarSet, value.name) ||
                       tfsmText(scalarText, value.name).isEmpty()) {
                clearRecord()
                return
            }
        }

        let order = Array<String>(template.values.size, repeat: "")
        let listFields = HashMap<String, Bool>()
        let scalars = HashMap<String, String>()
        let listValues = HashMap<String, Array<String>>()
        var populated = false
        var i = 0
        while (i < template.values.size) {
            let value = template.values[i]
            order[i] = value.name
            if (value.isList) {
                let items = listFor(value.name).toArray()
                listFields[value.name] = true
                listValues[value.name] = items
                if (items.size > 0) {
                    populated = true
                }
            } else {
                if (tfsmFlag(scalarSet, value.name)) {
                    scalars[value.name] = tfsmText(scalarText, value.name)
                    populated = true
                } else {
                    scalars[value.name] = ""
                }
            }
            i += 1
        }

        if (!populated) {
            return
        }

        results.add(TextFsmRow(order, listFields, scalars, listValues))
        clearRecord()
    }

    private func clearRecord(): Unit {
        for (value in template.values) {
            if (value.isList && !value.filldown) {
                listFor(value.name).clear()
            }
            if (value.filldown) {
                scalarSet[value.name] = tfsmFlag(filldownSet, value.name)
                scalarText[value.name] = tfsmText(filldownText, value.name)
            } else {
                scalarSet[value.name] = false
                scalarText[value.name] = ""
            }
        }
    }

    private func clearAll(): Unit {
        for (value in template.values) {
            scalarSet[value.name] = false
            scalarText[value.name] = ""
            filldownSet[value.name] = false
            filldownText[value.name] = ""
            listFor(value.name).clear()
        }
    }
}

func stripQuotes(text: String): String {
    let t = text.trimAscii()
    if (t.size >= 2 && t.startsWith("\"") && t.endsWith("\"")) {
        return t[1..(t.size - 1)]
    }
    return t
}

public func parseTextFsm(template: String, output: String): Array<TextFsmRow> {
    return TextFsmTemplate.compile(template).parse(output)
}
