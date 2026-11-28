# Model licences

ConciergeClock bundles no model weights. The offline AI model is downloaded once, on request,
into the App Group `group.com.greatergoodsoftware.models` (shared with PrepPilot, FocusFound and
FotoPhilter) and is used only after its SHA-256 matches the values below. The source of
truth in code is `Packages/GGSModelKit/Sources/GGSModelCore/ModelCatalog.swift`.

| Model | File | Size (bytes) | SHA-256 | Source (pinned commit) | Licence |
|---|---|---|---|---|---|
| Gemma 4 E4B (instruction-tuned, LiteRT-LM) | `gemma-4-E4B-it.litertlm` | 3,659,530,240 | `0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0` | [litert-community/gemma-4-E4B-it-litert-lm @ f254b5ba6e36f7d89cc7892e268e9877bc20f0a0](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/tree/f254b5ba6e36f7d89cc7892e268e9877bc20f0a0) | Apache-2.0 |
| Gemma 4 E2B (instruction-tuned, LiteRT-LM) | `gemma-4-E2B-it.litertlm` | 2,588,147,712 | `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c` | [litert-community/gemma-4-E2B-it-litert-lm @ 2e12bfd869b2962984f97a1f2a26807316d534cc](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/2e12bfd869b2962984f97a1f2a26807316d534cc) | Apache-2.0 |

Values read from the Hugging Face API (`/api/models/<repo>?blobs=true`) on 26 Nov 2026. Both
repositories are public and ungated. The generic `.litertlm` files are used (they run on the
CPU and on the Metal GPU); the `-gpu`, `-web` and vendor-specific files are not.

## Runtime

| Library | Version | Licence |
|---|---|---|
| [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) (Swift package `LiteRTLM`) | v0.20.0 (commit 95df4c2a), vendored in `Packages/LiteRTLM`; prebuilt runtime downloaded from the v0.20.0 GitHub release, checksum-pinned | Apache-2.0 (`Packages/LiteRTLM/LICENSE`) |

## Changing the model

Edit `ModelCatalog.swift` (repository, revision, file name, size, SHA-256) and this table
together. Apps that already downloaded the old file show it as not installed and offer the
new download.
