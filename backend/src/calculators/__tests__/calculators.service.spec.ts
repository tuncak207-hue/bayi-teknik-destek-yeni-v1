import { CalculatorsService } from '../calculators.service';
import { BadRequestException } from '@nestjs/common';

describe('CalculatorsService — AI kullanılmayan deterministik hesaplamalar', () => {
  const service = new CalculatorsService();

  describe('batterySizing', () => {
    it('standby + alarm akımına göre gerekli Ah değerini ve önerilen akü boyutunu hesaplar', () => {
      const result = service.batterySizing({
        standbyCurrentMa: 200,
        alarmCurrentMa: 1000,
        standbyHours: 24,
        alarmMinutes: 30,
      });

      // standbyAh = 0.2A * 24h = 4.8Ah ; alarmAh = 1A * 0.5h = 0.5Ah ; toplam*1.25 = 6.625
      expect(result.standbyAh).toBeCloseTo(4.8, 1);
      expect(result.alarmAh).toBeCloseTo(0.5, 1);
      expect(result.requiredAh).toBeCloseTo(6.625, 2);
      expect(result.recommendedBatteryAh).toBe(7); // standart boyutlardan en yakın üst
    });

    it('negatif veya sıfır değerlerde BadRequestException fırlatır', () => {
      expect(() =>
        service.batterySizing({ standbyCurrentMa: 0, alarmCurrentMa: 1000, standbyHours: 24, alarmMinutes: 30 }),
      ).toThrow(BadRequestException);
    });
  });

  describe('cameraStorage', () => {
    it('kamera sayısı, bitrate ve saklama süresine göre gerekli TB hesaplar', () => {
      const result = service.cameraStorage({ cameraCount: 10, bitrateMbps: 4, retentionDays: 30 });
      expect(result.requiredTb).toBeGreaterThan(0);
      expect(result.recommendedHddTb).toBeGreaterThanOrEqual(result.requiredTb);
    });
  });

  describe('poeBudget', () => {
    it('toplam güç ihtiyacı switch bütçesini aşarsa withinBudget=false döner', () => {
      const result = service.poeBudget({
        devices: [{ name: 'Kamera', wattage: 15, count: 20 }],
        switchBudgetW: 200,
      });
      expect(result.totalRequiredW).toBe(300);
      expect(result.withinBudget).toBe(false);
    });

    it('bütçe yeterliyse withinBudget=true döner', () => {
      const result = service.poeBudget({
        devices: [{ name: 'Kamera', wattage: 10, count: 5 }],
        switchBudgetW: 200,
      });
      expect(result.totalRequiredW).toBe(50);
      expect(result.withinBudget).toBe(true);
    });
  });
});
