import Foundation

enum Constants {
    // 【修正】解像度アップ & 縦長アスペクト比に変更 (3:4)
    static let processWidth: Int = 240
    static let processHeight: Int = 320
    
    // 【修正】解像度が上がった分、探索範囲も少し広げる
    static let gridStep: Int = 8
    static let windowSize: Int = 12 // 元は8
    
    static let historyLength: Int = 60
    static let minLifeToDisplay: Int = 4
    static let maxObjectRatio: Double = 0.20
}
