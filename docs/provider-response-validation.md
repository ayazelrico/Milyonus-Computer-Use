# Unambiguous provider JSON

Both provider decoders now pass the complete response through the shared bounded `StrictJSON` parser before inspecting normalized dictionaries. Duplicate members are rejected at every object depth, including fields in otherwise ignored metadata. Escaped spellings of the same member name are also treated as duplicates. The shared nesting bound applies before a response can become a planner proposal.

OpenAI's `output_text` is a second JSON document and is parsed through the same validator separately, after its existing 65,536-byte text limit. Anthropic tool input is already nested in the outer response, so the outer scan covers its member names. Existing 262,144-byte response bounds, exactly-one-proposal checks, required proposal keys, action allowlist and refusal handling remain unchanged.

An explicitly oversized response retains `RESOURCE_LIMIT`. A response that fails bounded JSON parsing at a decoder boundary returns `PROVIDER_RESPONSE_INVALID`, with no raw body export or retry. A duplicate discriminator cannot select whichever success/refusal/action value a dictionary parser happens to retain.

Synthetic tests send conflicting and repeated envelope members, duplicate proposal fields, Unicode-escaped duplicate names and excessive nesting in unused metadata. Each rejected case makes exactly one request to the stub transport and cannot produce a proposal. Existing positive, refusal and malformed-proposal tests remain in the full suite. No real provider request, credential, native input or approval is involved. These checks do not establish real provider compatibility or complete the agent pilot gate.
