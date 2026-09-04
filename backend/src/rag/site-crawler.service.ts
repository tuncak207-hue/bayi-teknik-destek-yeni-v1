import { Injectable, Logger } from '@nestjs/common';
import puppeteer, { Browser } from 'puppeteer';

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

    // Kullanıcı isteği: "sadece 1 sayfa taradı" — bazı siteler (özellikle
    // modern React/Vue tabanlı siteler) linkleri JavaScript ile SONRADAN
    // oluşturur, ham HTML'de <a href> hiç bulunmaz. Bu durumda sitemap.xml
    // dosyası (varsa) çok daha güvenilir bir kaynak — JavaScript
    // gerektirmeden TÜM sayfa adreslerini düz metin olarak listeler.
    const sitemapUrls = await this.trySitemap(start, maxPages);
    if (sitemapUrls.length > 0) {
      this.logger.log(`[Sitemap] ${sitemapUrls.length} URL bulundu, öncelikli olarak kuyruğa ekleniyor.`);
      for (const u of sitemapUrls) {
        if (!queue.some((q) => q.url === u)) queue.push({ url: u, depth: 1 });
      }
    }

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

    // Kullanıcı isteği: "headless browser eklemeyi dene" — standart
    // yöntem (ham HTML + sitemap) çok az sayfa bulduysa (muhtemelen site
    // JavaScript ile içerik/link oluşturuyor), gerçek bir tarayıcı motoru
    // (Puppeteer) ile YENİDEN denenir. Daha ağır olduğu için sadece
    // GEREKTİĞİNDE (fallback olarak) kullanılıyor.
    if (pages.length <= 1) {
      this.logger.log('[Puppeteer] Standart tarama yetersiz kaldı, tarayıcı motoruyla deneniyor...');
      try {
        const browserPages = await this.crawlWithBrowser(start, { maxPages, maxDepth, pageTimeoutMs, budgetMs });
        if (browserPages.length > pages.length) return browserPages;
      } catch (err) {
        this.logger.warn(`[Puppeteer] Tarayıcı motoruyla tarama başarısız: ${err}`);
      }
    }

    return pages;
  }

  /**
   * Kullanıcı isteği: "headless browser eklemeyi dene" — JavaScript ile
   * içerik/link üreten modern sitelerde, ham HTML okumak yetersiz
   * kalıyor. Bu metod GERÇEK bir Chromium tarayıcısı açıp sayfayı
   * render eder, JS çalıştıktan SONRAKİ DOM'dan metin ve linkleri okur.
   * Daha yavaş ve kaynak-yoğun olduğu için sadece standart yöntem
   * yetersiz kaldığında (fallback) çağrılır.
   */
  private async crawlWithBrowser(start: URL, limits: Required<CrawlLimits>): Promise<CrawledPage[]> {
    const { maxPages, maxDepth, pageTimeoutMs, budgetMs } = limits;
    const visited = new Set<string>();
    const queue: Array<{ url: string; depth: number }> = [{ url: this.normalize(start), depth: 0 }];
    const pages: CrawledPage[] = [];
    const deadline = Date.now() + budgetMs;

    let browser: Browser | null = null;
    try {
      browser = await puppeteer.launch({
        headless: true,
        // Render gibi kısıtlı/konteyner ortamlarda Chromium'un başarıyla
        // başlaması için gereken bayraklar — sandbox ve paylaşımlı bellek
        // (/dev/shm) genelde bu tür ortamlarda kısıtlı/kapalıdır.
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--single-process',
          '--no-zygote',
        ],
      });

      while (queue.length > 0 && pages.length < maxPages && Date.now() < deadline) {
        const { url, depth } = queue.shift()!;
        if (visited.has(url)) continue;
        visited.add(url);

        const page = await browser.newPage();
        try {
          await page.setUserAgent(
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          );
          await page.goto(url, { waitUntil: 'networkidle2', timeout: pageTimeoutMs });

          // NOT: Bu callback GERÇEKTE tarayıcı (Chromium) içinde çalışır,
          // backend'in Node.js ortamında değil — bu yüzden 'document' gibi
          // DOM API'leri backend'in TypeScript ayarlarında tanımlı değil.
          // @ts-ignore
          const text = await page.evaluate(() => document.body?.innerText ?? '');
          pages.push({ url, text: text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim() });

          if (depth < maxDepth) {
            const hrefs: string[] = await page.evaluate(() => {
              // @ts-ignore
              return Array.from(document.querySelectorAll('a[href]')).map((a: any) => a.href);
            });
            for (const href of hrefs) {
              try {
                const resolved = new URL(href);
                if (!this.isSameRootDomain(resolved.hostname, start.hostname)) continue;
                if (/\.(pdf|jpg|jpeg|png|gif|svg|zip|docx?|xlsx?|mp4|mp3|css|js)$/i.test(resolved.pathname)) continue;
                const normalized = this.normalize(resolved);
                if (!visited.has(normalized) && queue.length + pages.length < maxPages * 2) {
                  queue.push({ url: normalized, depth: depth + 1 });
                }
              } catch {
                // geçersiz href — atla
              }
            }
          }
        } catch (err) {
          this.logger.warn(`[Puppeteer] Sayfa render edilemedi, atlanıyor: ${url} — ${err}`);
        } finally {
          await page.close();
        }
      }
    } finally {
      if (browser) await browser.close();
    }

    this.logger.log(`[Puppeteer] Tarama tamamlandı: ${start.hostname} — ${pages.length} sayfa`);
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

  /**
   * Kullanıcı isteği: "sadece 1 sayfa taradı" — JavaScript ile linkleri
   * oluşturan sitelerde ham HTML üzerinden link bulmak işe yaramıyor.
   * sitemap.xml (varsa) JavaScript gerektirmeden tüm sayfa adreslerini
   * verir. Basit bir "sitemap index" (alt sitemap'lere işaret eden)
   * durumunu da bir seviye takip eder.
   */
  private async trySitemap(base: URL, maxUrls: number, depth = 0): Promise<string[]> {
    if (depth > 1) return []; // sonsuz döngüyü önlemek için sitemap index'i en fazla 1 seviye takip et
    const sitemapUrl = `${base.origin}/sitemap.xml`;
    try {
      const res = await fetch(sitemapUrl, {
        signal: AbortSignal.timeout(8_000),
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; TeknikDestekBot/1.0)' },
      });
      if (!res.ok) return [];
      const xml = await res.text();
      const locRegex = /<loc>([^<]+)<\/loc>/gi;
      const found: string[] = [];
      let match: RegExpExecArray | null;
      while ((match = locRegex.exec(xml)) !== null) {
        found.push(match[1].trim());
      }

      // Sitemap index ise (alt sitemap'lere işaret ediyorsa), ilk birkaç
      // alt sitemap'i bir seviye takip et.
      const subSitemaps = found.filter((u) => u.endsWith('.xml')).slice(0, 3);
      const directUrls = found.filter((u) => !u.endsWith('.xml'));

      let all = directUrls;
      for (const sub of subSitemaps) {
        try {
          const subUrl = new URL(sub);
          if (!this.isSameRootDomain(subUrl.hostname, base.hostname)) continue;
          const subUrls = await this.trySitemap(subUrl, maxUrls, depth + 1);
          all = all.concat(subUrls);
        } catch {
          // geçersiz alt sitemap adresi — atla
        }
      }

      return all
        .filter((u) => {
          try {
            return this.isSameRootDomain(new URL(u).hostname, base.hostname);
          } catch {
            return false;
          }
        })
        .slice(0, maxUrls);
    } catch {
      return []; // sitemap yok/erişilemedi — sorun değil, normal link takibiyle devam edilir
    }
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
