import Foundation

/// A downloadable on-device language model. This file is the only place that says where the
/// models come from: change the source here and every app follows.
public struct ModelSpec: Sendable, Hashable, Identifiable, Codable {
    public enum Backend: String, Sendable, Codable {
        /// Metal GPU: fastest, uses more memory.
        case gpu
        /// CPU: slower, uses the least memory.
        case cpu
    }

    public var id: String
    public var displayName: String
    /// File name in the shared Models folder (as published).
    public var fileName: String
    /// Hugging Face repository and the commit it is pinned to, so the file never changes
    /// underneath the checksum.
    public var repository: String
    public var revision: String
    public var sizeBytes: Int64
    /// SHA-256 of the file, lowercase hex. A download is only used when it matches.
    public var sha256: String
    /// Physical memory (GB) an iPhone needs for this model on `preferredBackend`.
    public var minimumMemoryGB: Double
    public var preferredBackend: Backend
    public var license: String

    /// Direct download link, pinned to `revision`.
    public var downloadURL: URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(fileName)")!
    }

    /// The model's page (licence, model card).
    public var pageURL: URL {
        URL(string: "https://huggingface.co/\(repository)")!
    }
}

/// The models the apps can use. Both are Google's Gemma 4 instruction-tuned models in
/// LiteRT-LM format, published by Google under Apache 2.0, ungated. Values read from the
/// Hugging Face API on 26 Nov 2026 (see docs/model-licenses.md).
public enum ModelCatalog {
    /// Gemma 4 E4B: best quality. iPhones with 8 GB of memory (iPhone 15 Pro and newer).
    public static let gemma4E4B = ModelSpec(
        id: "gemma-4-e4b-it",
        displayName: "Gemma 4 E4B",
        fileName: "gemma-4-E4B-it.litertlm",
        repository: "litert-community/gemma-4-E4B-it-litert-lm",
        revision: "f254b5ba6e36f7d89cc7892e268e9877bc20f0a0",
        sizeBytes: 3_659_530_240,
        sha256: "0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0",
        minimumMemoryGB: 7.5,
        preferredBackend: .gpu,
        license: "Apache-2.0"
    )

    /// Gemma 4 E2B: smaller and faster. Fits iPhones with 6 GB of memory.
    public static let gemma4E2B = ModelSpec(
        id: "gemma-4-e2b-it",
        displayName: "Gemma 4 E2B",
        fileName: "gemma-4-E2B-it.litertlm",
        repository: "litert-community/gemma-4-E2B-it-litert-lm",
        revision: "2e12bfd869b2962984f97a1f2a26807316d534cc",
        sizeBytes: 2_588_147_712,
        sha256: "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c",
        minimumMemoryGB: 5.5,
        preferredBackend: .gpu,
        license: "Apache-2.0"
    )

    public static let all = [gemma4E4B, gemma4E2B]

    public static func spec(id: String) -> ModelSpec? {
        all.first { $0.id == id }
    }
}
