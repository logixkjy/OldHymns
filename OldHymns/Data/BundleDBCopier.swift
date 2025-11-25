//
//  BundleDBCopier.swift
//  OldHymns
//
//  Created by JooYoung Kim on 9/25/25.
//

import Foundation

public enum BundleDBCopier {
    public static func installIfNeeded(
        dbFileName: String = "hymn.db",
        dbVersion: Int = 1   // ← 버전 추가
    ) throws -> String {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dst = docs.appendingPathComponent(dbFileName)
        
        let versionKey = "BundleDBCopier.\(dbFileName).version"
        let savedVersion = UserDefaults.standard.integer(forKey: versionKey)
        
        // 버전이 바뀌었으면 기존 파일 삭제해서 새로 깔도록
        if savedVersion != dbVersion, fm.fileExists(atPath: dst.path) {
            try? fm.removeItem(at: dst)
        }
        
        // 없으면 번들에서 복사
        if !fm.fileExists(atPath: dst.path) {
            guard let src = Bundle.main.url(forResource: "hymn", withExtension: "db") else {
                throw NSError(
                    domain: "BundleDBCopier",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Bundle DB not found: hymn.db"]
                )
            }
            try fm.copyItem(at: src, to: dst)
            UserDefaults.standard.set(dbVersion, forKey: versionKey)
        }
        
        return dst.path
    }
}
