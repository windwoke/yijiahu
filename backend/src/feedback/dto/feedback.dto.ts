import { IsString, IsNotEmpty, MaxLength, IsOptional } from 'class-validator';

export class CreateFeedbackDto {
  @IsString()
  @IsNotEmpty({ message: '反馈类型不能为空' })
  category: string; // bug / feature / other

  @IsString()
  @IsNotEmpty({ message: '反馈内容不能为空' })
  @MaxLength(1000, { message: '反馈内容不能超过1000字' })
  content: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  contact?: string; // 联系方式（可选）
}
