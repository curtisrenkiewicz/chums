import SwiftUI
import AVFoundation

/// Zen: a Tolan-style garden gremlin seen as a bust: a big flat pink head with a crown of leaf fingers that grow out of
/// its own color, a fat yellow torus collar, a narrow body and thick capsule arms. Ported from its HTML playground
/// (life-garden journals/scratch/2026-10-17-zen-chum-v3.html), where every part was matched against frames of Tolan's
/// own pose videos: flat shapes, one gradient each, light only ever subtracts, a thin warmer rim makes the flat head
/// read as a thick disc, and the mouth is one cavity whose layers arrive as it opens (flat red crescent → dark band and
/// tongue → teeth).
///   idle: a slow layered roll, eyes dart and the head follows, a content squint now and then, and sometimes the mouth
///   eases into a big open smile · listening: a curious head tilt, brows up, a small closed smile · thinking: eyes
///   up and to the right, one brow up, a hand to the chin, three dots · working: head down, eyes reading across a line in little
///   hops, brows knit, lips pressed a touch lopsided, a glance up at you at each tool call · subagents: three sprouts orbit its head and it watches them · speaking: syllables (A E O U
///   M) while the voice plays, a hand gesturing with it · done: happy eyes, the D smile with teeth, a wave, leaves fly
///   · needs you: worried brows, a knock on the glass · approval: shrinks up out of the card's way, looks at you
///   hopefully, hands clasped · blocked: cross brows, a grimace, arms crossed, the leaves stiffen and shiver · dizzy:
///   spiral eyes, a wavy mouth, wobbling, arms limp · sleep: head down, leaves droop, a small round mouth breathing, z's
///   tap: a squash and a blink, four quick ones annoy it · stroke: it hums a little tune, eyes shut (keep stroking and
///   the phrases chain into a song) · finger down: its eyes follow it ·
///   crown: turns its head (fast, it gets dizzy) · shake: the leaves fly about
final class ZenStage: Staged {
    static let shared = ZenStage()

    let ownsApproval = false
    let holds: [ChumsState: Double] = [.done: 2.6, .dizzy: 3.4]
    /// The bust fills the bottom of the screen, so words go on top.
    func captionTop(_ r: Rig) -> Bool { true }
    func ownsCaption(_ r: Rig) -> Bool { false }

    private static let W = 198.0, H = 242.0

    // MARK: colors (Bubblegum: Tolan's pink, sampled from their frames)

    typealias RGB = SIMD3<Double>
    private static func hex(_ h: UInt32) -> RGB { RGB(Double((h >> 16) & 0xFF), Double((h >> 8) & 0xFF), Double(h & 0xFF)) }
    private static func col(_ c: RGB, _ a: Double = 1) -> Color { Color(.sRGB, red: c.x / 255, green: c.y / 255, blue: c.z / 255, opacity: a) }
    private static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB { a + (b - a) * t }
    private static func lift(_ c: RGB, _ t: Double) -> RGB { mix(c, RGB(255, 255, 255), t) }
    private static func deepen(_ c: RGB, _ t: Double) -> RGB { c * (1 - t) }
    private static func saturate(_ c: RGB, _ k: Double) -> RGB {
        let m = (c.x + c.y + c.z) / 3
        return RGB(clamp(m + (c.x - m) * k, 0, 255), clamp(m + (c.y - m) * k, 0, 255), clamp(m + (c.z - m) * k, 0, 255))
    }

    private enum P {
        static let front = hex(0xFF8199), tip = hex(0xEE3D78), root = front
        static let collar = hex(0xFFC83A), collarWall = hex(0xF3911A), collarTop = lift(collar, 0.18)
        static let brow = hex(0xC06E8E), browWall = saturate(deepen(brow, 0.2), 1.25)
        static let iris = hex(0x2C3A38), blush = hex(0xFF5C84)
        static let rim = hex(0xE8587A), shade = hex(0xF0607F), tipRim = saturate(deepen(tip, 0.22), 1.2)
        static let wall = deepen(front, 0.22)
        // the mouth, measured from Tolan pose 02: teeth, the shadow they cast, the dark inside, the tongue
        static let lip = RGB(242, 54, 79), teeth = RGB(252, 252, 252), teethShadow = RGB(86, 0, 11)
        static let mouthIn = RGB(125, 24, 42), tongue = RGB(251, 56, 72)
        static let white = RGB(252, 252, 247)
    }

    // MARK: what each state asks of the rig

    // yaw: head turn (+ toward screen right) · pitch: + looks down · lean: closer to you · brow: raise · browA: + inner
    // ends up (worried), − down (cross) · browR: extra raise on the right brow · lid: upper lid closed · spread, droop,
    // stiff: the leaves
    private enum Eyes { case open, happy, closed, spiral }
    private enum Arm { case hang, chin, conduct, gesture, wave, knock, clasp, cross, flop }
    private struct Spec {
        var yaw = 0.0, pitch = 0.0, tilt = 0.0, lean = 1.0, brow = 0.0, browA = 0.0, browR = 0.0
        var lookX = 0.0, lookY = 0.0, lid = 0.0, spread = 1.0, droop = 0.0, stiff = 0.0, blush = 1.0
        var eyes = Eyes.open, mouth = "smile", R = Arm.hang, L = Arm.hang
    }
    private func spec(_ s: ChumsState) -> Spec {
        switch s {
        case .idle: return Spec()
        case .listening: return Spec(pitch: -0.1, tilt: 0.24, lean: 1.05, brow: 0.45, browA: 0.2, lookY: -0.12, spread: 1.15, mouth: "soft")
        case .thinking: return Spec(yaw: 0.3, pitch: -0.25, tilt: -0.1, brow: 0.15, browR: 0.65, lookX: 0.85, lookY: -0.9, spread: 0.92, mouth: "hmm", R: .chin)
        case .working: return Spec(yaw: -0.06, pitch: 0.32, brow: -0.3, browA: -0.6, lookY: 0.55, lid: 0.18, spread: 0.95, mouth: "focus")
        case .subagents: return Spec(pitch: -0.05, brow: 0.45, R: .conduct)
        case .speaking: return Spec(brow: 0.25, mouth: "talk", R: .gesture)
        case .done: return Spec(brow: 0.7, spread: 1.35, blush: 1.3, eyes: .happy, mouth: "D", R: .wave)
        case .needs: return Spec(lean: 1.12, brow: 0.5, browA: 0.75, mouth: "o", R: .knock)
        case .approval: return Spec(pitch: -0.08, tilt: 0.08, lean: 1.06, brow: 0.6, browA: 0.65, lookY: -0.3, blush: 1.25, R: .clasp, L: .clasp)
        case .blocked: return Spec(brow: -0.3, browA: -1, lid: 0.2, spread: 1.15, stiff: 1, mouth: "grit", R: .cross, L: .cross)
        case .dizzy: return Spec(spread: 1.1, eyes: .spiral, mouth: "wavy", R: .flop, L: .flop)
        case .sleep: return Spec(pitch: 0.42, tilt: 0.17, brow: -0.2, browA: 0.2, spread: 0.85, droop: 1, eyes: .closed, mouth: "sleep")
        }
    }

    // MARK: the mouth: one parametric shape, so every pose blends into the next

