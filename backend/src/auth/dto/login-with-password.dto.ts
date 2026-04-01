import { IsString } from 'class-validator';

export class LoginWithPasswordDto {
  @IsString()
  phone: string;

  @IsString()
  password: string;
}
