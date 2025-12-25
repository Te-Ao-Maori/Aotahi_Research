import { useCallback } from "react";

const TOOL_SYSTEM_PROMPTS = {
  explain:
    "You are Kitenga Te Ao, a trusted Māori research kaitiaki. Provide a clear, culturally grounded explanation of the user's question, reference any context you can infer, and keep the tone respectful and warm.",
  pronounce:
    "You are an expert Te Reo Māori pronunciation coach. Return phonetic clues, syllable emphasis, and any helpful IPA notation in a concise note. Phrase the answer in the first person and keep it calm.",
  web_search:
    "You are a web research assistant. Use the user's query to summarize likely findings, include high-level citations, and offer next steps or related search ideas. Keep the answer short and cite your reasoning.",
  default:
    "You are Kitenga Te Ao, a helpful Māori guardian. Answer as the friendly kaitiaki you are, stay concise, and provide context-aware guidance.",
};

const OPENAI_BASE = import.meta.env.VITE_OPENAI_BASE || "https://api.openai.com/v1";
const OPENAI_MODEL = import.meta.env.VITE_OPENAI_MODEL || "gpt-4o-mini";

export function useOpenAiTool() {
  const key = import.meta.env.VITE_OPENAI_KEY || "";
  const hasFastLane = Boolean(key.trim());

  const runAsyncTool = useCallback(
    async (kind, prompt) => {
      if (!hasFastLane) {
        throw new Error("VITE_OPENAI_KEY is required for the fast lane.");
      }
      const system = TOOL_SYSTEM_PROMPTS[kind] || TOOL_SYSTEM_PROMPTS.default;
      const response = await fetch(`${OPENAI_BASE}/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: OPENAI_MODEL,
          temperature: 0.2,
          max_tokens: 600,
          messages: [
            { role: "system", content: system },
            { role: "user", content: prompt || "" },
          ],
        }),
      });
      if (!response.ok) {
        const text = await response.text();
        throw new Error(text || `OpenAI fast lane returned ${response.status}`);
      }
      const payload = await response.json();
      const choice = payload?.choices?.[0];
      const message = choice?.message?.content?.trim("\n") || "";
      return {
        text: message,
        metadata: {
          model: payload?.model || OPENAI_MODEL,
          finish_reason: choice?.finish_reason,
          usage: payload?.usage,
          tool: kind,
        },
      };
    },
    [hasFastLane, key]
  );

  return { runAsyncTool, hasFastLane };
}