    // w: half width · open: 0 a closed crescent → 1 a wide D · round: toward an O · smile: + corners up · teeth · tilt
    private struct Mouth { var w = 5.0, open = 0.0, round = 0.0, smile = 0.0, teeth = 0.0, tilt = 0.0 }
    private static let mouths: [String: Mouth] = [
        "smile": Mouth(w: 7, open: 0.04, smile: 1),
        "grin": Mouth(w: 8.5, open: 0.4, smile: 1.2),
        "beam": Mouth(w: 9, open: 0.7, smile: 1.1),
        "o": Mouth(w: 3.4, open: 0.55, round: 1),
        "hmm": Mouth(w: 4.6, open: 0.05, smile: -0.4, tilt: 0.3),
        "flat": Mouth(w: 5, open: 0.05, smile: 0.1),
        "soft": Mouth(w: 5.6, open: 0.03, smile: 0.6, tilt: 0.08),      // listening: a small, attentive closed smile
        "hum": Mouth(w: 5.4, open: 0, smile: 0.75, tilt: 0.05),          // lips closed, content: humming
        "focus": Mouth(w: 4.4, open: 0.02, smile: -0.15, tilt: -0.16),   // pressed together and a touch lopsided: concentrating
        "D": Mouth(w: 9.5, open: 1, smile: 1, teeth: 1),
        "grit": Mouth(w: 7.5, open: 0.4, smile: -1.2, teeth: 1),
        "sleep": Mouth(w: 3.4, open: 0.32, round: 0.55, tilt: 0.15),
        "wavy": Mouth(w: 7),
    ]
    private static let visemes: [String: Mouth] = [
        "rest": Mouth(w: 6, open: 0.1, smile: 0.8),
        "A": Mouth(w: 7.2, open: 0.95, smile: 0.6, teeth: 0.5),
        "E": Mouth(w: 8.8, open: 0.45, smile: 0.9, teeth: 1),
        "O": Mouth(w: 4.4, open: 0.75, round: 1),
        "U": Mouth(w: 3, open: 0.32, round: 1),
        "M": Mouth(w: 4.6, smile: 0.3),
    ]
    private static let syllables = ["A", "E", "O", "A", "E", "M", "U", "A", "E", "O"]

    // MARK: the rig's layout (design points, the 198 × 242 screen)

    private static let headX = 99.0, headY = 125.0, headW = 114.0, headH = 98.0
    private static let shoulderY = 196.0, upper = 22.0, lower = 20.0, armW = 24.0
    private static let leaves = 7

    // MARK: state

    /// A value on a damped spring, the playground's: k stiffness, d damping ratio.
    private struct S {
        var x: Double, v = 0.0
        init(_ x: Double) { self.x = x }
        mutating func to(_ t: Double, _ k: Double, _ d: Double, _ dt: Double) {
            v += ((t - x) * k - v * 2 * sqrt(k) * d) * dt; x += v * dt
        }
    }
    private var yaw = S(0), pitch = S(0), tilt = S(0), lean = S(1), brow = S(0), browA = S(0), browR = S(0)
    private var lookX = S(0), lookY = S(0), lid = S(0), spread = S(1), droop = S(0), stiff = S(0), blush = S(1)
    private var mw = S(7), mopen = S(0.04), mround = S(0), msmile = S(1), mteeth = S(0), mtilt = S(0)
    private var hand: [P2] = [P2(144, 262), P2(54, 262)], handV: [P2] = [.zero, .zero], reach: [S] = [S(1), S(1)]
    private struct Leaf { var o = 0.0, v = 0.0, k: Double }
    private var hair: [Leaf] = (0..<ZenStage.leaves).map { i in
        let x = sin(Double(i + 3) * 127.1 + 311.7) * 43758.5453
        return Leaf(k: 70 + (x - floor(x)) * 40)
    }
    private var sq = S(0), nod = S(0), crown = S(0)
    private var blinkT = 0.0, nextBlink = 1.5, glance = P2.zero, nextGlance = 2.0
    private var squintT = 0.0, nextSquint = 6.0, beamT = 0.0, nextBeam = 5.0
    private var vis = "rest", sylT = 0.0, phrase = 0, browPop = 0.0
    private var react: ChumsState? = nil, reactT = 0.0, petT = 0.0
    private var gaze: P2? = nil, gazeT = 0.0, taps: [Double] = []
    private var fastFor = 0.0, crownIdle = 9.0, nextTool = 0.8, knockT = 0.0
    private var prevHX = 99.0, prevVX = 0.0
    private var upT = 0.0                                     // working: glancing up at a tool call
    private var humT = 0.0, humCool = 0.0                     // the phrase being hummed; a breath before the next stroke's
    private var away = S(0), down = S(0)                      // shrunk up out of the approval card's way; lowered for the talk bar
    private var state: ChumsState = .idle, started = false
    private var t = 0.0

    private struct Bit { var kind: Int, x, y, vx, vy, g, life, max, r, spin: Double, col: RGB }   // 0 leaf, 1 z, 2 ring
    private var bits: [Bit] = []
    private var spawn = 0.0

    private var shownState: ChumsState { react ?? state }

    // MARK: Staged

    func onState(_ r: Rig, _ s: ChumsState, prev: ChumsState?, variant: Bool) {
        state = s
        if !started {
            started = true
            let sp = spec(s)
            yaw.x = sp.yaw; pitch.x = sp.pitch; tilt.x = sp.tilt; lean.x = sp.lean; brow.x = sp.brow; browA.x = sp.browA
            browR.x = sp.browR; lookX.x = sp.lookX; lookY.x = sp.lookY; lid.x = sp.lid; spread.x = sp.spread
            droop.x = sp.droop; stiff.x = sp.stiff; blush.x = sp.blush
            away.x = s == .approval ? 1 : 0
        } else if prev != s {
            // a little squash-pop on every state change, with the leaves kicking
            sq.v += 1.4
            for i in hair.indices { hair[i].v += rnd(-5, 5) }
        }
        bits = []; spawn = 0; phrase = 0; sylT = 0; knockT = 0
    }

    func step(_ r: Rig, _ dt0: Double) {
        if r.ao {
            // dimmed: drawn about once a second, so nothing in flight; it rests in its state's pose
            react = nil; petT = 0; gazeT = 0; bits = []; sq = S(0); nod = S(0)
            for i in hair.indices { hair[i].o = 0; hair[i].v = 0 }
        }
        var left = min(dt0, 0.1)
        while left > 0 { let h = min(left, 1.0 / 120); sub(r, h); left -= h }
    }

