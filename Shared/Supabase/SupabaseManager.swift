import Supabase
import Foundation

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://bchsgwwlqojfbnrcyqem.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJjaHNnd3dscW9qZmJucmN5cWVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwOTU4MzgsImV4cCI6MjA5MDY3MTgzOH0.3ivNaGbt69PofhQvhVD8RL_J1ZkDMHocIanLyYBlDlQ",
        options: SupabaseClientOptions(
            auth: .init(storage: SharedAuthStorage())
        )
    )
}
