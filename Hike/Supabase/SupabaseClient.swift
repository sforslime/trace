import Foundation
import Supabase

enum Supa {
    static let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabasePublishableKey
    )
}
