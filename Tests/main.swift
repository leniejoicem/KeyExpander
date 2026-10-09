// Logic tests for KeyExpander (run with Tests/run-tests.sh). Compiled together with the app's real source files by
// Tests/run-tests.sh, against a throwaway home folder so the real snippet library is never touched.
// Nothing here posts keyboard events or touches the system clipboard.

import Cocoa
import SQLite

// ---------- tiny test runner ----------
var passed = 0, failed = 0
func expect(_ cond: Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if cond { passed += 1 } else { failed += 1; print("FAIL:", name, detail()) }
}
func section(_ s: String) { print("— \(s)") }

// Safety: never touch the real snippet library.
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.path
let testHome = ProcessInfo.processInfo.environment["KE_TEST_HOME"] ?? "<unset>"
guard appSupport.hasPrefix(testHome) || appSupport.hasPrefix("/private" + testHome) else { print("ABORT: Application Support resolves to \(appSupport)"); exit(2) }
print("db dir:", appSupport)

// ---------- 1. trigger matching ----------
section("trigger matching")
let m = TextEngine.triggerMatches
let matchCases: [(String, String, Bool, Bool, String)] = [
    (";sig", "hello ;sig", false, true, "symbol trigger after space"),
    (";sig", "word;sig", false, true, "symbol trigger glued to a word still fires"),
    (";sig", ";SIG", false, true, "case-insensitive"),
    (";sig", ";SIG", true, false, "case-sensitive rejects other case"),
    (";sig", ";sig", true, true, "case-sensitive exact"),
    ("hi", "chi", false, false, "letter trigger inside a word"),
    ("hi", "hii", false, false, "suffix mismatch"),
    ("hi", "say hi", false, true, "letter trigger after space"),
    ("hi", "hi", false, true, "letter trigger at buffer start"),
    ("hi", "(hi", false, true, "letter trigger after punctuation"),
    ("hi", "line\nhi", false, true, "letter trigger after newline"),
    ("hi", "2hi", false, false, "letter trigger after digit"),
    ("2fa", "x 2fa", false, true, "digit trigger after space"),
    ("2fa", "a2fa", false, false, "digit trigger inside a word"),
    ("ytd", "YTD", false, true, "user-style trigger, other case"),
    (";sig", "sig", false, false, "buffer shorter than trigger"),
    ("", "anything", false, false, "empty trigger never fires"),
    ("üb", "x üb", false, true, "non-ASCII letter trigger"),
    ("üb", "xüb", false, false, "non-ASCII letter trigger inside a word"),
    ("👋", "hey 👋", false, true, "emoji trigger"),
    ("Über", "ÜBER", false, true, "case-insensitive non-ASCII"),
]
for (t, b, cs, want, name) in matchCases {
    let got = m(t, b, cs)
    expect(got == want, name, "trigger=\(t.debugDescription) buffer=\(b.debugDescription) got \(got)")
}

// ---------- 2. key classification ----------
section("key classification")
typealias A = GlobalKeyListener.KeyAction
let act = GlobalKeyListener.action
let keyCases: [(Int64, CGEventFlags, String?, Bool, A, String)] = [
    (0, [], "a", false, .character("a"), "plain letter"),
    (0, .maskShift, "A", false, .character("A"), "shifted letter"),
    (0, .maskAlphaShift, "A", false, .character("A"), "caps lock letter"),
    (41, [], ";", false, .character(";"), "semicolon"),
    (49, [], " ", false, .delimiter(isNewline: false), "space"),
    (36, [], "\r", false, .delimiter(isNewline: true), "return"),
    (76, .maskNumericPad, "\u{3}", false, .delimiter(isNewline: true), "keypad enter"),
    (51, [], "\u{7f}", false, .backspace, "backspace"),
    (51, .maskAlternate, "\u{7f}", false, .resetBuffer, "option+backspace"),
    (51, .maskCommand, "\u{7f}", false, .resetBuffer, "cmd+backspace"),
    (9, .maskCommand, "v", false, .resetBuffer, "cmd+v"),
    (0, .maskControl, "\u{1}", false, .resetBuffer, "ctrl+a"),
    (123, [.maskNumericPad, .maskSecondaryFn], "\u{F702}", false, .resetBuffer, "left arrow"),
    (126, [.maskNumericPad, .maskSecondaryFn], "\u{F700}", false, .resetBuffer, "up arrow"),
    (115, .maskSecondaryFn, "\u{F729}", false, .resetBuffer, "home"),
    (117, .maskSecondaryFn, "\u{F728}", false, .resetBuffer, "forward delete"),
    (48, [], "\t", false, .resetBuffer, "tab"),
    (53, [], "\u{1b}", false, .resetBuffer, "escape"),
    (122, .maskSecondaryFn, "\u{F704}", false, .resetBuffer, "F1 (private-use char)"),
    (14, .maskAlternate, nil, false, .ignore, "dead key (option+e) produces nothing"),
    (49, [], " ", true, .ignore, "our own synthetic space"),
    (51, [], "\u{7f}", true, .ignore, "our own synthetic backspace"),
    (9, .maskCommand, "v", true, .ignore, "our own synthetic cmd+v"),
]
for (code, flags, chars, synth, want, name) in keyCases {
    let got = act(code, flags, chars, synth)
    expect(got == want, name, "got \(got), want \(want)")
}

