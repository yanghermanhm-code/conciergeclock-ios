import Foundation

/// A language model that can write text on the iPhone. The app supplies Gemma (GGSModelKit)
/// behind this protocol, so ConciergeCore and its tests never depend on the model runtime —
/// the same split as PrepPilot's PrepEngine.
///
/// Concierge Clock uses it (Phase 6) to rank how important each event is, to vary the
/// butler's lines in every tone, to understand looser spoken commands, to answer "ask me about
/// my day" and to write the weekly wake summary. Facts (times, titles, counts) always come from
/// the calendar and the wake log, never from the model.
public protocol TextGenerating: Sendable {
    /// Shown in Settings ("Gemma 4 E2B").
    var modelName: String { get }

    /// One reply to `prompt` under the `system` instructions. With `jsonSchema`, the reply is a
    /// single JSON object matching it.
    func generate(system: String, prompt: String, jsonSchema: String?, maxTokens: Int, temperature: Double) async throws -> String
}