    private func sub(_ r: Rig, _ dt: Double) {
        t += dt
        if react != nil { reactT -= dt; if reactT <= 0 { react = nil } }
        let st = shownState, s = spec(st)
        petT -= dt; gazeT -= dt
        let petting = petT > 0

        // procedural life on top of the state's pose
        var ty = s.yaw, tp = s.pitch, tt = s.tilt, lx = s.lookX, ly = s.lookY
        if st == .idle || st == .speaking || st == .listening {
            // layered slow waves so the roll never loops visibly
            tt += 0.075 * sin(t * 0.53) + 0.04 * sin(t * 1.37 + 1) + 0.02 * sin(t * 2.9 + 2)
            ty += 0.1 * sin(t * 0.37)
            nextGlance -= dt
            if nextGlance < 0 {
                let g = P2(rnd(-0.9, 0.9), rnd(-0.45, 0.45))
                if abs(g.x - glance.x) > 0.8 && rnd(0, 1) < 0.6 { blinkT = 0.16 }   // big glances come with a blink
                glance = g; nextGlance = rnd(1.4, 4.4)
            }
            // eyes snap to the glance; the head follows on its slower spring
            lx += glance.x * 0.7; ly += glance.y * 0.5
            ty += glance.x * 0.3; tp += glance.y * 0.1; tt += glance.x * 0.05
        }
        if st == .idle {
            nextSquint -= dt
            if nextSquint < 0 { squintT = 0.9; nextSquint = rnd(6, 12); sq.v -= 0.6 }
            // now and then the sliver eases open into a big smile and back, like Tolan's pose 05
            nextBeam -= dt
            if nextBeam < 0 { beamT = 1.8; nextBeam = rnd(7, 13) }
        }
        squintT -= dt; beamT -= dt
        let squint = squintT > 0 && st == .idle, beam = beamT > 0 && st == .idle && !squint
        if st == .speaking {
            // syllables only while the voice plays; a breath between phrases
            if r.voice > 0.06 { sylT -= dt; if sylT <= 0 { nextSyllable() } } else { vis = "rest"; phrase = 0; sylT = 0 }
            tp -= 0.06 * mopen.x; tt += 0.04 * sin(t * 1.3)
        }
        browPop *= exp(-dt * 3)
        if st == .dizzy { ty = 0.5 * sin(t * 4); tt = 0.22 * cos(t * 4); tp = 0.1 * sin(t * 8) }
        // reading: the eyes hop across a line in little jumps, then snap back to the next; a tool call, a glance up at you
        upT -= dt
        if st == .working {
            let ph = (t * 0.45).truncatingRemainder(dividingBy: 1), hop = floor(ph * 5), line = floor(t * 0.45).truncatingRemainder(dividingBy: 3)
            lx = -0.65 + hop * 0.3; ly = 0.5 + line * 0.08; ty += (hop - 2) * 0.025
            if upT > 0 { lx = 0; ly = -0.35; tp -= 0.15 }
        }
        if st == .subagents { let a = t * 0.9; lx = cos(a) * 0.9; ly = sin(a) * 0.4 - 0.2; ty = cos(a) * 0.25 }
        if st == .needs {
            let was = knockT; knockT += dt; if knockT >= 3.2 { knockT = 0 }
            if was < 0.02 && knockT >= 0.02 { r.onHaptic?(.strong) }
            tp -= 0.06 * knockBeat()
        }
        if petting { tt += 0.12 * sin(t * 2) }
        if gazeT > 0, let g = gaze, s.eyes == .open, !petting {
            lx = clamp((g.x - Self.headX) / 60, -1, 1); ly = clamp((g.y - Self.headY) / 60, -1, 1)
            ty += lx * 0.25; tp += ly * 0.12
        }
        // each tool call: a nod, a blink, the leaves bounce
        nextTool -= dt
        if nextTool <= 0 && (!r.worlds.queue.isEmpty || state == .working), let c = r.worlds.nextEvent(r) {
            nextTool = r.worlds.queue.isEmpty ? rnd(1.4, 2.4) : 0.5
            if c.kind != .stop {
                nod.v += 3.2; blinkT = 0.16; for i in hair.indices { hair[i].v += rnd(-2.4, 5.6) }
                if state == .working { upT = 0.55 }
            }
        }


        // the pose's springs: eyes fast, the head slower and looser
        let bl = petting || squint ? 1.5 : s.blush
        for (v, tgt) in [(\ZenStage.lookX, lx), (\ZenStage.lookY, ly)] { self[keyPath: v].to(tgt, 260, 0.8, dt) }
        for (v, tgt) in [(\ZenStage.yaw, ty + crown.x), (\ZenStage.pitch, tp), (\ZenStage.tilt, tt)] { self[keyPath: v].to(tgt, 42, 0.62, dt) }
        let glancing = st == .working && upT > 0              // glancing up: eyes open, brows pop
        let rest: [(ReferenceWritableKeyPath<ZenStage, S>, Double)] = [
            (\.lean, s.lean), (\.brow, glancing ? 0.35 : s.brow), (\.browA, glancing ? 0 : s.browA), (\.browR, s.browR), (\.lid, glancing ? 0 : s.lid),
            (\.spread, s.spread), (\.droop, s.droop), (\.stiff, s.stiff), (\.blush, bl)]
        for (v, tgt) in rest { self[keyPath: v].to(tgt, 90, 0.8, dt) }

        // mouth: fast springs while talking so syllables land; expressions ease over about half a second, like Tolan's
        let wasHumming = humT > 0; humT -= dt
        if wasHumming && humT <= 0 && petting { hum(r, chain: true) }   // still being petted: the next phrase
        let humming = humT > 0
        var m: Mouth
        if st == .speaking { m = Self.visemes[vis] ?? Mouth() }
        else { m = Self.mouths[humming ? "hum" : petting || squint ? "grin" : beam ? "beam" : s.mouth] ?? Self.mouths["smile"]! }
        if st == .sleep { m.open += 0.14 * sin(t * 1.1) }                 // breathes in and out with the chest
        let mk = st == .speaking ? 900.0 : 70, md = st == .speaking ? 0.8 : 0.95
        mw.to(m.w, mk, md, dt); mopen.to(m.open, mk, md, dt); mround.to(m.round, mk, md, dt)
        msmile.to(m.smile, mk, md, dt); mteeth.to(m.teeth, mk, md, dt); mtilt.to(m.tilt, mk, md, dt)
        self.squinting = squint || humming                                // humming with its eyes shut

        // the crown turns the head, then lets it settle back; turned fast for a second, dizzy
        crown.v += (-crown.x * 30 - crown.v * 6) * dt; crown.x = clamp(crown.x + crown.v * dt, -1.2, 1.2)
        crownIdle += dt
        if abs(crown.v) > 6 && crownIdle < 0.2 && state != .dizzy { fastFor += dt } else { fastFor = max(0, fastFor - dt) }
        if fastFor > 1 { fastFor = 0; r.setState(.dizzy) }
        // squash from pokes and landings, nods from tool calls and syllables
        sq.v += (-sq.x * 260 - sq.v * 9) * dt; sq.x += sq.v * dt
        nod.v += (-nod.x * 200 - nod.v * 10) * dt; nod.x += nod.v * dt
        nextBlink -= dt
        if nextBlink < 0 && s.eyes == .open { blinkT = 0.16; nextBlink = rnd(2.2, 5.7) }
        blinkT -= dt

        // hands chase their pose on loose springs, so they overshoot and settle
        for (i, sg) in [(0, 1.0), (1, -1.0)] {
            let pose = i == 0 ? s.R : s.L, goal = handGoal(pose, sg)
            let k = 110.0, d = 2 * sqrt(k) * 0.48
            handV[i] += ((goal - hand[i]) * k - handV[i] * d) * dt; hand[i] += handV[i] * dt
            // resting arms are short enough that the hand lands in frame; raised arms reach their full length
            let reaching = pose == .wave || pose == .conduct || pose == .knock
            reach[i].to(reaching ? 1.4 : 1, 90, 0.8, dt)
        }

        // the leaves follow the head through, each on its own spring
        let hx = headXNow(), vx = (hx - prevHX) / max(dt, 1e-3), ax = (vx - prevVX) / max(dt, 1e-3)
        prevHX = hx; prevVX = vx
        for i in hair.indices {
            let push = -ax * 0.0011 - crown.v * 0.02 - tilt.v * 0.12 - nod.v * 0.05 * Double(i - 3) / 3
            hair[i].v += push * (1 - 0.7 * stiff.x)
            hair[i].v += (-hair[i].o * hair[i].k - hair[i].v * 2 * sqrt(hair[i].k) * (0.26 + 0.5 * stiff.x)) * dt
            hair[i].o += hair[i].v * dt
        }

        // away for the approval card, down for the talk bar
        away.to(st == .approval ? 1 : 0, 60, 0.75, dt)
        down.to(st == .listening ? 1 : 0, 60, 0.85, dt)

        // particles
        spawn -= dt
        if spawn < 0 && !r.ao { emit(st) }
        for i in bits.indices {
            bits[i].life -= dt; bits[i].x += bits[i].vx * dt; bits[i].y += bits[i].vy * dt
            bits[i].vy += bits[i].g * dt; bits[i].r += bits[i].spin * dt
        }
        bits.removeAll { $0.life <= 0 }
    }
    private var squinting = false

