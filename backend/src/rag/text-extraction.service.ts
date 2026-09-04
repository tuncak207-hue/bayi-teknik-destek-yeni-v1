import { Injectable, Logger } from '@nestjs/common';

export interface ExtractedPage {
  page: number;
  text: string;
}

@Injectable()
export class TextExtractionService {
  private readonly logger = new Logger(TextExtractionService.name);

  async extract(buffer: Buffer, mimeType: string): Promise<ExtractedPage[]> {
    if (mimeType === 'application/pdf') {
      return this.extractPdf(buffer);
    }
    if (
      mimeType ===
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ) {
      return this.extractDocx(buffer);
    }
    if (
      mimeType === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      mimeType === 'application/vnd.ms-excel'
    ) {
      return this.extractXlsx(buffer);
    }
    if (mimeType === 'text/plain') {
      return [{ page: 1, text: buffer.toString('utf-8') }];
    }
    // Kullanıcı isteği: "AI sadece dokümana değil, bu URL linkine de
    // baksın" — admin panelden eklenen web sayfaları da AYNI RAG
    // işleme hattından (chunk+embed) geçebilsin diye HTML desteği.
    if (mimeType === 'text/html') {
      return this.extractHtml(buffer);
    }
    if (mimeType.startsWith('image/')) {
      return this.extractImageOcr(buffer);
    }
    throw new Error(`Desteklenmeyen dosya tipi: ${mimeType}`);
  }

  /**
   * HTML'den okunabilir düz metni çıkarır — harici bir kütüphaneye
   * (cheerio vb.) ihtiyaç duymadan: script/style/nav/footer gibi
   * içerik taşımayan etiketleri temizler, kalan etiketleri kaldırır,
   * HTML karakter kodlarını (&amp; vb.) çözer.
   */
  private extractHtml(buffer: Buffer): ExtractedPage[] {
    let html = buffer.toString('utf-8');
    html = html.replace(/<(script|style|nav|footer|noscript)[^>]*>[\s\S]*?<\/\1>/gi, ' ');
    html = html.replace(/<!--[\s\S]*?-->/g, ' ');
    html = html.replace(/<br\s*\/?>/gi, '\n');
    html = html.replace(/<\/(p|div|li|h[1-6]|tr)>/gi, '\n');
    html = html.replace(/<[^>]+>/g, ' ');
    html = html
      .replace(/&nbsp;/gi, ' ')
      .replace(/&amp;/gi, '&')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'");
    html = html.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
    return [{ page: 1, text: html }];
  }

  private async extractPdf(buffer: Buffer): Promise<ExtractedPage[]> {
    // pdf-parse tüm metni tek seferde döner; sayfa ayrımı için \f (form feed)
    // veya pdf.js render-per-page kullanılabilir. Burada pdf-parse'ın
    // pagerender callback'i ile sayfa bazlı ayrıştırma yapılıyor.
    const pdfParse = require('pdf-parse');
    const pages: ExtractedPage[] = [];
    let currentPage = 0;

    await pdfParse(buffer, {
      pagerender: (pageData: any) => {
        currentPage += 1;
        const renderOptions = { normalizeWhitespace: true, disableCombineTextItems: false };
        return pageData.getTextContent(renderOptions).then((textContent: any) => {
          const text = textContent.items.map((item: any) => item.str).join(' ');
          pages.push({ page: currentPage, text });
          return text;
        });
      },
    });

    // Metin çok azsa (taranmış/scanned PDF), OCR'a düş.
    const totalChars = pages.reduce((sum, p) => sum + p.text.trim().length, 0);
    if (totalChars < 20) {
      this.logger.warn('PDF metni çok az bulundu, OCR gerekebilir (scanned PDF).');
      // Not: Prodüksiyonda burada her sayfa görsele render edilip (pdf-to-img)
      // tesseract.js ile OCR yapılmalı. Basitlik için burada uyarı bırakılıyor.
    }

    return pages.length ? pages : [{ page: 1, text: '' }];
  }

  private async extractDocx(buffer: Buffer): Promise<ExtractedPage[]> {
    const mammoth = require('mammoth');
    const result = await mammoth.extractRawText({ buffer });
    // DOCX'te gerçek "sayfa" kavramı yok; kaynak gösterimi için tek blok olarak
    // page=1 kabul edip chunking sırasında böleceğiz.
    return [{ page: 1, text: result.value }];
  }

  private async extractXlsx(buffer: Buffer): Promise<ExtractedPage[]> {
    const maxBytes = 10 * 1024 * 1024;
    const maxRows = 10_000;
    const maxColumns = 200;

    if (buffer.length > maxBytes) {
      throw new Error('Spreadsheet dosyası izin verilen 10 MB sınırını aşıyor.');
    }

    const ExcelJS = require('exceljs');
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);

    return workbook.worksheets.map((worksheet: any, idx: number) => {
      if (worksheet.rowCount > maxRows || worksheet.columnCount > maxColumns) {
        throw new Error(
          `Spreadsheet boyutu izin verilen sınırı aşıyor: maksimum ${maxRows} satır ve ${maxColumns} sütun.`,
        );
      }

      const lines: string[] = [];
      worksheet.eachRow({ includeEmpty: false }, (row: any) => {
        const values = Array.from(
          { length: Math.min(row.cellCount, maxColumns) },
          (_, columnIndex) => {
            const cell = row.getCell(columnIndex + 1);
            return String(cell.text ?? '').replace(/[\\r\\n]+/g, ' ').trim();
          },
        );
        lines.push(values.join(','));
      });

      return { page: idx + 1, text: `Sayfa: ${worksheet.name}\n${lines.join('\\n')}` };
    });
  }

  private async extractImageOcr(buffer: Buffer): Promise<ExtractedPage[]> {
    const { createWorker } = require('tesseract.js');
    const worker = await createWorker(['eng', 'tur']);
    const {
      data: { text },
    } = await worker.recognize(buffer);
    await worker.terminate();
    return [{ page: 1, text }];
  }
}
