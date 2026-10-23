/// 9×9 dot-matrix icons matching the clock's LED style.
public enum DotMatrixIcon: String, CaseIterable {
    case clock, checklist, calendar, gear, refresh

    public static let size = 9

    private var pattern: [String] {
        switch self {
        case .clock:
            return ["..#####..",
                    ".#.....#.",
                    "#...#...#",
                    "#...#...#",
                    "#...###.#",
                    "#.......#",
                    "#.......#",
                    ".#.....#.",
                    "..#####.."]
        case .checklist:
            return ["##.######",
                    "##.......",
                    ".........",
                    "##.######",
                    "##.......",
                    ".........",
                    "##.######",
                    "##.......",
                    "........."]
        case .calendar:
            return [".#.....#.",
                    "#########",
                    "#########",
                    "#.......#",
                    "#.#.#.#.#",
                    "#.......#",
                    "#.#.#.#.#",
                    "#.......#",
                    "#########"]
        case .gear:
            return ["...#.#...",
                    ".#.###.#.",
                    "..#####..",
                    ".##...##.",
                    "###...###",
                    ".##...##.",
                    "..#####..",
                    ".#.###.#.",
                    "...#.#..."]
        case .refresh:
            return ["..####...",
                    ".#....#.#",
                    "#......##",
                    "#.....###",
                    "#........",
                    "#.......#",
                    "#.......#",
                    ".#.....#.",
                    "..#####.."]
        }
    }

    public var dots: [[Bool]] {
        pattern.map { row in row.map { $0 == "#" } }
    }
}
