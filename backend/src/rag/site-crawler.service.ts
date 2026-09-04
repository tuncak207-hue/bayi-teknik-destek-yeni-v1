import { Injectable, Logger } from '@nestjs/common';

export interface CrawledPage {
  url: string;
  text: string;
}

const MAX_PAGES = 60;
const MAX_DEPTH = 8;
const PAGE_TIMEOUT_MS = 15_000;
const CRAWL_BUDGET_MS = 3 * 60_000; // toplam tarama için üst sınır

export interface CrawlLimits {
  maxPages?: number;
  maxDepth?: number;
  pageTimeoutMs?: number;
  budgetMs?: number;
}

/**
 * Kullanıcı isteği: "sadece ana sayfaya girip bakmamalı, tıpkı senin
 * yaptığın gibi sayfanın her menüsüne bakmalı" — bir başlangıç URL'i
 * verildiğinde, o AYNI SİTE İÇİNDEKİ (aynı domain) menü/link'leri takip
 * ederek birden fazla sayfayı tarar, her sayfanın metnini çıkarır.
 *
 * Güvenlik: sadece verilen domain içinde kalır (dış linkleri takip
 * etmez), iç ağ/özel IP adreslerine (SSRF riski) istek atmaz, sayfa
 * sayısı ve derinlik sınırlıdır (sunucu kaynaklarını korumak için).
 */
@Injectable()
export class SiteCrawlerService {
  private readonly logger = new Logger(SiteCrawlerService.name);

  async crawl(startUrl: string, limits: CrawlLimits = {}): Promise<CrawledPage[]> {
    const maxPages = limits.maxPages ?? MAX_PAGES;
    const maxDepth = limits.maxDepth ?? MAX_DEPTH;
    const pageTimeoutMs = limits.pageTimeoutMs ?? PAGE_TIMEOUT_MS;
    const budgetMs = limits.budgetMs ?? CRAWL_BUDGET_MS;

    const start = new URL(startUrl);
    this.assertSafeHost(start.hostname);

    const visited = new Set<string>();
    const queue: Array<{ url: string; depth: number }> = [{ url: this.normalize(start), depth: 0 }];
    const pages: CrawledPage[] = [];
    const deadline = Date.now() + budgetMs;

    while (queue.length > 0 && pages.length < maxPages && Date.now() < deadline) {
      const { url, depth } = queue.shift()!;
      if (visited.has(url)) continue;
      visited.add(url);

      let html: string;
      try {
        // Kullanıcı isteği: "sadece 1 sayfa taradı" — bazı siteler,
        // tarayıcı gibi görünmeyen (User-Agent'sız) isteklere farklı/eksik
        // içerik dönüyor ya da tamamen engelliyor. Gerçekçi bir tarayıcı
        // kimliği ekleyerek bu sorunu azaltıyoruz.
        const res = await fetch(url, {
          signal: AbortSignal.timeout(pageTimeoutMs),
          headers: {
            'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        });
        if (!res.ok || !res.headers.get('content-type')?.includes('text/html')) continue;
        html = await res.text();
      } catch (err) {
        this.logger.warn(`Sayfa alınamadı, atlanıyor: ${url} — ${err}`);
        continue;
      }

      pages.push({ url, text: this.stripHtml(html) });

      if (depth < maxDepth) {
        for (const link of this.extractSameSiteLinks(html, start)) {
          if (!visited.has(link) && queue.length + pages.length < maxPages * 2) {
            queue.push({ url: link, depth: depth + 1 });
          }
        }
      }
    }

    this.logger.log(`Tarama tamamlandı: ${start.hostname} — ${pages.length} sayfa`);
    return pages;
  }

  /** localhost, özel IP aralıkları ve bulut metadata adreslerine isteği engeller (SSRF koruması). */
  private assertSafeHost(hostname: string) {
    const blocked = [
      /^localhost$/i,
      /^127\./,
      /^0\.0\.0\.0$/,
      /^10\./,
      /^172\.(1[6-9]|2\d|3[01])\./,
      /^192\.168\./,
      /^169\.254\./, // bulut metadata servisleri (AWS/GCP) burada
      /^::1$/,
    ];
    if (blocked.some((re) => re.test(hostname))) {
      throw new Error('Bu adrese erişim güvenlik nedeniyle engellendi.');
    }
  }

  private normalize(url: URL): string {
    return `${url.origin}${url.pathname}`.replace(/\/$/, '') || url.origin;
  }

  private extractSameSiteLinks(html: string, base: URL): string[] {
    const links = new Set<string>();
    const hrefRegex = /<a\s+[^>]*href=["']([^"'#]+)["']/gi;
    let match: RegExpExecArray | null;
    while ((match = hrefRegex.exec(html)) !== null) {
      try {
        const resolved = new URL(match[1], base);
        // Kullanıcı isteği: "sadece 1 sayfa taradı" — TAM hostname
        // eşleşmesi (www.site.com !== shop.site.com) çok sıkıydı, aynı
        // KÖK domaindeki alt alan adlarını da (www, shop, support vb.)
        // kabul edecek şekilde gevşetildi.
        if (!this.isSameRootDomain(resolved.hostname, base.hostname)) continue;
        if (/\.(pdf|jpg|jpeg|png|gif|svg|zip|docx?|xlsx?|mp4|mp3|css|js)$/i.test(resolved.pathname)) continue;
        links.add(this.normalize(resolved));
      } catch {
        // geçersiz/relative olmayan href — atla
      }
    }
    return Array.from(links);
  }

  /** "www.site.com" ve "shop.site.com" gibi aynı kök domaindeki alt alan adlarını eşleştirir. */
  private isSameRootDomain(a: string, b: string): boolean {
    const rootOf = (host: string) => host.split('.').slice(-2).join('.');
    return rootOf(a) === rootOf(b);
  }

  private stripHtml(html: string): string {
    let text = html;
    text = text.replace(/<(script|style|nav|footer|noscript)[^>]*>[\s\S]*?<\/\1>/gi, ' ');
    text = text.replace(/<!--[\s\S]*?-->/g, ' ');
    text = text.replace(/<br\s*\/?>/gi, '\n');
    text = text.replace(/<\/(p|div|li|h[1-6]|tr)>/gi, '\n');
    text = text.replace(/<[^>]+>/g, ' ');
    text = text
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'");
    return text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  }
}