// ---------- 3. expansion text ----------
section("expansion text")
expect(TextEngine.sanitizedExpansionText("a\n    b\n\tc") == "a\n    b\n\tc", "indentation kept")
expect(TextEngine.sanitizedExpansionText("a\r\nb\rc") == "a\nb\nc", "line endings normalized")
expect(TextEngine.sanitizedExpansionText("  lead") == "  lead", "leading spaces kept")

// ---------- 4. pasteboard snapshot / restore (private pasteboard, not the user's clipboard) ----------
section("pasteboard snapshot")
let pb = NSPasteboard(name: NSPasteboard.Name("com.keyexpander.harness.\(getpid())"))
defer { pb.releaseGlobally() }
func borrowAndRestore() {
    let snap = PasteboardSnapshot.capture(from: pb)
    pb.clearContents(); pb.setString("SNIPPET", forType: .string)
    snap.restore(to: pb)
}
// rich text + image on one item
pb.clearContents()
let rich = NSPasteboardItem()
let rtf = "{\\rtf1 {\\b bold}}".data(using: .utf8)!
let tiff = NSImage(size: NSSize(width: 2, height: 2), flipped: false) { r in NSColor.red.setFill(); r.fill(); return true }.tiffRepresentation!
rich.setString("bold", forType: .string); rich.setData(rtf, forType: .rtf); rich.setData(tiff, forType: .tiff)
pb.writeObjects([rich])
borrowAndRestore()
let ri = pb.pasteboardItems?.first
expect(ri?.string(forType: .string) == "bold", "rich: string restored")
expect(ri?.data(forType: .rtf) == rtf, "rich: RTF restored byte-for-byte")
expect(ri?.data(forType: .tiff) == tiff, "rich: image restored byte-for-byte")
// image only
pb.clearContents(); let img = NSPasteboardItem(); img.setData(tiff, forType: .tiff); pb.writeObjects([img])
borrowAndRestore()
expect(pb.data(forType: .tiff) == tiff, "image-only clipboard restored")
expect(pb.string(forType: .string) == nil, "image-only: no stray string added")
// two files copied in Finder
pb.clearContents()
let urls = [URL(fileURLWithPath: "/etc/hosts"), URL(fileURLWithPath: "/etc/shells")]
pb.writeObjects(urls as [NSURL])
borrowAndRestore()
let back = pb.readObjects(forClasses: [NSURL.self]) as? [URL]
expect(back == urls, "two copied files restored", "\(String(describing: back))")
// plain string
pb.clearContents(); pb.setString("plain", forType: .string)
borrowAndRestore()
expect(pb.string(forType: .string) == "plain", "plain text restored")
// empty clipboard stays empty
pb.clearContents()
borrowAndRestore()
expect((pb.pasteboardItems ?? []).isEmpty, "empty clipboard stays empty")
// transient marker types are well-formed
expect(NSPasteboard.PasteboardType.transient.rawValue == "org.nspasteboard.TransientType", "transient type id")

// ---------- 4b. clipboard lending across expansions ----------
section("clipboard lending")
let lender = ClipboardLender(pasteboard: pb)
func clip() -> String? { pb.string(forType: .string) }
// one expansion
pb.clearContents(); pb.setString("user copy", forType: .string)
let l1 = lender.lend("SNIP")
expect(clip() == "SNIP", "snippet is on the clipboard during the paste")
lender.giveBack(l1)
expect(clip() == "user copy", "single expansion: clipboard restored")
// second expansion before the first restore fires
pb.clearContents(); pb.setString("user copy", forType: .string)
let a = lender.lend("SNIP"), b = lender.lend("SNIP")
lender.giveBack(a)
expect(clip() == "SNIP", "older loan doesn't restore while a newer paste is running")
lender.giveBack(b)
expect(clip() == "user copy", "overlapping expansions: user's clipboard restored, not the snippet", String(describing: clip()))
// another app rewrites the same text (changeCount bumps, content doesn't)
pb.clearContents(); pb.setString("user copy", forType: .string)
let c = lender.lend("SNIP")
pb.clearContents(); pb.setString("SNIP", forType: .string)
lender.giveBack(c)
expect(clip() == "user copy", "pasteboard rewritten with the same snippet: still restored", String(describing: clip()))
// user copies something new before the restore
pb.clearContents(); pb.setString("user copy", forType: .string)
let d = lender.lend("SNIP")
pb.clearContents(); pb.setString("fresh copy", forType: .string)
lender.giveBack(d)
expect(clip() == "fresh copy", "a copy made during the paste is kept")
// user copies, then expands again before the first restore
pb.clearContents(); pb.setString("user copy", forType: .string)
let e = lender.lend("SNIP")
pb.clearContents(); pb.setString("fresh copy", forType: .string)
let f = lender.lend("SNIP")
lender.giveBack(e); lender.giveBack(f)
expect(clip() == "fresh copy", "copy between two expansions is what comes back", String(describing: clip()))

