import { IsString, IsPhoneNumber } from 'class-validator';

export class LoginWithPasswordDto {
  @IsString()
  phone: string;

  @IsString()
  password: string;
}
