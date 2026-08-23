import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CalculatorsService } from './calculators.service';

@UseGuards(JwtAuthGuard)
@Controller('calculators')
export class CalculatorsController {
  constructor(private calculatorsService: CalculatorsService) {}

  @Post('battery')
  battery(@Body() body: any) {
    return this.calculatorsService.batterySizing(body);
  }

  @Post('camera-storage')
  cameraStorage(@Body() body: any) {
    return this.calculatorsService.cameraStorage(body);
  }

  @Post('poe-budget')
  poeBudget(@Body() body: any) {
    return this.calculatorsService.poeBudget(body);
  }
}
