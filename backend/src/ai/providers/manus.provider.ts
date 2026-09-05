import { Injectable } from '@nestjs/common';
import { AICompletionResult, AIMessage, AIProvider } from './ai-provider.interface';

type ManusTaskStatus = 'running' | 'stopped' | 'waiting' | 'error';

interface ManusTaskResponse {
  ok?: boolean;
  task_id?: string;
  error?: { code?: string; message?: string };
}

interface ManusTaskDetailResponse {
  ok?: boolean;
  task?: { status?: ManusTaskStatus };
  error?: { code?: string; message?: string };
}

interface ManusSendMessageResponse {
  ok?: boolean;
  task_id?: string;
  error?: { code?: string; message?: string };
}

interface ManusConfirmActionResponse {
  ok?: boolean;
  task_id?: string;
  error?: { code?: string; message?: string };
}

interface ManusMessage {
  type?: string;
  assistant_message?: { content?: string };
  error_message?: { content?: string };
  status_update?: {
    agent_status?: string;
    status_detail?: {
      waiting_description?: string;
      waiting_for_event_id?: string;
      waiting_for_event_type?: string;
    };
  };
}

interface ManusMessagesResponse {
  ok?: boolean;
  messages?: ManusMessage[];
  error?: { code?: string; message?: string };
}

@Injectable()
export class ManusProvider implements AIProvider {
  private readonly baseUrl = (process.env.MANUS_API_BASE_URL || 'https://api.manus.ai').replace(/\/$/, '');
  private readonly apiKey = process.env.MANUS_API_KEY || '';
  private readonly agentProfile = process.env.MANUS_AGENT_PROFILE || 'standard';
  private readonly timeoutMs = Number(process.env.MANUS_TIMEOUT_MS || 120_000);
  private readonly pollIntervalMs = Number(process.env.MANUS_POLL_INTERVAL_MS || 2_000);
  // Manus v2 message.content yaklaşık 5.000 token ile sınırlıdır. Sistem
  // promptu + RAG + canlı web bağlamı birlikte bu sınırı aşabileceğinden,
  // güvenli bir karakter bütçesiyle promptu kısaltıyoruz.
  private readonly maxInputChars = Number(process.env.MANUS_MAX_INPUT_CHARS || 16_000);

  async complete(
    messages: AIMessage[],
    opts: { maxTokens?: number; temperature?: number } = {},
  ): Promise<AICompletionResult> {
    void opts;
    if (!this.apiKey) {
      throw new Error('MANUS_API_KEY tanımlı değil. Backend .env dosyasına Manus API anahtarını ekleyin.');
    }

    const prompt = this.toPrompt(messages);
    const created = await this.request<ManusTaskResponse>('/v2/task.create', {
      method: 'POST',
      body: JSON.stringify({
        message: {
          content: [{ type: 'text', text: prompt }],
        },
        locale: process.env.MANUS_LOCALE || 'tr',
        interactive_mode: false,
        agent_profile: this.agentProfile,
        hide_in_task_list: true,
        share_visibility: 'private',
        title: 'Bayi teknik destek AI yanıtı',
      }),
    });

    if (!created.task_id) {
      throw new Error(`Manus görevi oluşturulamadı: ${this.errorMessage(created)}`);
    }

    const startedAt = Date.now();
    let autoContinuedAfterAsk = false;
    while (Date.now() - startedAt < this.timeoutMs) {
      const detail = await this.request<ManusTaskDetailResponse>(
        `/v2/task.detail?task_id=${encodeURIComponent(created.task_id)}`,
        { method: 'GET' },
      );
      const status = detail.task?.status;

      if (status === 'stopped') {
        const result = await this.request<ManusMessagesResponse>(
          `/v2/task.listMessages?task_id=${encodeURIComponent(created.task_id)}&order=desc&limit=50`,
          { method: 'GET' },
        );
        const text = this.extractAssistantText(result.messages || []);
        if (!text) throw new Error('Manus görevi tamamlandı ancak asistan yanıtı boş geldi.');
        return { text, raw: { taskId: created.task_id, detail, messages: result } };
      }

      if (status === 'error') {
        throw new Error(`Manus görevi hata verdi: ${this.errorMessage(detail)}`);
      }

      if (status === 'waiting') {
        const waitingResult = await this.request<ManusMessagesResponse>(
          `/v2/task.listMessages?task_id=${encodeURIComponent(created.task_id)}&order=desc&limit=50`,
          { method: 'GET' },
        );
        const waitingText = this.extractAssistantText(waitingResult.messages || []);
        if (waitingText) {
          return { text: waitingText, raw: { taskId: created.task_id, detail, messages: waitingResult } };
        }
        const waitingEventType = this.extractWaitingEventType(waitingResult.messages || []);
        if (waitingEventType === 'needConnectMyBrowser' && !autoContinuedAfterAsk) {
          const waitingEventId = this.extractWaitingEventId(waitingResult.messages || []);
          if (waitingEventId) {
            autoContinuedAfterAsk = true;
            await this.request<ManusConfirmActionResponse>('/v2/task.confirmAction', {
              method: 'POST',
              body: JSON.stringify({
                task_id: created.task_id,
                event_id: waitingEventId,
                input: { action: 'skip' },
              }),
            });
            await this.sleep(this.pollIntervalMs);
            continue;
          }
        }

        if (waitingEventType === 'messageAskUser' && !autoContinuedAfterAsk) {
          autoContinuedAfterAsk = true;
          await this.request<ManusSendMessageResponse>('/v2/task.sendMessage', {
            method: 'POST',
            body: JSON.stringify({
              task_id: created.task_id,
              message: {
                content: [{
                  type: 'text',
                  text: 'Kullanıcı ek soru beklemiyor. Lütfen ek bilgi istemeden devam et; soruyu web üzerinde araştır, öncelikle resmi üretici ve güvenilir teknik kaynakları kullan, doğrulanabilir kaynak URL’lerini ekleyerek doğrudan Türkçe cevap ver.',
                }],
              },
            }),
          });
          await this.sleep(this.pollIntervalMs);
          continue;
        }

        const waitingDescription = this.extractWaitingDescription(waitingResult.messages || []);
        return {
          text: `${waitingDescription || 'Manus ek bilgi bekliyor.'}\n\nManus web araştırması bu görevde başlatılamadı.\n\nCONFIDENCE: LOW`,
          raw: { taskId: created.task_id, detail, messages: waitingResult },
        };
      }

      await this.sleep(this.pollIntervalMs);
    }

    throw new Error(`Manus görevi ${this.timeoutMs / 1000} saniye içinde tamamlanmadı.`);
  }

