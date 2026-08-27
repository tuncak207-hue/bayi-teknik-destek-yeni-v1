import { Controller, Get, HttpException, HttpStatus } from '@nestjs/common';
import { PrismaService } from './common/prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async check() {
    const startedAt = Date.now();

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return {
        status: 'ok',
        database: 'ok',
        uptimeSeconds: Math.floor(process.uptime()),
        responseTimeMs: Date.now() - startedAt,
        timestamp: new Date().toISOString(),
      };
    } catch {
      throw new HttpException(
        {
          status: 'degraded',
          database: 'unavailable',
          uptimeSeconds: Math.floor(process.uptime()),
          timestamp: new Date().toISOString(),
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }
}

export default HealthController;

export const healthCheckContract = {
  path: '/api/v1/health',
  successStatus: 200,
  degradedStatus: 503,
};
