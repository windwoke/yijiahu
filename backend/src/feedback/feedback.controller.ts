import { Controller, Post, Body, Req } from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { CreateFeedbackDto } from './dto/feedback.dto';

@Controller('feedback')
export class FeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  @Post()
  async submit(@Body() dto: CreateFeedbackDto, @Req() req: any) {
    const userId = req.user?.id;
    return this.feedbackService.submit(dto, userId);
  }
}