  private toPrompt(messages: AIMessage[]): string {
    const unsupportedImage = messages.some(
      (message) => Array.isArray(message.content) && message.content.some((part) => part.type === 'image'),
    );
    if (unsupportedImage) {
      throw new Error('ManusProvider şu anda görsel içerikli AI mesajlarını desteklemiyor.');
    }

    const prompt = messages
      .map((message) => {
        const content = Array.isArray(message.content)
          ? message.content.filter((part) => part.type === 'text').map((part) => part.text).join('\n')
          : message.content;
        return `[${message.role.toUpperCase()}]\n${content}`;
      })
      .join('\n\n');

    if (prompt.length <= this.maxInputChars) return prompt;

    const tailChars = Math.min(4_000, Math.floor(this.maxInputChars / 4));
    const headChars = this.maxInputChars - tailChars;
    return `${prompt.slice(0, headChars)}\n\n[BAĞLAM MANUS GİRİŞ SINIRI NEDENİYLE KISALTILDI]\n\n${prompt.slice(-tailChars)}`;
  }

  private extractAssistantText(messages: ManusMessage[]): string {
    const assistantMessages = messages
      .filter((message) => message.type === 'assistant_message' || message.assistant_message)
      .map((message) => message.assistant_message?.content)
      .filter((content): content is string => Boolean(content?.trim()));
    return assistantMessages.join('\n\n').trim();
  }

  private extractWaitingDescription(messages: ManusMessage[]): string {
    const waitingMessage = [...messages].reverse().find((message) => message.status_update?.agent_status === 'waiting');
    return waitingMessage?.status_update?.status_detail?.waiting_description || '';
  }

  private extractWaitingEventType(messages: ManusMessage[]): string {
    const waitingMessage = [...messages].reverse().find((message) => message.status_update?.agent_status === 'waiting');
    return waitingMessage?.status_update?.status_detail?.waiting_for_event_type || '';
  }

  private extractWaitingEventId(messages: ManusMessage[]): string {
    const waitingMessage = [...messages].reverse().find((message) => message.status_update?.agent_status === 'waiting');
    return waitingMessage?.status_update?.status_detail?.waiting_for_event_id || '';
  }

  private async request<T>(path: string, init: RequestInit): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        'x-manus-api-key': this.apiKey,
        ...(init.headers || {}),
      },
    });
    const body = (await response.json()) as T;
    if (!response.ok) {
      throw new Error(`Manus API ${response.status}: ${this.errorMessage(body)}`);
    }
    return body;
  }

  private errorMessage(value: any): string {
    return value?.error?.message || value?.error?.code || 'bilinmeyen hata';
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
