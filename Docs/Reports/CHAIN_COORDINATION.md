# Chain Coordination Notes

- Stream payload shape (Chain 3): `ConversationEngineLive` emits `ConversationDelta` events in this order—`.context(ContextBuildResult)` once, `.assistantStreaming(aggregateText)` for each token/output, `.assistantCommitted(Message)` when finalized. The legacy `ConversationService` wrapper maps streaming to `StreamChunk` with aggregate tokens and emits `.done` after commit.
- Error surface (Chain 4): conversation calls can throw `EngineError.streamingTransport(StreamTransportError)`, `.contextRequired` (preferred descriptor IDs without snapshot), `.invalidDescriptor` (IDs missing in snapshot), `.contextLoadFailed`, and `.persistenceFailed`. These are the canonical error types for the unified pipeline.

