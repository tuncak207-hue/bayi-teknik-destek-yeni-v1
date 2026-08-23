import { Injectable, BadRequestException } from '@nestjs/common';

@Injectable()
export class CalculatorsService {
  /**
   * Yangın alarm paneli akü hesabı.
   * standbyCurrentMa: bekleme (standby) akımı (mA)
   * alarmCurrentMa: alarm durumu akım tüketimi (mA)
   * standbyHours: gerekli bekleme süresi (genelde 24h)
   * alarmMinutes: gerekli alarm süresi (genelde 30dk)
   * safetyFactor: güvenlik payı çarpanı (varsayılan 1.25 -> %25 pay)
   */
  batterySizing(params: {
    standbyCurrentMa: number;
    alarmCurrentMa: number;
    standbyHours: number;
    alarmMinutes: number;
    safetyFactor?: number;
  }) {
    const { standbyCurrentMa, alarmCurrentMa, standbyHours, alarmMinutes } = params;
    const safetyFactor = params.safetyFactor ?? 1.25;

    if (standbyCurrentMa <= 0 || alarmCurrentMa <= 0 || standbyHours <= 0 || alarmMinutes <= 0) {
      throw new BadRequestException('Tüm değerler pozitif olmalıdır.');
    }

    const standbyAh = (standbyCurrentMa / 1000) * standbyHours;
    const alarmAh = (alarmCurrentMa / 1000) * (alarmMinutes / 60);
    const totalAh = (standbyAh + alarmAh) * safetyFactor;

    // Standart akü kapasitelerinden en yakın üstünü öner
    const standardSizes = [1.2, 2.2, 3.2, 4.5, 7, 12, 17, 18, 24, 26, 33, 38, 45, 65, 100];
    const recommended = standardSizes.find((s) => s >= totalAh) ?? Math.ceil(totalAh);

    return {
      standbyAh: round(standbyAh),
      alarmAh: round(alarmAh),
      requiredAh: round(totalAh),
      recommendedBatteryAh: recommended,
      note: 'Bu hesap genel bir kılavuzdur; nihai değer panel üreticisinin dokümanına göre doğrulanmalıdır.',
    };
  }

  /**
   * Kamera sistemi için gerekli HDD/NVR depolama hesabı.
   */
  cameraStorage(params: {
    cameraCount: number;
    bitrateMbps: number; // kamera başına ortalama bitrate
    retentionDays: number;
    recordingHoursPerDay?: number; // varsayılan 24 (sürekli kayıt)
  }) {
    const { cameraCount, bitrateMbps, retentionDays } = params;
    const recordingHoursPerDay = params.recordingHoursPerDay ?? 24;

    if (cameraCount <= 0 || bitrateMbps <= 0 || retentionDays <= 0) {
      throw new BadRequestException('Tüm değerler pozitif olmalıdır.');
    }

    // Mbps -> MB/s -> günlük MB -> toplam MB
    const mbPerSecond = bitrateMbps / 8;
    const dailyMbPerCamera = mbPerSecond * 3600 * recordingHoursPerDay;
    const totalDailyMb = dailyMbPerCamera * cameraCount;
    const totalMb = totalDailyMb * retentionDays;
    const totalTb = totalMb / 1_000_000;

    // Standart HDD boyutlarından öner
    const standardSizesTb = [1, 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20];
    const recommended = standardSizesTb.find((s) => s >= totalTb) ?? Math.ceil(totalTb);

    return {
      requiredTb: round(totalTb, 2),
      recommendedHddTb: recommended,
      note: 'Hareket algılamalı (motion-only) kayıt kullanılıyorsa gerçek ihtiyaç önemli ölçüde daha düşük olabilir.',
    };
  }

  /**
   * PoE switch güç bütçesi hesabı.
   */
  poeBudget(params: { devices: Array<{ name: string; wattage: number; count: number }>; switchBudgetW: number }) {
    if (!params.devices?.length) throw new BadRequestException('En az bir cihaz girilmelidir.');
    if (!params.switchBudgetW || params.switchBudgetW <= 0) {
      throw new BadRequestException('Switch güç bütçesi pozitif bir değer olmalıdır.');
    }
    if (params.devices.some((d) => d.wattage <= 0 || d.count <= 0)) {
      throw new BadRequestException('Cihaz güç ve adet değerleri pozitif olmalıdır.');
    }

    const totalRequiredW = params.devices.reduce((sum, d) => sum + d.wattage * d.count, 0);
    const utilizationPercent = round((totalRequiredW / params.switchBudgetW) * 100, 1);

    return {
      totalRequiredW: round(totalRequiredW),
      switchBudgetW: params.switchBudgetW,
      utilizationPercent,
      withinBudget: totalRequiredW <= params.switchBudgetW,
      note:
        totalRequiredW > params.switchBudgetW
          ? 'Toplam güç ihtiyacı switch bütçesini aşıyor; ek PoE switch veya midspan enjektör gerekebilir.'
          : 'Toplam güç ihtiyacı switch bütçesi içinde.',
    };
  }
}

function round(value: number, decimals = 2) {
  const factor = Math.pow(10, decimals);
  return Math.round(value * factor) / factor;
}
