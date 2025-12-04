import Foundation

enum Config {
    // 解像度設定 (処理負荷軽減のため低解像度で計算)
    static let processWidth: Int = 160
    static let processHeight: Int = 120
    
    // アルゴリズム定数
    static let grid: Int = 8
    static let win: Int = 8
    static let historyLength: Int = 60
    static let minLifeToDisplay: Int = 4
    static let maxObjectRatio: Double = 0.15
}