// ---------- 5. database: migration + orphan cleanup (pre-seeded legacy file) ----------
section("database")
let dbm = DatabaseManager.shared
expect(dbm.isPersistent, "on-disk database opened")
let raw = dbm.db
let cols = try raw.tableColumns("snippets")
for c in ["title", "category_id", "case_sensitive", "is_enabled", "usage_count", "updated_at"] {
    expect(cols.contains(c), "migration added column \(c)")
}
let orphanCat = try raw.scalar("SELECT quote(category_id) FROM snippets WHERE trigger = 'legacy'") as? String
expect(orphanCat == "NULL", "orphaned legacy snippet moved to Uncategorized", "got \(String(describing: orphanCat))")
expect(try raw.scalar("SELECT count(*) FROM categories") as? Int64 == 4, "default categories seeded")

let catRepo = CategoryRepository(), snipRepo = SnippetRepository()
try catRepo.add(name: "Temp")
let temp = try catRepo.fetchAll().first { $0.name == "Temp" }!
let keep = try catRepo.fetchAll().first { $0.name != "Temp" }!
try snipRepo.add(SnippetDraft(title: "a", trigger: ";a", content: "A", categoryId: temp.id))
try snipRepo.add(SnippetDraft(title: "b", trigger: ";b", content: "B", categoryId: temp.id))
try snipRepo.add(SnippetDraft(title: "c", trigger: ";c", content: "C", categoryId: keep.id))
try catRepo.delete(id: temp.id)
let after = try snipRepo.fetchAll()
expect(try catRepo.fetchAll().contains { $0.id == temp.id } == false, "category deleted")
expect(after.filter { [";a", ";b"].contains($0.trigger) }.allSatisfy { $0.categoryId == nil }, "its snippets moved to Uncategorized")
expect(after.first { $0.trigger == ";c" }?.categoryId == keep.id, "other categories' snippets untouched")

do {
    try snipRepo.add(SnippetDraft(title: "dup", trigger: ";a", content: "X"))
    expect(false, "exact duplicate trigger rejected by DB")
} catch {
    let msg = String(describing: error).lowercased()
    expect(msg.contains("unique constraint failed: snippets.trigger"), "duplicate error is recognisable for the UI", msg)
}

let idA = after.first { $0.trigger == ";a" }!.id
try snipRepo.incrementUsage(id: idA)
expect(try snipRepo.fetchAll().first { $0.id == idA }?.usageCount == 1, "usage count increments")

// ---------- 6. view model: case-insensitive duplicate triggers ----------
section("view model")
let vm = await AppViewModel()
await vm.loadAll()
let ok = await vm.addSnippet(SnippetDraft(title: "x", trigger: ";A", content: "X"))
let err = await vm.errorMessage
expect(!ok, "trigger differing only by case is rejected")
expect(err == "That trigger is already in use. Choose a different one.", "friendly duplicate message", String(describing: err))
await MainActor.run { vm.errorMessage = nil }
let ok2 = await vm.addSnippet(SnippetDraft(title: "y", trigger: ";new", content: "Y"))
expect(ok2, "fresh trigger accepted")
let idC = try snipRepo.fetchAll().first { $0.trigger == ";c" }!.id
await vm.updateSnippet(id: idC, draft: SnippetDraft(title: "c", trigger: ";C", content: "C2"))
expect(await vm.errorMessage == nil, "editing a snippet's own trigger case is allowed")

await vm.addCategory(name: "Personal")
// Stale list: the in-memory check can't see it, so the DB constraint must produce the friendly text.
try snipRepo.add(SnippetDraft(title: "z", trigger: ";stale", content: "Z"))
let okStale = await vm.addSnippet(SnippetDraft(title: "z2", trigger: ";stale", content: "Z"))
let staleErr = await vm.errorMessage
expect(!okStale && staleErr == "That trigger is already in use. Choose a different one.", "DB-level duplicate gets friendly message", String(describing: staleErr))
await MainActor.run { vm.errorMessage = nil }
await vm.addCategory(name: "Personal")
let catErr = await vm.errorMessage
expect(catErr == "That category name already exists.", "duplicate category gets a friendly message", String(describing: catErr))
await MainActor.run { vm.errorMessage = nil }

// ---------- 7. engine buffer + consume decisions (expansion itself never runs: no run loop) ----------
section("engine")
let engine = TextEngine.shared
engine.reloadSnippets()
func typeIn(_ s: String) { for ch in s { engine.handleTyped(character: String(ch)) } }
engine.resetBuffer(); typeIn(";a")
expect(engine.handleDelimiter(isNewline: false), "typed trigger is consumed on space")
expect(!engine.handleDelimiter(isNewline: false), "no double expansion while one is in flight")
print("passed \(passed), failed \(failed)")
exit(failed == 0 ? 0 : 1)