    private func nextSyllable() {
        if phrase <= 0 { vis = "rest"; sylT = rnd(0.3, 0.85); phrase = Int.random(in: 4...12); browPop = 1; return }
        var v = vis
        while v == vis { v = Self.syllables.randomElement()! }
        vis = v; sylT = rnd(0.085, 0.185); phrase -= 1
        if (Self.visemes[v]?.open ?? 0) > 0.5 { nod.v += 0.9 }
    }
    private func knockBeat() -> Double {
        let ph = knockT
        if ph < 0.18 { return sin(ph / 0.18 * .pi) }
        if ph > 0.3 && ph < 0.48 { return sin((ph - 0.3) / 0.18 * .pi) }
        return 0
    }
    private func hopNow() -> Double {
        let ph = t.truncatingRemainder(dividingBy: 2.6)
        return shownState == .done && ph < 1.3 ? abs(sin(ph / 0.65 * .pi)) : 0
    }
    private func headXNow() -> Double { Self.headX + yaw.x * 4 + (shownState == .blocked ? sin(t * 38) * 1.2 : 0) }
    private func sway() -> Double { -tilt.x * 8 }

    private func handGoal(_ pose: Arm, _ sg: Double) -> P2 {
        let c = 99.0
        switch pose {
        case .chin: return P2(c + 12, 176)
        case .conduct: return P2(c + 52, 158 + 14 * sin(t * 3))
        case .gesture: return P2(c + 46 + 6 * sin(t * 1.7), 206 - 22 * clamp(mopen.x, 0, 1))
        case .wave: let a = 0.5 * sin(t * 7); return P2(c + 60 + 30 * sin(a), 118 + 8 * (1 - cos(a)))   // swings from the elbow
        case .knock: return P2(c + 32, 156 - 6 * knockBeat())
        case .clasp: return P2(c + sg * 8, 204 + 2 * sin(t * 2))
        case .cross: return P2(c - sg * 34, 216 + (sg > 0 ? 0 : 4))
        case .flop: return P2(c + sg * (50 + 5 * sin(t * 4 + sg)) + sway() * 1.2, 236 + 3 * sin(t * 8 + sg))   // limp, swinging
        case .hang: return P2(c + sg * 51 + sway() * 0.5, 232)
        }
    }

    private func emit(_ st: ChumsState) {
        switch st {
        case .done:
            for _ in 0..<3 {
                let a = -Double.pi / 2 + rnd(-1.3, 1.3)
                bits.append(Bit(kind: 0, x: 99, y: 70, vx: cos(a) * 80, vy: sin(a) * 90 - 20, g: 140, life: 1.3, max: 1.3,
                                r: rnd(0, 6), spin: rnd(-4, 4), col: rnd(0, 1) < 0.5 ? P.tip : Self.lift(P.root, 0.1)))
            }
            spawn = 0.3
        case .sleep: bits.append(Bit(kind: 1, x: 140, y: 74, vx: 8, vy: -13, g: 0, life: 3, max: 3, r: 0, spin: 0, col: P.front)); spawn = 1.4
        case .needs: bits.append(Bit(kind: 2, x: 131, y: 150, vx: 0, vy: 0, g: 0, life: 0.6, max: 0.6, r: 0, spin: 0, col: P.front)); spawn = 3.2
        default: spawn = 99
        }
    }

    // MARK: input

    func motion(_ r: Rig, _ ax: Double, _ ay: Double, _ az: Double) {
        let e = max(0, sqrt(ax * ax + ay * ay + az * az) - 0.9)
        guard e > 0.2 else { return }
        for i in hair.indices { hair[i].v += rnd(-1, 1) * e * 14 }      // the leaves fly about
    }
    func crown(_ r: Rig, _ delta: Double) { crown.v = clamp(crown.v + delta * 1.2, -14, 14); crownIdle = 0 }
    func touched(_ r: Rig, at pt: CGPoint) { gaze = P2(pt.x, pt.y); gazeT = 2 }
    func dragged(_ r: Rig, at pt: CGPoint) { gaze = P2(pt.x, pt.y); gazeT = 2 }
    func released(_ r: Rig) { gazeT = min(gazeT, 0.4) }
    func poke(_ r: Rig) {
        sq.v -= 2.4; blinkT = 0.18
        for i in hair.indices { hair[i].v += rnd(-7, 7) }
        taps = taps.filter { t - $0 < 3 } + [t]
        if taps.count >= 4 && state != .sleep && state != .dizzy { taps = []; react = .blocked; reactT = 1.6 }
    }
    func pet(_ r: Rig) { petT = 0.7; hum(r) }

    /// A stroke starts a little hummed phrase; one at a time, with a breath before the next stroke's. Not over its own
    /// voice or the mic, and not dimmed.
    private func hum(_ r: Rig, chain: Bool = false) {
        if !chain && t < humCool { return }
        if r.ao || state == .speaking || state == .listening { return }
        let d = Hum.shared.play(chain: chain)
        if d > 0 { humT = d; humCool = t + d + 1.2 }
    }
    func deny(_ r: Rig) { react = .blocked; reactT = 1.2 }
    func hit(_ pt: CGPoint) -> Bool {
        if state == .approval { return simd_length(P2(pt.x, pt.y) - P2(99, 74)) < 44 }
        return abs(pt.x - 99) < 66 && pt.y > 64
    }

    // MARK: drawing

    func draw(_ r: Rig, _ ctx: GraphicsContext) {
        // dimmed: drawn as one layer at half strength (piece by piece, the overlaps would show through lighter)
        if r.ao { var c = ctx; c.opacity = 0.5; c.drawLayer { l in self.paint(r, l) } } else { paint(r, ctx) }
    }

    func front(_ r: Rig, _ ctx: GraphicsContext) {}

    private func paint(_ r: Rig, _ ctx0: GraphicsContext) {
        let st = shownState, s = spec(st), petting = petT > 0
        var ctx = ctx0
        // approval: shrinks up toward the top, the card sliding in over its body; listening: lowered under the talk bar
        let k = clamp(away.x, 0, 1.2)
        ctx.translateBy(x: 0, y: -110 * k + 14 * down.x)
        ctx.translateBy(x: 99, y: Self.H); ctx.scaleBy(x: 1 - 0.48 * k, y: 1 - 0.48 * k); ctx.translateBy(x: -99, y: -Self.H)

        let breathe = sin(t * (st == .sleep ? 1.1 : 1.7)) * (st == .sleep ? 2 : 1.1)
        // everything scales around the bottom middle, so leaning in reads as coming closer
        var g = ctx
        g.translateBy(x: 99, y: Self.H); g.scaleBy(x: lean.x, y: lean.x); g.translateBy(x: -99, y: -Self.H)
        g.translateBy(x: 0, y: -hopNow() * 11)

        let torsoTop = drawTorso(g, breathe)
        let front = [isFront(s.R), isFront(s.L)]
        if st == .subagents { drawSprouts(g, back: true) }
        for i in [1, 0] where !front[i] { drawArm(g, i, torsoTop) }
        drawCollar(g, breathe)

        // head group: leaves, head, face, all turning around the neck
        let hx = headXNow(), hy = Self.headY + breathe * 0.6 + nod.x * 4 + pitch.x * 5
        var h = g
        h.translateBy(x: hx, y: hy + 40); h.rotate(by: .radians(tilt.x + nod.x * 0.04))
        h.scaleBy(x: 1 + sq.x * 0.6, y: 1 - sq.x); h.translateBy(x: -hx, y: -(hy + 40))
        drawHair(h, hx, hy)
        // a thick disc seen a little from above: a thin rim of its side wall shows along the bottom and the far side
        h.fill(superellipse(hx + 2 - yaw.x * 4, hy + 4.4, Self.headW, Self.headH, 2.15), with: .color(Self.col(P.rim)))
        h.fill(superellipse(hx, hy, Self.headW, Self.headH, 2.15), with: .color(Self.col(P.front)))   // the face: one flat color
        drawFace(h, hx, hy, s, petting)

        for i in [1, 0] where front[i] { drawArm(g, i, torsoTop) }
        if st == .subagents { drawSprouts(g, back: false) }
        drawBits(ctx, st)
    }

