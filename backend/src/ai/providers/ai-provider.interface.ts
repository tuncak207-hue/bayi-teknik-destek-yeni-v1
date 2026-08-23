export interface AIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string | AIContentBlock[];
}

export type AIContentBlock =
  | { type: 'text'; text: string }
  | { type: 'image'; mediaType: string; data: string /* base64 */ };

export interface AICompletionResult {
  text: string;
  raw?: unknown;
}

/**
 * Tüm LLM sağlayıcılarının uyması gereken arayüz.
 * Bu sayede Anthropic / OpenAI / Gemini kolayca değiştirilebilir
 * (bkz. ai.module.ts -> AI_PROVIDER env değişkeni).
 */
export interface AIProvider {
  complete(messages: AIMessage[], opts?: { maxTokens?: number; temperature?: number }): Promise<AICompletionResult>;
}

export const AI_PROVIDER = 'AI_PROVIDER';
