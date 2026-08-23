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
    if (mimeType.startsWith('image/')) {
      return this.extractImageOcr(buffer);
    }
    throw new Error(`Desteklenmeyen dosya tipi: ${mimeType}`);
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
    const XLSX = require('xlsx');
    const workbook = XLSX.read(buffer, { type: 'buffer' });
    return workbook.SheetNames.map((name: string, idx: number) => {
      const sheet = workbook.Sheets[name];
      const csv = XLSX.utils.sheet_to_csv(sheet);
      return { page: idx + 1, text: `Sayfa: ${name}\n${csv}` };
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