    private func isFront(_ a: Arm) -> Bool { a != .hang && a != .flop }

    private func superellipse(_ cx: Double, _ cy: Double, _ w: Double, _ h: Double, _ n: Double) -> Path {
        var p = Path()
        for i in 0...64 {
            let a = Double(i) / 64 * TAU, c = cos(a), s = sin(a)
            let x = cx + (c < 0 ? -1 : 1) * pow(abs(c), 2 / n) * w / 2
            let y = cy + (s < 0 ? -1 : 1) * pow(abs(s), 2 / n) * h / 2
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }

    /// The body's paint, shared by torso and arms so they're identical where they meet: the face's color down to the
    /// shoulders, then deepening (hue-shifted, never grey) toward the bottom.
    private func bodyShading(_ top: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: [.init(color: Self.col(P.front), location: 0), .init(color: Self.col(P.front), location: 0.25),
                                          .init(color: Self.col(Self.mix(P.front, P.shade, 0.75)), location: 1)]),
                        startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: Self.H))
    }

    /// A soft sack with straight sides; the round shoulders come from the arms, painted the same.
    private func drawTorso(_ g: GraphicsContext, _ breathe: Double) -> Double {
        let c = 99 + sway(), top = 175 + breathe * 0.3
        var p = Path()
        p.move(to: CGPoint(x: c - 22, y: top))
        p.addCurve(to: CGPoint(x: c - 37, y: top + 30), control1: CGPoint(x: c - 32, y: top + 1), control2: CGPoint(x: c - 37, y: top + 12))
        p.addLine(to: CGPoint(x: c - 37, y: Self.H + 40)); p.addLine(to: CGPoint(x: c + 37, y: Self.H + 40)); p.addLine(to: CGPoint(x: c + 37, y: top + 30))
        p.addCurve(to: CGPoint(x: c + 22, y: top), control1: CGPoint(x: c + 37, y: top + 12), control2: CGPoint(x: c + 32, y: top + 1))
        p.closeSubpath()
        g.fill(p, with: bodyShading(top))
        // form: the sides turn deeper and richer (light only ever subtracts)
        var e = g; e.clip(to: p)
        let side = Gradient(stops: [.init(color: Self.col(P.shade, 0.5), location: 0), .init(color: Self.col(P.shade, 0), location: 0.2),
                                    .init(color: Self.col(P.shade, 0), location: 0.8), .init(color: Self.col(P.shade, 0.5), location: 1)])
        e.fill(Path(CGRect(x: c - 38, y: top, width: 76, height: Self.H - top + 40)),
               with: .linearGradient(side, startPoint: CGPoint(x: c - 37, y: 0), endPoint: CGPoint(x: c + 37, y: 0)))
        return top
    }

    /// The ring collar, a chunky torus under the chin; the head hides its back half.
    private func drawCollar(_ g: GraphicsContext, _ breathe: Double) {
        let c = 99 + yaw.x * 2.5 + sway() * 0.7, y = 179 + breathe * 0.4
        // its cast shadow on the chest: one light from the top left, so down and to the right
        var sh = g; sh.addFilter(.blur(radius: 1.5))
        sh.fill(Path(ellipseIn: CGRect(x: c + 3 - 40, y: y + 15 - 7, width: 80, height: 14)), with: .color(Self.col(P.shade, 0.6)))
        var ring = Path()
        ring.addArc(center: .zero, radius: 1, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        let tube = ring.applying(CGAffineTransform(a: 33, b: 0, c: 0, d: 10, tx: c, ty: y - 6))
        let lit = Gradient(stops: [.init(color: Self.col(P.collarTop), location: 0), .init(color: Self.col(P.collar), location: 0.5),
                                   .init(color: Self.col(P.collarWall), location: 1)])
        let style = StrokeStyle(lineWidth: 24, lineCap: .round)
        g.stroke(tube, with: .linearGradient(lit, startPoint: CGPoint(x: 0, y: y - 12), endPoint: CGPoint(x: 0, y: y + 6)), style: style)
        // the ends turn away from the light
        let ends = Gradient(stops: [.init(color: Self.col(P.collarWall, 0.55), location: 0), .init(color: Self.col(P.collarWall, 0), location: 0.28),
                                    .init(color: Self.col(P.collarWall, 0), location: 0.72), .init(color: Self.col(P.collarWall, 0.4), location: 1)])
        g.stroke(tube, with: .linearGradient(ends, startPoint: CGPoint(x: c - 46, y: 0), endPoint: CGPoint(x: c + 46, y: 0)), style: style)
    }

    /// Two-bone IK: the elbow bends outward.
    private func ik(_ s: P2, _ t: P2, _ a: Double, _ b: Double, _ side: Double) -> (elbow: P2, hand: P2) {
        let dv = t - s
        let d = clamp(simd_length(dv), 1, a + b - 0.5)
        let th = atan2(dv.y, dv.x), A = acos(clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
        let e1 = s + P2(cos(th + A), sin(th + A)) * a, e2 = s + P2(cos(th - A), sin(th - A)) * a
        let elbow = (e1.x - 99) * side > (e2.x - 99) * side ? e1 : e2
        return (elbow, s + P2(cos(th), sin(th)) * d)
    }

    /// One even capsule with a round end, painted with the body's own gradient so the round shoulder IS the top of the
    /// body (the hair trick). A resting arm reads through the gap it opens beside the torso, not a line; a soft shadow
    /// only where it still overlaps the body.
    private func drawArm(_ g: GraphicsContext, _ i: Int, _ top: Double) {
        let sg = i == 0 ? 1.0 : -1.0
        let S0 = P2(99 + sway() + sg * 33 + yaw.x * 2, Self.shoulderY)
        let (E, Hd) = ik(S0, hand[i], Self.upper * reach[i].x, Self.lower * reach[i].x, sg)
        func lp(_ a: P2, _ b: P2, _ k: Double) -> P2 { a + (b - a) * k }
        func from(_ k: Double) -> Path {                        // the curve from k to the hand (de Casteljau split)
            let a = lp(S0, E, k), b = lp(E, Hd, k)
            var p = Path(); let q = lp(a, b, k)
            p.move(to: CGPoint(x: q.x, y: q.y)); p.addQuadCurve(to: CGPoint(x: Hd.x, y: Hd.y), control: CGPoint(x: b.x, y: b.y))
            return p
        }
        let style = StrokeStyle(lineWidth: Self.armW, lineCap: .round, lineJoin: .round)
        let paint = bodyShading(top)
        for (k, alpha) in [(0.3, 0.18), (0.6, 0.24)] {
            var c = g
            c.addFilter(.shadow(color: Self.col(Self.deepen(P.front, 0.4), alpha), radius: 2, x: -sg * 1.5, y: 1.5))
            c.stroke(from(k), with: paint, style: style)
        }
        g.stroke(from(0), with: paint, style: style)
        // roundness: deeper color along the side away from the light, fading in below the shoulder
        var inner = g
        let outline = from(0).strokedPath(style)
        inner.clip(to: outline)
        inner.addFilter(.blur(radius: 2.5))
        var along = Path()
        let lx = -0.45, ly = -0.89, off = -Self.armW * 0.42
        for j in 0...12 {
            let k = 0.3 + 0.7 * Double(j) / 12, q = lp(lp(S0, E, k), lp(E, Hd, k), k)
            let pt = CGPoint(x: q.x + lx * off, y: q.y + ly * off)
            if j == 0 { along.move(to: pt) } else { along.addLine(to: pt) }
        }
        inner.stroke(along, with: .color(Self.col(P.shade, 0.5)), style: StrokeStyle(lineWidth: Self.armW * 0.4, lineCap: .round))
    }

    /// Fat leaf fingers fanned from near the middle of the head, so they read as a crown, not spikes. Each grows out of
    /// the head: exactly its color until it clears the head's edge, then one smooth blend to the tip, with its own thin
    /// side wall offset away from the light.
    private func drawHair(_ g: GraphicsContext, _ hx: Double, _ hy: Double) {
        let rootX = hx - yaw.x * 9, rootY = hy + 2, w = 32.0
        for i in [0, 6, 1, 5, 2, 4, 3] {                         // outer leaves behind, the middle one in front
            let u = Double(i - 3) / 3, q = hair[i]
            let fan = u * 1.22 * spread.x
            let wave = sin(t * 1.7 + Double(i) * 0.9) * 0.045 * (1 - stiff.x) + (stiff.x > 0.5 ? sin(t * 40 + Double(i)) * 0.012 : 0)
            let ang = fan + wave + q.o + droop.x * (u < 0 ? -1 : 1) * (0.5 + 0.3 * abs(u))
            let L = (90 - 14 * u * u + (i % 2 == 1 ? -5 : 0)) * (1 - 0.1 * droop.x)
            var leaf = Path()
            leaf.move(to: CGPoint(x: -w * 0.4, y: -10))
            leaf.addCurve(to: CGPoint(x: 0, y: -L), control1: CGPoint(x: -w * 0.62, y: -L * 0.6), control2: CGPoint(x: -w * 0.5, y: -L * 0.9))
            leaf.addCurve(to: CGPoint(x: w * 0.4, y: -10), control1: CGPoint(x: w * 0.5, y: -L * 0.9), control2: CGPoint(x: w * 0.62, y: -L * 0.6))
            leaf.closeSubpath()
            var c = g; c.translateBy(x: rootX, y: rootY); c.rotate(by: .radians(ang))
            // The rim must only ever read as a sliver down one side, never as a second leaf: shift the copy straight across
            // the finger, clip it to that side, and shorten it a touch from the root so its point stays inside the real tip.
            let ox = 1.2 - yaw.x * 2.5, oy = 2.2, ca = cos(-ang), sa = sin(-ang), dx = ox * ca - oy * sa
            var wall = c
            wall.clip(to: Path(CGRect(x: dx > 0 ? 0 : -w, y: -L - 4, width: w, height: L + 24)))
            wall.translateBy(x: dx, y: 0.6); wall.scaleBy(x: 1, y: 0.92)
            let rg = Gradient(stops: [.init(color: Self.col(P.rim), location: 0), .init(color: Self.col(P.rim), location: 0.5),
                                      .init(color: Self.col(P.tipRim), location: 1)])
            wall.fill(leaf, with: .linearGradient(rg, startPoint: .zero, endPoint: CGPoint(x: 0, y: -L)))
            let lg = Gradient(stops: [.init(color: Self.col(P.front), location: 0), .init(color: Self.col(P.front), location: 0.46),
                                      .init(color: Self.col(Self.mix(P.front, P.root, 0.85)), location: 0.62), .init(color: Self.col(P.tip), location: 1)])
            c.fill(leaf, with: .linearGradient(lg, startPoint: .zero, endPoint: CGPoint(x: 0, y: -L)))
        }
    }

    private func drawFace(_ g: GraphicsContext, _ hx: Double, _ hy: Double, _ s: Spec, _ petting: Bool) {
        let fx = hx + yaw.x * 12, fy = hy + 4 + pitch.x * 8, sx = 1 - 0.28 * abs(yaw.x)
        func X(_ x: Double) -> Double { fx + x * sx - yaw.x * abs(x) * 0.12 * (x < 0 ? -1 : 1) }

        // blush: below and just outside the eyes, never tucked under them
        let bl = clamp(blush.x, 0.6, 1.6)
        for k in [-1.0, 1.0] {
            let rx = 8.6 * sx * (0.9 + 0.12 * bl), ry = 5 * (0.9 + 0.12 * bl)
            g.fill(Path(ellipseIn: CGRect(x: X(k * 36) - rx, y: fy + 13.5 - ry, width: 2 * rx, height: 2 * ry)), with: .color(Self.col(P.blush, 0.72 * min(1, bl))))
        }

        // eyes
        let eyes: Eyes = petting || squinting ? .closed : s.eyes
        let blink = blinkT > 0 ? sin(clamp(blinkT / 0.16, 0, 1) * .pi) * 1.1 : 0
        let lidK = clamp(max(lid.x, blink), 0, 1)
        let iris = Self.col(P.iris), lidC = Self.col(P.wall)
        for k in [-1.0, 1.0] {
            let ex = X(k * 21), ey = fy - 4, r = 11.0, hw = r * 0.82 * sx
            // closed and happy eyes are filled crescents, like the Tolans' squint-smile
            if eyes == .closed || eyes == .happy {
                let up = eyes == .happy
                var p = Path()
                p.move(to: CGPoint(x: ex - hw, y: ey + (up ? 3 : -1)))
                p.addQuadCurve(to: CGPoint(x: ex + hw, y: ey + (up ? 3 : -1)), control: CGPoint(x: ex, y: ey + (up ? -9 : 10)))
                p.addQuadCurve(to: CGPoint(x: ex - hw, y: ey + (up ? 3 : -1)), control: CGPoint(x: ex, y: ey + (up ? -3.4 : 4.6)))
                g.fill(p, with: .color(iris))
                continue
            }
            // the upper lid cuts the eye flat from above (a blink closes it all the way)
            let ly = ey - r + 2 * r * lidK
            if lidK > 0.92 {
                var p = Path()
                p.move(to: CGPoint(x: ex - r * 0.8 * sx, y: ey + 2))
                p.addQuadCurve(to: CGPoint(x: ex + r * 0.8 * sx, y: ey + 2), control: CGPoint(x: ex, y: ey + 4))
                g.stroke(p, with: .color(lidC), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                continue
            }
            var e = g
            e.clip(to: Path(CGRect(x: ex - r - 3, y: ly, width: 2 * r + 6, height: 2 * r + 6)))
            let white = Path(ellipseIn: CGRect(x: ex - r * 0.86 * sx, y: ey - r * 1.04, width: 2 * r * 0.86 * sx, height: 2 * r * 1.04))
            e.fill(white, with: .color(Self.col(P.white)))
            e.clip(to: white)
            if eyes == .spiral {
                var p = Path()
                for j in 0..<56 {
                    let a = Double(j) * 0.25, rr = a * 0.68, aa = a + t * 7 * k
                    let pt = CGPoint(x: ex + cos(aa) * rr * sx, y: ey + sin(aa) * rr)
                    if j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                e.stroke(p, with: .color(iris), lineWidth: 2)
            } else {
                let ir = 7.3, mx = r - ir - 0.2
                let ix = ex + clamp(lookX.x, -1, 1) * mx * sx, iy = ey + clamp(lookY.x, -1, 1) * mx
                e.fill(Path(ellipseIn: CGRect(x: ix - ir, y: iy - ir, width: 2 * ir, height: 2 * ir)), with: .color(iris))
            }
            if lidK > 0.04 {
                let lw = r * sx * sqrt(max(0, 1 - pow((ly - ey) / r, 2))) + 1.5
                g.strokeLine(ex - lw, ly, ex + lw, ly, lidC, 3)
            }
        }

        // brows: the main actors. Built like the head: one fat, slightly bowed capsule with a flat front face, and a thin
        // crisp rim of its side wall showing along the bottom (down and a touch right, same as the head's rim).
        for k in [-1.0, 1.0] {
            let raise = brow.x + (k > 0 ? browR.x : 0) + (petting ? 0.3 : 0) + browPop * 0.35
            let by = fy - 26 - raise * 6.5 + (s.eyes == .happy ? -2 : 0)
            var b = g
            b.translateBy(x: X(k * 21), y: by); b.rotate(by: .radians(k * browA.x * 0.42 + (k > 0 ? -browR.x * 0.15 : 0)))
            var bar = Path(); bar.move(to: CGPoint(x: -8.5 * sx, y: 1.4))
            bar.addQuadCurve(to: CGPoint(x: 8.5 * sx, y: 1.4), control: CGPoint(x: 0, y: -2.2))
            let style = StrokeStyle(lineWidth: 8.5, lineCap: .round)
            var rim = b; rim.translateBy(x: 0.5, y: 1.7)
            rim.stroke(bar, with: .color(Self.col(P.browWall)), style: style)
            b.stroke(bar, with: .color(Self.col(P.brow)), style: style)
        }

        // mouth: a hair off-center and tilted, the way the Tolans wear it
        drawMouth(g, X(2.5), fy + 15, sx, s.mouth == "wavy" && !petting)
    }

    /// One cavity for every mouth, read off Tolan's pose videos frame by frame. A nearly straight top edge with sharp
    /// corners; opening only drops the bottom arc (and widens it). Inside, top to bottom: optional teeth, a dark band
    /// that thickens toward the far corner, then the tongue. No outline. Layers arrive with the opening: closed is one
    /// flat red crescent, a little open lets the dark band in, and only wide, unrounded shapes show teeth.
    private func drawMouth(_ g0: GraphicsContext, _ cx: Double, _ cy: Double, _ sx: Double, _ wavy: Bool) {
        var g = g0
        g.translateBy(x: cx, y: cy); g.rotate(by: .radians(-0.09 + mtilt.x)); g.scaleBy(x: sx, y: 1)
        if wavy {
            var p = Path()
            for i in 0...12 {
                let x = -8 + Double(i) * 16 / 12, pt = CGPoint(x: x, y: sin(Double(i) * 1.1 + t * 6) * 1.8)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            g.stroke(p, with: .color(Self.col(P.lip)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            return
        }
        let open = clamp(mopen.x, 0, 1.2), round = clamp(mround.x, 0, 1), smile = msmile.x
        let w = max(1.5, mw.x) * (1 + 0.25 * open), h = 2.3 + open * 9.3
        let far = clamp(0.6 - yaw.x * 2.5, -1, 1)                       // which corner turns away from us (right, at rest)
        let c = smile * 1.6                                               // corners lift with the smile
        let ctl = -c * 0.5 + 2.4 * min(0, smile) - round * h * 1.4        // top edge: nearly straight; arches for an O or a grimace
        func top(_ x: Double) -> Double { let u = (x / w + 1) / 2; return (1 - u) * (1 - u) * -c + 2 * u * (1 - u) * ctl + u * u * -c }
        let D = h / 0.75, sh = -far * w * 0.22                           // the bowl is deepest toward the near side
        var shape = Path()
        shape.move(to: CGPoint(x: -w, y: -c))
        shape.addQuadCurve(to: CGPoint(x: w, y: -c), control: CGPoint(x: 0, y: ctl))
        shape.addCurve(to: CGPoint(x: -w, y: -c), control1: CGPoint(x: w * 0.95 + sh, y: -c + D), control2: CGPoint(x: -w * 0.95 + sh, y: -c + D))
        shape.closeSubpath()
        func band(_ depth: (Double) -> Double) -> Path {                   // a strip hanging off the top edge
            var p = Path(); p.move(to: CGPoint(x: -w - 2, y: top(-w) - 6))
            for i in 0...16 { let x = -w + 2 * w * Double(i) / 16; p.addLine(to: CGPoint(x: x, y: top(x) + depth(x))) }
            p.addLine(to: CGPoint(x: w + 2, y: top(w) - 6)); p.closeSubpath(); return p
        }
        let inside = smoothstep(0.06, 0.26, open), teeth = mteeth.x * (1 - round) * smoothstep(0.28, 0.55, open)
        g.fill(shape, with: .color(Self.col(Self.mix(P.lip, P.tongue, inside))))
        var m = g; m.clip(to: shape)
        if inside > 0.01 { m.fill(band { x in h * (0.4 + 0.28 * far * x / w) * inside }, with: .color(Self.col(P.mouthIn))) }
        if teeth > 0.05 {
            func tooth(_ x: Double) -> Double { teeth * (0.5 + h * 0.19) * (1 - pow(x / w, 2)) }
            m.fill(band { tooth($0) + 0.9 }, with: .color(Self.col(P.teethShadow)))
            m.fill(band(tooth), with: .color(Self.col(P.teeth)))
        }
    }
    private func smoothstep(_ a: Double, _ b: Double, _ v: Double) -> Double { let x = clamp((v - a) / (b - a), 0, 1); return x * x * (3 - 2 * x) }

    /// Little helpers orbiting the head: the ones on the far side of the orbit pass behind it.
    private func drawSprouts(_ g: GraphicsContext, back: Bool) {
        var list: [(i: Int, x: Double, y: Double, z: Double)] = []
        for i in 0..<3 {
            let a = Double(i) * 2.094 + t * 0.9
            let q = (i: i, x: 99 + cos(a) * 78, y: 132 + sin(a) * 26 + sin(t * 5 + Double(i)) * 2, z: sin(a))
            if (q.z < 0) == back { list.append(q) }
        }
        for q in list.sorted(by: { $0.z < $1.z }) {
            let sc = 0.75 + 0.2 * (q.z + 1) / 2
            var c = g; c.translateBy(x: q.x, y: q.y); c.scaleBy(x: sc, y: sc)
            c.strokeLine(0, 2, 0, -10, Self.col(Self.deepen(P.front, 0.15)), 2.4)
            for k in [-1.0, 1.0] {
                var l = c; l.translateBy(x: 0, y: -10); l.rotate(by: .radians(k * (0.9 + 0.15 * sin(t * 6 + Double(q.i)))))
                l.fill(Path(ellipseIn: CGRect(x: -3.6, y: -13, width: 7.2, height: 14)), with: .color(Self.col(P.tip)))
            }
            c.fill(Path(ellipseIn: CGRect(x: -11, y: -1, width: 22, height: 18)), with: .color(Self.col(P.wall)))
            c.fill(Path(ellipseIn: CGRect(x: -11, y: -2, width: 22, height: 18)), with: .color(Self.col(P.front)))
            for k in [-1.0, 1.0] { c.fillCircle(k * 4, 6, 1.8, Self.col(P.iris)) }
        }
    }

    private func drawBits(_ g: GraphicsContext, _ st: ChumsState) {
        if st == .thinking {
            for i in 0..<3 {
                let d = Double(i)
                g.fillCircle(150 + d * 9, 62 - d * 8 + sin(t * 4 - d * 0.7) * 1.8, 2.4 + d * 0.9, Color(.sRGB, red: 0.92, green: 0.94, blue: 0.9, opacity: 0.9))
            }
        }
        for q in bits {
            let a = clamp(q.life / q.max * 2, 0, 1)
            switch q.kind {
            case 0:
                var c = g.faded(a); c.translateBy(x: q.x, y: q.y); c.rotate(by: .radians(q.r))
                var p = Path()
                p.move(to: CGPoint(x: 0, y: -5)); p.addQuadCurve(to: CGPoint(x: 0, y: 5), control: CGPoint(x: 4, y: 0))
                p.addQuadCurve(to: CGPoint(x: 0, y: -5), control: CGPoint(x: -4, y: 0))
                c.fill(p, with: .color(Self.col(q.col)))
            case 1:
                let u = 1 - q.life / q.max
                let z = g.resolve(Text("z").font(.system(size: 10 + u * 9, weight: .heavy, design: .rounded)).foregroundColor(Self.col(Self.lift(P.front, 0.4))))
                g.faded(min(1, (1 - u) * 1.6)).draw(z, at: CGPoint(x: q.x, y: q.y), anchor: .bottom)
            default:
                let u = 1 - q.life / q.max
                g.strokeCircle(q.x, q.y, 10 + u * 22, .white.opacity(0.5 * (1 - u)), 2)
            }
        }
    }
}

/// Zen's hum, ported from the playground's Web Audio patch and rendered sample by sample: a soft buzz (harmonics falling
/// off faster than a sawtooth) through two lowpasses for the closed lips, a boost around 270 Hz for the nasal murmur,
/// and a little breath. Notes glide legato, each one re-articulated with a small dip ("mm-mm-mmm"), vibrato creeping in
/// on long notes, and the pitch sagging at the end. Chained phrases stay in one key and never repeat back to back.
final class Hum {
    static let shared = Hum()

    private static let rate = 24000.0
    private static let tunes: [[(Double, Double)]] = [          // (semitones up from the base, beats)
        [(0, 1), (2, 1), (4, 2.4)],
        [(4, 1), (2, 1), (0, 1), (2, 2.4)],
        [(0, 0.7), (4, 0.7), (7, 1.2), (4, 2.2)],
        [(7, 1), (4, 1), (5, 0.5), (4, 0.5), (2, 2.2)],
        [(0, 1.4), (-3, 0.8), (0, 2.6)],
    ]
    /// One cycle of the buzz: sines at 1/k^1.45, normalized to a peak of 1 like Web Audio's periodic waves.
    private static let wave: [Float] = {
        let n = 1024
        var w = (0..<n).map { i -> Double in
            let a = Double(i) / Double(n) * 2 * .pi
            return (1...30).reduce(0) { $0 + sin(Double($1) * a) / pow(Double($1), 1.45) }
        }
        let peak = w.map(abs).max()!
        w = w.map { $0 / peak }
        return w.map(Float.init)
    }()

    private var player: AVAudioPlayer?
    private var base = 0.0, last = -1

    /// Plays one phrase; returns how long it lasts, or 0 if it couldn't play.
    func play(chain: Bool) -> Double {
        var pick = Int.random(in: 0..<Self.tunes.count)
        while pick == last { pick = Int.random(in: 0..<Self.tunes.count) }
        last = pick
        if !chain || base == 0 { base = 247 * pow(2, Double.random(in: -2...2) / 12) }
        let (samples, secs) = render(Self.tunes[pick], base)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let p = try? AVAudioPlayer(data: Self.wav(samples)) else { return 0 }
        player = p
        return p.play() ? secs : 0
    }

    /// A biquad (the Audio EQ Cookbook's, as Web Audio builds them).
    private struct Biquad {
        var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0, x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        init(lowpass f: Double, qdB: Double) {
            let w = 2 * .pi * f / Hum.rate, al = sin(w) / (2 * pow(10, qdB / 20)), c = cos(w), a0 = 1 + al
            b0 = (1 - c) / 2 / a0; b1 = (1 - c) / a0; b2 = b0; a1 = -2 * c / a0; a2 = (1 - al) / a0
        }
        init(peaking f: Double, q: Double, gain: Double) {
            let A = pow(10, gain / 40), w = 2 * .pi * f / Hum.rate, al = sin(w) / (2 * q), c = cos(w), a0 = 1 + al / A
            b0 = (1 + al * A) / a0; b1 = -2 * c / a0; b2 = (1 - al * A) / a0; a1 = b1; a2 = (1 - al / A) / a0
        }
        init(bandpass f: Double, q: Double) {
            let w = 2 * .pi * f / Hum.rate, al = sin(w) / (2 * q), c = cos(w), a0 = 1 + al
            b0 = al / a0; b1 = 0; b2 = -al / a0; a1 = -2 * c / a0; a2 = (1 - al) / a0
        }
        mutating func run(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            return y
        }
    }

    private func render(_ tune: [(Double, Double)], _ base: Double) -> ([Float], Double) {
        let beat = 0.19, peak = 0.3, t0 = 0.02
        // the schedule: pitch targets (time, Hz, glide), the volume's breakpoints, the vibrato's depth targets
        var pitch: [(Double, Double, Double)] = [], gain: [(Double, Double)] = [(t0, 0)], vib: [(Double, Double)] = []
        var at = t0
        for (i, (s, beats)) in tune.enumerated() {
            let len = beats * beat, f = base * pow(2, s / 12)
            pitch.append((at, f, 0.035))
            if i == 0 { gain.append((at + 0.08, peak)) }
            else { gain.append((at + 0.03, peak * 0.45)); gain.append((at + 0.1, peak)) }
            gain.append((at + len - 0.02, peak * 0.82))
            vib.append((at + 0.12, len > 0.3 ? f * 0.009 : 0))
            at += len
        }
        pitch.append((at - 0.16, base * pow(2, tune.last!.0 / 12) * 0.96, 0.08))     // trails off a little flat
        gain.append((at + 0.16, 0))
        let end = at + 0.2, n = Int(end * Self.rate)

        var lips = Biquad(lowpass: 850, qdB: 0.6), lips2 = Biquad(lowpass: 1500, qdB: 0.5)
        var nasal = Biquad(peaking: 270, q: 1.3, gain: 8), breath = Biquad(bandpass: 600, q: 0.7)
        var f = base * pow(2, tune[0].0 / 12) * 0.97, depth = 0.0, phase = 0.0     // scoop up into the first note
        var pi = 0, gi = 0, vi = -1, target = f, glide = 0.035, vtarget = 0.0
        var out = [Float](repeating: 0, count: n), loud = 0.0
        let dt = 1 / Self.rate, table = Self.wave, tn = Double(table.count)
        for i in 0..<n {
            let t = Double(i) * dt
            while pi < pitch.count && pitch[pi].0 <= t { target = pitch[pi].1; glide = pitch[pi].2; pi += 1 }
            while vi + 1 < vib.count && vib[vi + 1].0 <= t { vi += 1; vtarget = vib[vi].1 }
            if pi > 0 { f += (target - f) * (1 - exp(-dt / glide)) }
            if vi >= 0 { depth += (vtarget - depth) * (1 - exp(-dt / 0.08)) }
            while gi + 1 < gain.count && gain[gi + 1].0 <= t { gi += 1 }
            let g: Double
            if t < t0 { g = 0 } else if gi + 1 < gain.count {
                let (ta, va) = gain[gi], (tb, vb) = gain[gi + 1]
                g = va + (vb - va) * (t - ta) / max(tb - ta, 1e-6)
            } else { g = 0 }
            phase += (f + depth * sin(2 * .pi * 5.3 * t)) * dt
            phase -= floor(phase)
            let buzz = Double(table[Int(phase * tn) % table.count])
            let voice = lips2.run(lips.run(nasal.run(buzz)))
            let air = breath.run(Double.random(in: -1...1)) * 0.05
            let v = (voice + air) * g
            out[i] = Float(v); loud = max(loud, abs(v))
        }
        // the playground peaked at 0.85; level it there whatever the phrase
        if loud > 0 { let k = Float(0.85 / loud); for i in out.indices { out[i] *= k } }
        return (out, at + 0.16 - t0 + 0.02)
    }

    /// 16-bit mono PCM in a WAV header, for AVAudioPlayer.
    private static func wav(_ s: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let r = UInt32(rate), bytes = UInt32(s.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes); d.append(contentsOf: Array("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(r); u32(r * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        for x in s { u16(UInt16(bitPattern: Int16(clamp(Double(x), -1, 1) * 32767))) }
        return d
    }
}
